//
//  DownloadQueueManager.swift
//  Quick3D
//

import Foundation
import Combine

final class DownloadQueueManager: ObservableObject {

    /// The queue the app runs with, for screens outside the SwiftUI environment (UIKit, AR, view models).
    static weak var current: DownloadQueueManager?

    @Published private(set) var states: [String: DownloadPhase] = [:]

    var onFileReady: ((_ projectId: String, _ fileName: String, _ fileURL: URL) -> Void)?

    var onJobFailed: ((DownloadJob, DownloadFailureReason) -> Void)?

    var fileFinalizer: ((_ projectId: String, _ fileName: String, _ fileURL: URL) -> Result<Void, DownloadFailureReason>)?

    var fileNameResolver: ((_ projectId: String) -> String?)?

    private let maxConcurrent: Int
    private let linkProvider: GSXDownloadLinkProvider
    private let storage: DownloadStorage
    private let transportFactory: DownloadJobTransportFactory
    private(set) var prompter: DownloadPrompter?
    private let network: DownloadNetworkObserving?
    private var logoutObserver: NSObjectProtocol?

    /// While true, a network failure is reported as `.interrupted`: the system cut the transfer
    /// because the app went to the background, not because the connection was lost.
    var isInInterruptionWindow = false

    private var isPaused = false
    private var waitingJobs: [Waiting] = []
    private var runningJobs: [String: Running] = [:]

    private var cellularPendingJobs: [Waiting] = []
    private var isAskingCellularStart = false
    private var isAskingCellularResume = false

    private var failedJobs: [String: DownloadJob] = [:]

    private var completedJobs: [String: DownloadJob] = [:]

    init(
        maxConcurrent: Int = Constant.maxConcurrentDownloads,
        linkProvider: GSXDownloadLinkProvider,
        storage: DownloadStorage = DownloadStorage(),
        transportFactory: DownloadJobTransportFactory,
        prompter: DownloadPrompter? = nil,
        network: DownloadNetworkObserving? = nil,
        notificationCenter: NotificationCenter = .default
    ) {
        self.maxConcurrent = max(maxConcurrent, 1)
        self.linkProvider = linkProvider
        self.storage = storage
        self.transportFactory = transportFactory
        self.prompter = prompter
        self.network = network
        network?.onStatusChange = { [weak self] status in
            self?.onMain { self?.handleNetworkChange(status) }
        }
        logoutObserver = notificationCenter.addObserver(forName: .userDidLogout, object: nil, queue: nil) { [weak self] _ in
            self?.onMain { self?.abortAll(reason: .sessionEnded) }
        }
    }

    func configure(prompter: DownloadPrompter) {
        self.prompter = prompter
    }

    @discardableResult
    func enqueue(projectId: String, displayName: String, fileName: String) -> Bool {
        guard !isBusy(projectId: projectId) else { return false }
        return submit(DownloadJob(projectId: projectId, displayName: displayName, fileName: fileName))
    }

    @discardableResult
    func retry(projectId: String) -> Bool {
        guard let failed = failedJobs[projectId], !isBusy(projectId: projectId) else { return false }
        let fileName = fileNameResolver?(projectId) ?? failed.fileName
        return submit(DownloadJob(projectId: projectId, displayName: failed.displayName, fileName: fileName))
    }

    private func submit(_ job: DownloadJob) -> Bool {
        switch network?.status ?? .wifi {
        case .offline:
            prompter?.showError(.network, displayName: job.displayName)
            return false
        case .cellular:
            askBeforeUsingCellular(job)
        case .wifi:
            accept([Waiting(job: job)])
        }
        return true
    }

    private func accept(_ jobs: [Waiting]) {
        for waiting in jobs {
            failedJobs.removeValue(forKey: waiting.job.projectId)
            completedJobs.removeValue(forKey: waiting.job.projectId)
            setState(.waiting, for: waiting.job.projectId)
        }
        waitingJobs.append(contentsOf: jobs)
        startNextJobs()
    }

    /// Jobs that are running or waiting for their turn, running ones first.
    var activeJobs: [DownloadJob] {
        let running = runningJobs.values.map(\.job).sorted { $0.projectId < $1.projectId }
        return running + waitingJobs.map(\.job)
    }

