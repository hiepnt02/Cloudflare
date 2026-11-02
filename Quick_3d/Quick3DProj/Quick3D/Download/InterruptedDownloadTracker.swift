//
//  InterruptedDownloadTracker.swift
//  Quick3D
//

import Combine
import UIKit

/// Keeps a small on-disk list of the downloads that are waiting or running so that, if the app
/// is killed, the next launch can show them as failed rows the user can retry.
final class InterruptedDownloadTracker {

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GSXInterrupted", isDirectory: true)
    }

    static func currentAccountKey() -> String? {
        guard let info = UserSession.shared.userInfo else { return nil }
        return info.userId ?? info.email
    }

    struct Entry: Codable, Equatable {
        let projectId: String
        let displayName: String
        let fileName: String
    }

    struct Snapshot: Codable, Equatable {
        var version = 1
        var account: String?
        var jobs: [Entry]
    }

    private let queue: DownloadQueueManager
    private let directory: URL
    private let fileManager: FileManager
    private let notificationCenter: NotificationCenter
    private let accountKey: () -> String?
    private let interruptionGrace: TimeInterval

    private var statesSubscription: AnyCancellable?
    private var observers: [NSObjectProtocol] = []
    private var windowReset: DispatchWorkItem?

    private var fileURL: URL {
        directory.appendingPathComponent("snapshot.json")
    }

    init(
        queue: DownloadQueueManager,
        isSignedIn: Bool = UserSession.shared.sessionId != nil,
        accountKey: @escaping () -> String? = InterruptedDownloadTracker.currentAccountKey,
        directory: URL = InterruptedDownloadTracker.defaultDirectory,
        fileManager: FileManager = .default,
        notificationCenter: NotificationCenter = .default,
        interruptionGrace: TimeInterval = Constant.downloadInterruptionGrace
    ) {
        self.queue = queue
        self.accountKey = accountKey
        self.directory = directory
        self.fileManager = fileManager
        self.notificationCenter = notificationCenter
        self.interruptionGrace = interruptionGrace

        // Read and delete before subscribing: the first emission of `$states` is empty and would
        // otherwise overwrite the snapshot, and deleting first makes the list show only once.
        let snapshot = takeSnapshot()
        let restored = Self.jobsToRestore(snapshot, isSignedIn: isSignedIn, currentAccount: accountKey())
        queue.restoreInterrupted(restored)

        statesSubscription = queue.$states
            .map { Set($0.filter { $0.value.isActive }.keys) }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.persist() }

        observeLifecycle()
    }

    deinit {
        observers.forEach(notificationCenter.removeObserver(_:))
        windowReset?.cancel()
    }

    /// Jobs of `snapshot` that may be shown: the user is signed in and the snapshot is theirs.
    static func jobsToRestore(_ snapshot: Snapshot?, isSignedIn: Bool, currentAccount: String?) -> [DownloadJob] {
        guard isSignedIn,
              let snapshot,
              let account = snapshot.account,
              account == currentAccount else { return [] }
        return snapshot.jobs.map {
            DownloadJob(projectId: $0.projectId, displayName: $0.displayName, fileName: $0.fileName)
        }
    }

    private func takeSnapshot() -> Snapshot? {
        defer { removeFile() }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    private func persist() {
        let jobs = queue.activeJobs
        guard !jobs.isEmpty, let account = accountKey() else {
            removeFile()
            return
        }
        let snapshot = Snapshot(
            account: account,
            jobs: jobs.map { Entry(projectId: $0.projectId, displayName: $0.displayName, fileName: $0.fileName) }
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        prepareDirectory()
        try? data.write(to: fileURL, options: .atomic)
    }

    private func removeFile() {
        try? fileManager.removeItem(at: fileURL)
    }

    private func prepareDirectory() {
        guard !fileManager.fileExists(atPath: directory.path) else { return }
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    private func observeLifecycle() {
        observers.append(notificationCenter.addObserver(forName: .userDidLogout, object: nil, queue: nil) { [weak self] _ in
            self?.removeFile()
        })
        observers.append(notificationCenter.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.windowReset?.cancel()
            self?.queue.isInInterruptionWindow = true
        })
        observers.append(notificationCenter.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.closeInterruptionWindow(after: self?.interruptionGrace ?? 0)
        })
    }

    private func closeInterruptionWindow(after delay: TimeInterval) {
        windowReset?.cancel()
        let reset = DispatchWorkItem { [weak self] in
            self?.queue.isInInterruptionWindow = false
        }
        windowReset = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: reset)
    }
}
