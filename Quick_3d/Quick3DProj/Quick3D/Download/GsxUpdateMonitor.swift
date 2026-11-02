//
//  GsxUpdateMonitor.swift
//  Quick3D
//

import Foundation

struct GsxUpdateSummary: Equatable {
    struct Item: Equatable, Identifiable {
        let projectId: String
        let displayName: String
        var id: String { projectId }
    }

    var updates: [Item]
    var removed: [Item]

    var isEmpty: Bool { updates.isEmpty && removed.isEmpty }
}

final class GsxUpdateMonitor: ObservableObject {

    @Published private(set) var pendingSummary: GsxUpdateSummary?

    var isListVisible = true

    var onSessionExpired: (() -> Void)?

    private let registry: DownloadedGsxRegistry
    private let fetcher: ProjectDetailFetching
    private let isBusy: (String) -> Bool
    private let listName: (String) -> String?
    private let maxConcurrent: Int
    private var isChecking = false
    private var generation = 0
    private var logoutObserver: NSObjectProtocol?

    init(
        registry: DownloadedGsxRegistry,
        fetcher: ProjectDetailFetching,
        isBusy: @escaping (String) -> Bool = { _ in false },
        listName: @escaping (String) -> String? = { _ in nil },
        maxConcurrent: Int = 3,
        notificationCenter: NotificationCenter = .default
    ) {
        self.registry = registry
        self.fetcher = fetcher
        self.isBusy = isBusy
        self.listName = listName
        self.maxConcurrent = max(1, maxConcurrent)
        logoutObserver = notificationCenter.addObserver(forName: .userDidLogout, object: nil, queue: nil) { [weak self] _ in
            self?.generation += 1
            self?.isChecking = false
            self?.pendingSummary = nil
        }
    }

    deinit {
        logoutObserver.map(NotificationCenter.default.removeObserver)
    }

    @discardableResult
    func checkAll() -> Task<Void, Never>? {
        guard !isChecking else { return nil }
        let projectIds = registry.records.keys.filter { !isBusy($0) }.sorted()
        guard !projectIds.isEmpty else { return nil }

        isChecking = true
        let generation = generation
        let fetcher = fetcher
        let maxConcurrent = maxConcurrent
        return Task { @MainActor [weak self] in
            let answers = await Self.fetchDetails(of: projectIds, with: fetcher, maxConcurrent: maxConcurrent)
            self?.finishCheck(projectIds: projectIds, answers: answers, generation: generation)
        }
    }

    private static func fetchDetails(
        of projectIds: [String],
        with fetcher: ProjectDetailFetching,
        maxConcurrent: Int
    ) async -> [String: GsxDetailResult] {
        await withTaskGroup(of: (String, GsxDetailResult).self) { group in
            var waiting = projectIds[...]
            var answers: [String: GsxDetailResult] = [:]
            func askNext() {
                guard let projectId = waiting.popFirst() else { return }
                group.addTask { (projectId, await fetcher.fetchProjectDetail(projectId: projectId)) }
            }
            for _ in 0..<maxConcurrent { askNext() }
            while let (projectId, answer) = await group.next() {
                answers[projectId] = answer
                askNext()
            }
            return answers
        }
    }

    private func finishCheck(projectIds: [String], answers: [String: GsxDetailResult], generation: Int) {
        guard generation == self.generation else { return }
        isChecking = false
        if answers.values.contains(.sessionExpired) {
            onSessionExpired?()
            return
        }

        var summary = GsxUpdateSummary(updates: [], removed: [])
        for projectId in projectIds {
            guard let answer = answers[projectId], let record = registry.record(for: projectId), !isBusy(projectId) else { continue }
            let item = GsxUpdateSummary.Item(projectId: projectId, displayName: displayName(of: projectId, answer: answer))

            switch GsxUpdateCheck.evaluate(record: record, detail: answer) {
            case .updateAvailable:
                registry.setKeptMissingFile(false, for: projectId)
                summary.updates.append(item)
            case .upToDate:
                registry.setKeptMissingFile(false, for: projectId)
            case .fileRemoved where !record.keptMissingFile:
                summary.removed.append(item)
            case .fileRemoved, .offline, .checkFailed, .sessionExpired:
                break
            }
        }

        guard isListVisible, !summary.isEmpty else { return }
        pendingSummary = summary
    }

    private func displayName(of projectId: String, answer: GsxDetailResult) -> String {
        if case .found(_, let name?) = answer, !name.isEmpty { return name }
        return listName(projectId) ?? projectId
    }

    func keep(projectIds: [String]) {
        projectIds.forEach { registry.setKeptMissingFile(true, for: $0) }
        drop(projectIds)
    }

    func delete(projectIds: [String]) {
        registry.remove(projectIds: projectIds)
        drop(projectIds)
    }

    func discardPending() {
        pendingSummary = nil
    }

    private func drop(_ projectIds: [String]) {
        guard var summary = pendingSummary else { return }
        summary.updates.removeAll { projectIds.contains($0.projectId) }
        summary.removed.removeAll { projectIds.contains($0.projectId) }
        pendingSummary = summary.isEmpty ? nil : summary
    }
}