    /// Shows jobs the app lost when it was killed as failed rows the user can retry or dismiss.
    func restoreInterrupted(_ jobs: [DownloadJob]) {
        for job in jobs where !isBusy(projectId: job.projectId) && failedJobs[job.projectId] == nil {
            failedJobs[job.projectId] = job
            setState(.failed(.interrupted), for: job.projectId)
        }
    }

    func isBusy(projectId: String) -> Bool {
        runningJobs[projectId] != nil
            || waitingJobs.contains { $0.job.projectId == projectId }
            || cellularPendingJobs.contains { $0.job.projectId == projectId }
    }

    func displayName(for projectId: String) -> String? {
        let jobs = runningJobs.values.map(\.job) + waitingJobs.map(\.job) + cellularPendingJobs.map(\.job)
            + failedJobs.values + completedJobs.values
        return jobs.first { $0.projectId == projectId }?.displayName
    }

    func requestCancel(projectId: String) {
        if completedJobs[projectId] != nil {
            removeCompletedRow(projectId: projectId)
            return
        }
        if failedJobs[projectId] != nil {
            cancel(projectId: projectId)
            return
        }
        guard let job = queuedJob(for: projectId) else { return }
        prompter?.confirmCancel(displayName: job.displayName) { [weak self] in
            guard let self, self.queuedJob(for: projectId)?.id == job.id else { return }
            self.cancel(projectId: projectId)
        }
    }

    private func queuedJob(for projectId: String) -> DownloadJob? {
        runningJobs[projectId]?.job ?? waitingJobs.first { $0.job.projectId == projectId }?.job
    }

    func cancel(projectId: String) {
        if let running = runningJobs.removeValue(forKey: projectId) {
            running.transport?.cancel()
            storage.removePart(for: projectId)
        }
        waitingJobs.removeAll { $0.job.projectId == projectId }
        cellularPendingJobs.removeAll { $0.job.projectId == projectId }
        failedJobs.removeValue(forKey: projectId)
        completedJobs.removeValue(forKey: projectId)
        clearState(for: projectId)
        startNextJobs()
    }

    func dismissFinished() {
        for projectId in Array(completedJobs.keys) + Array(failedJobs.keys) {
            completedJobs.removeValue(forKey: projectId)
            failedJobs.removeValue(forKey: projectId)
            clearState(for: projectId)
        }
    }

    func remove(projectIds: [String]) {
        projectIds.forEach(cancel(projectId:))
    }

    func pauseAll() {
        isPaused = true
        for (projectId, running) in runningJobs {
            guard let transport = running.transport else { continue }
            runningJobs[projectId]?.transport = nil
            setState(.paused(received: running.received, total: running.total), for: projectId)
            transport.pause { [weak self] resumeData in
                self?.onMain {
                    guard let self, self.isRunning(running.job) else { return }
                    self.runningJobs[projectId]?.resumeData = resumeData
                }
            }
        }
    }

    func resumeAll() {
        guard isPaused else { return }
        isPaused = false
        for running in runningJobs.values {
            guard running.transport == nil, let link = running.link else { continue }
            startTransport(for: running.job, link: link)
        }
        startNextJobs()
    }

    func abortAll(reason: DownloadAbortReason) {
        stopActiveJobs()
        failedJobs.removeAll()
        completedJobs.removeAll()
        if !states.isEmpty { states = [:] }
    }

    @discardableResult
    private func stopActiveJobs() -> [DownloadJob] {
        let stopped = runningJobs.values.map(\.job) + waitingJobs.map(\.job)
        runningJobs.values.forEach { $0.transport?.cancel() }
        runningJobs.removeAll()
        waitingJobs.removeAll()
        cellularPendingJobs.removeAll()
        isPaused = false
        isAskingCellularStart = false
        isAskingCellularResume = false
        storage.purgeAll()
        return stopped
    }

