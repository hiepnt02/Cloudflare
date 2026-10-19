//
//  UploadQueueManager.swift
//  Quick3D
//
//  QU3DW-1423 — the single owner of everything about uploading projects.
//

import Foundation
import Combine

struct BatchProgress: Equatable {
    let isRunning: Bool
    let fraction: Double
    let totalJobs: Int
    let finishedJobs: Int

    static let idle = BatchProgress(isRunning: false, fraction: 0, totalJobs: 0, finishedJobs: 0)
}

final class UploadQueueManager: ObservableObject {

    @Published private(set) var states: [String: CellUploadState] = [:]

    @Published private(set) var batch: BatchProgress = .idle

    var onBatchFinished: ((UploadBatchResult) -> Void)?

    private var transportFactory: UploadJobTransportFactory?

    private var pendingJobs: [UploadJob] = []
    private var activeBatch: Batch?
    private var runningTransport: UploadJobTransport?
    private var isPromotionScheduled = false

    init(transportFactory: UploadJobTransportFactory? = nil) {
        self.transportFactory = transportFactory
    }

    func configure(transportFactory: UploadJobTransportFactory) {
        self.transportFactory = transportFactory
    }


    @discardableResult
    func enqueue(_ job: UploadJob) -> Bool {
        guard !isBusy(catId: job.catId) else { return false }

        pendingJobs.append(job)
        setState(.waiting, for: job.catId)
        schedulePromotion()
        return true
    }

    func isBusy(catId: String) -> Bool {
        if pendingJobs.contains(where: { $0.catId == catId }) { return true }
        guard let activeBatch else { return false }
        return activeBatch.running?.catId == catId
            || activeBatch.queue.contains(where: { $0.catId == catId })
    }

    func remove(catId: String) {
        pendingJobs.removeAll { $0.catId == catId }
        activeBatch?.queue.removeAll { $0.catId == catId }
        if activeBatch?.running?.catId != catId {
            clearState(for: catId)
        }
    }

    func abortAll(reason: UploadAbortReason) {
        let transport = runningTransport
        runningTransport = nil
        activeBatch = nil
        pendingJobs.removeAll()
        transport?.cancel()

        states = [:]
        batch = .idle
    }


    private func schedulePromotion() {
        guard !isPromotionScheduled else { return }
        isPromotionScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.isPromotionScheduled = false
            self?.promotePendingIfIdle()
        }
    }

    private func promotePendingIfIdle() {
        guard activeBatch == nil, !pendingJobs.isEmpty else { return }

        let jobs = pendingJobs
        pendingJobs = []
        activeBatch = Batch(jobs: jobs)
        publishBatchProgress()
        startNextJob()
    }

    private func startNextJob() {
        guard var current = activeBatch else { return }

        guard !current.queue.isEmpty else {
            finishBatch(current)
            return
        }

        let job = current.queue.removeFirst()
        current.running = job
        activeBatch = current
        setState(.uploading(0), for: job.catId)
        publishBatchProgress()

        guard let transportFactory else {
            handleFinish(.failure(.unknown), of: job)
            return
        }

        let transport = transportFactory.transport(for: job)
        runningTransport = transport
        transport.start(
            job: job,
            onProgress: { [weak self] fraction in
                self?.onMain { self?.handleProgress(fraction, of: job) }
            },
            onFinish: { [weak self] outcome in
                self?.onMain { self?.handleFinish(outcome, of: job) }
            }
        )
    }

    private func finishBatch(_ current: Batch) {
        activeBatch = nil
        runningTransport = nil
        batch = .idle

        if !current.result.isEmpty {
            onBatchFinished?(current.result)
        }
        promotePendingIfIdle()
    }


    private func handleProgress(_ fraction: Double, of job: UploadJob) {
        guard var current = activeBatch, current.running?.id == job.id else { return }

        let clamped = min(max(fraction, 0), 1)
        current.jobSentBytes = Int64(Double(job.byteWeight ?? 0) * clamped)
        activeBatch = current

        setState(.uploading(clamped), for: job.catId)
        publishBatchProgress()
    }

    private func handleFinish(_ outcome: UploadJobOutcome, of job: UploadJob) {
        guard var current = activeBatch, current.running?.id == job.id else { return }

        current.running = nil
        current.sentBytes += job.byteWeight ?? 0
        current.jobSentBytes = 0
        current.finishedJobs += 1
        current.result.record(job, outcome: outcome)
        activeBatch = current

        clearState(for: job.catId)

        publishBatchProgress()
        startNextJob()
    }


    private func setState(_ phase: UploadPhase, for catId: String) {
        let next = CellUploadState(phase: phase)
        guard let existing = states[catId] else {
            states[catId] = next
            return
        }
        guard !isSameOnScreen(existing.phase, phase) else { return }
        states[catId] = next
    }

    private func clearState(for catId: String) {
        guard states[catId] != nil else { return }
        states.removeValue(forKey: catId)
    }

    private func isSameOnScreen(_ lhs: UploadPhase, _ rhs: UploadPhase) -> Bool {
        if case .uploading(let a) = lhs, case .uploading(let b) = rhs {
            return Int(a * 100) == Int(b * 100)
        }
        return lhs == rhs
    }

    private func publishBatchProgress() {
        guard let current = activeBatch else {
            if batch != .idle { batch = .idle }
            return
        }

        let next = BatchProgress(
            isRunning: true,
            fraction: current.fraction,
            totalJobs: current.totalJobs,
            finishedJobs: current.finishedJobs
        )
        guard Int(next.fraction * 100) != Int(batch.fraction * 100)
                || next.finishedJobs != batch.finishedJobs
                || !batch.isRunning else { return }
        batch = next
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}


private extension UploadQueueManager {

    struct Batch {
        var queue: [UploadJob]
        var running: UploadJob?
        let totalBytes: Int64
        let totalJobs: Int
        var sentBytes: Int64 = 0
        var jobSentBytes: Int64 = 0
        var finishedJobs: Int = 0
        var result = UploadBatchResult()

        init(jobs: [UploadJob]) {
            self.queue = jobs
            self.totalJobs = jobs.count
            self.totalBytes = jobs.reduce(0) { $0 + ($1.byteWeight ?? 0) }
        }

        var fraction: Double {
            guard totalBytes > 0 else {
                guard totalJobs > 0 else { return 0 }
                return Double(finishedJobs) / Double(totalJobs)
            }
            let sent = Double(sentBytes + jobSentBytes)
            return min(max(sent / Double(totalBytes), 0), 1)
        }
    }
}