    private func startNextJobs() {
        while !isPaused, runningJobs.count < maxConcurrent, !waitingJobs.isEmpty {
            let waiting = waitingJobs.removeFirst()
            runningJobs[waiting.job.projectId] = Running(job: waiting.job)
            if let link = waiting.link {
                prepare(waiting.job, link: link)
            } else {
                requestLink(for: waiting.job)
            }
        }
    }

    private func askBeforeUsingCellular(_ job: DownloadJob) {
        cellularPendingJobs.append(Waiting(job: job))
        linkProvider.link(for: job) { [weak self] result in
            self?.onMain {
                guard let self,
                      let index = self.cellularPendingJobs.firstIndex(where: { $0.job.id == job.id }) else { return }
                switch result {
                case .success(let link):
                    self.cellularPendingJobs[index].link = link
                    self.showCellularStartPrompt(bytes: link.expectedBytes)
                case .failure(let reason):
                    self.cellularPendingJobs.remove(at: index)
                    self.markFailed(job, reason: reason)
                }
            }
        }
    }

    private func showCellularStartPrompt(bytes: Int64?) {
        guard !isAskingCellularStart else { return }
        isAskingCellularStart = true
        prompter?.confirmCellular(
            bytes: bytes,
            onConfirm: { [weak self] in self?.answerCellularStart(agreed: true) },
            onCancel: { [weak self] in self?.answerCellularStart(agreed: false) }
        )
    }

    private func answerCellularStart(agreed: Bool) {
        guard isAskingCellularStart else { return }
        isAskingCellularStart = false
        let jobs = cellularPendingJobs
        cellularPendingJobs.removeAll()
        guard agreed else { return }
        accept(jobs)
    }

    private func handleNetworkChange(_ status: DownloadNetworkStatus) {
        switch status {
        case .cellular:
            guard !runningJobs.isEmpty || !waitingJobs.isEmpty, !isAskingCellularResume else { return }
            pauseAll()
            isAskingCellularResume = true
            prompter?.confirmCellularResume(
                onConfirm: { [weak self] in self?.answerCellularResume(agreed: true) },
                onCancel: { [weak self] in self?.answerCellularResume(agreed: false) }
            )
        case .wifi:
            guard isAskingCellularResume else { return }
            prompter?.dismissCellularPrompt()
            answerCellularResume(agreed: true)
        case .offline:
            let hadUnstartedJobs = !cellularPendingJobs.isEmpty
            if isAskingCellularStart || isAskingCellularResume {
                prompter?.dismissCellularPrompt()
            }
            let stopped = stopActiveJobs()
            stopped.forEach { markFailed($0, reason: .network) }
            guard !stopped.isEmpty || hadUnstartedJobs else { return }
            prompter?.showNetworkLost()
        }
    }

    private func answerCellularResume(agreed: Bool) {
        guard isAskingCellularResume else { return }
        isAskingCellularResume = false
        if agreed {
            resumeAll()
        } else {
            stopActiveJobs().forEach { clearState(for: $0.projectId) }
        }
    }

    private func requestLink(for job: DownloadJob) {
        linkProvider.link(for: job) { [weak self] result in
            self?.onMain {
                guard let self, self.isRunning(job) else { return }
                switch result {
                case .success(let link):
                    self.prepare(job, link: link)
                case .failure(let reason):
                    self.handleFinish(.failure(reason), of: job)
                }
            }
        }
    }

    private func prepare(_ job: DownloadJob, link: GSXDownloadLink) {
        let reserved = runningJobs.values
            .filter { $0.job.id != job.id }
            .reduce(Int64(0)) { $0 + $1.remainingBytes }
        guard storage.canStore(bytes: link.expectedBytes, reserved: reserved) else {
            handleFinish(.failure(.storageFull), of: job)
            return
        }

        runningJobs[job.projectId]?.link = link
        runningJobs[job.projectId]?.total = link.expectedBytes ?? 0
        if isPaused {
            setState(.paused(received: 0, total: link.expectedBytes ?? 0), for: job.projectId)
        } else {
            startTransport(for: job, link: link)
        }
    }

    private func startTransport(for job: DownloadJob, link: GSXDownloadLink) {
        guard let running = runningJobs[job.projectId] else { return }
        let transport = transportFactory.transport(for: job)
        runningJobs[job.projectId]?.transport = transport
        runningJobs[job.projectId]?.resumeData = nil
        setState(.downloading(received: running.received, total: running.total), for: job.projectId)

        transport.start(
            job: job,
            link: link,
            destination: storage.partURL(for: job.projectId),
            resumeData: running.resumeData,
            onProgress: { [weak self] received, total in
                self?.onMain { self?.handleProgress(received: received, total: total, of: job) }
            },
            onFinish: { [weak self] outcome in
                self?.onMain { self?.handleFinish(outcome, of: job) }
            }
        )
    }

    private func handleProgress(received: Int64, total: Int64, of job: DownloadJob) {
        guard isRunning(job), runningJobs[job.projectId]?.transport != nil else { return }
        runningJobs[job.projectId]?.received = received
        runningJobs[job.projectId]?.total = total
        setState(.downloading(received: received, total: total), for: job.projectId)
    }

    private func handleFinish(_ outcome: DownloadJobOutcome, of job: DownloadJob) {
        guard isRunning(job) else { return }
        runningJobs.removeValue(forKey: job.projectId)

        switch outcome {
        case .success(let fileURL):
            switch fileFinalizer?(job.projectId, job.fileName, fileURL) ?? .success(()) {
            case .success:
                markCompleted(job)
                onFileReady?(job.projectId, job.fileName, fileURL)
            case .failure(let reason):
                storage.removePart(for: job.projectId)
                markFailed(job, reason: reason)
            }
        case .failure(let reason):
            storage.removePart(for: job.projectId)
            markFailed(job, reason: reason == .network && isInInterruptionWindow ? .interrupted : reason)
        }
        startNextJobs()
    }

    private func markFailed(_ job: DownloadJob, reason: DownloadFailureReason) {
        failedJobs[job.projectId] = job
        setState(.failed(reason), for: job.projectId)
        onJobFailed?(job, reason)
    }

    private func markCompleted(_ job: DownloadJob) {
        completedJobs[job.projectId] = job
        setState(.completed, for: job.projectId)
    }

    private func removeCompletedRow(projectId: String) {
        completedJobs.removeValue(forKey: projectId)
        clearState(for: projectId)
    }

    private func isRunning(_ job: DownloadJob) -> Bool {
        runningJobs[job.projectId]?.job.id == job.id
    }

    private func setState(_ phase: DownloadPhase, for projectId: String) {
        if let existing = states[projectId], isSameOnScreen(existing, phase) { return }
        states[projectId] = phase
    }

    private func clearState(for projectId: String) {
        guard states[projectId] != nil else { return }
        states.removeValue(forKey: projectId)
    }

    private func isSameOnScreen(_ lhs: DownloadPhase, _ rhs: DownloadPhase) -> Bool {
        if case .downloading = lhs, case .downloading = rhs {
            return Int(lhs.fraction * 100) == Int(rhs.fraction * 100)
        }
        return lhs == rhs
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}

extension DownloadQueueManager {

    /// True while the GSX file of `projectId` is waiting, downloading or paused.
    func isDownloading(projectId: String) -> Bool {
        states[projectId]?.isActive == true
    }

    /// Emits the current value, then every change of `isDownloading(projectId:)`.
    func isDownloadingPublisher(projectId: String) -> AnyPublisher<Bool, Never> {
        $states
            .map { $0[projectId]?.isActive == true }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    static func isDownloading(projectId: String) -> Bool {
        current?.isDownloading(projectId: projectId) ?? false
    }

    static func isDownloadingPublisher(projectId: String) -> AnyPublisher<Bool, Never> {
        current?.isDownloadingPublisher(projectId: projectId) ?? Just(false).eraseToAnyPublisher()
    }
}

private extension DownloadQueueManager {

    struct Waiting {
        let job: DownloadJob
        var link: GSXDownloadLink?
    }

    struct Running {
        let job: DownloadJob
        var link: GSXDownloadLink?
        var transport: DownloadJobTransport?
        var resumeData: Data?
        var received: Int64 = 0
        var total: Int64 = 0

        var remainingBytes: Int64 {
            max(total - received, 0)
        }
    }
}
