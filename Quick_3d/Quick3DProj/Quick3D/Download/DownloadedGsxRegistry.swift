//
//  DownloadedGsxRegistry.swift
//  Quick3D
//

import Foundation

struct DownloadedGsx: Codable, Equatable {
    let projectId: String
    let fileName: String
    let bytes: Int64
    let downloadedAt: Date
    var keptMissingFile: Bool = false
}

extension DownloadedGsx {
    private enum CodingKeys: String, CodingKey {
        case projectId, fileName, bytes, downloadedAt, keptMissingFile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projectId = try container.decode(String.self, forKey: .projectId)
        fileName = try container.decode(String.self, forKey: .fileName)
        bytes = try container.decode(Int64.self, forKey: .bytes)
        downloadedAt = try container.decode(Date.self, forKey: .downloadedAt)
        keptMissingFile = try container.decodeIfPresent(Bool.self, forKey: .keptMissingFile) ?? false
    }
}

final class DownloadedGsxRegistry: ObservableObject {

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GSXDownloaded", isDirectory: true)
    }

    private struct Payload: Codable {
        var version = 1
        var records: [DownloadedGsx]
    }

    @Published private(set) var records: [String: DownloadedGsx] = [:]

    private let directory: URL
    private let fileManager: FileManager
    private var logoutObserver: NSObjectProtocol?

    init(
        directory: URL = DownloadedGsxRegistry.defaultDirectory,
        fileManager: FileManager = .default,
        notificationCenter: NotificationCenter = .default
    ) {
        self.directory = directory
        self.fileManager = fileManager
        load()
        logoutObserver = notificationCenter.addObserver(forName: .userDidLogout, object: nil, queue: nil) { [weak self] _ in
            self?.removeAll()
        }
    }

    deinit {
        logoutObserver.map(NotificationCenter.default.removeObserver)
    }

    func record(for projectId: String) -> DownloadedGsx? {
        guard let record = records[projectId], fileManager.fileExists(atPath: fileURL(of: record).path) else { return nil }
        return record
    }

    func fileURL(of record: DownloadedGsx) -> URL {
        projectDirectory(record.projectId).appendingPathComponent(record.fileName)
    }

    @discardableResult
    func store(partURL: URL, projectId: String, fileName: String) -> Bool {
        (try? moveIntoPlace(partURL: partURL, projectId: projectId, fileName: fileName)) != nil
    }

    func finalize(partURL: URL, projectId: String, fileName: String) -> Result<Void, DownloadFailureReason> {
        guard GsxFileValidator.isGsx(at: partURL) else {
            try? fileManager.removeItem(at: partURL)
            return .failure(.invalidResponse)
        }
        do {
            try moveIntoPlace(partURL: partURL, projectId: projectId, fileName: fileName)
            return .success(())
        } catch {
            try? fileManager.removeItem(at: partURL)
            return .failure(Self.failureReason(for: error))
        }
    }

    static func failureReason(for error: Error) -> DownloadFailureReason {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteOutOfSpaceError
            || nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(ENOSPC) {
            return .storageFull
        }
        return .unknown
    }

    private func moveIntoPlace(partURL: URL, projectId: String, fileName: String) throws {
        let name = (fileName as NSString).lastPathComponent
        guard !name.isEmpty, name != ".", name != "..", fileManager.fileExists(atPath: partURL.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        prepareRoot()
        let projectDirectory = projectDirectory(projectId)
        try fileManager.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        let destination = projectDirectory.appendingPathComponent(name)
        let bytes = (try fileManager.attributesOfItem(atPath: partURL.path)[.size] as? NSNumber)?.int64Value ?? 0

        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: partURL)
        } else {
            try fileManager.moveItem(at: partURL, to: destination)
        }
        if let old = records[projectId], old.fileName != name {
            try? fileManager.removeItem(at: projectDirectory.appendingPathComponent(old.fileName))
        }
        records[projectId] = DownloadedGsx(projectId: projectId, fileName: name, bytes: bytes, downloadedAt: Date())
        save()
    }

    func setKeptMissingFile(_ kept: Bool, for projectId: String) {
        guard var record = records[projectId], record.keptMissingFile != kept else { return }
        record.keptMissingFile = kept
        records[projectId] = record
        save()
    }

    func remove(projectIds: [String]) {
        guard !projectIds.isEmpty else { return }
        for projectId in projectIds {
            try? fileManager.removeItem(at: projectDirectory(projectId))
            records.removeValue(forKey: projectId)
        }
        save()
    }

    func removeAll() {
        try? fileManager.removeItem(at: directory)
        records = [:]
    }

    func attach(to queue: DownloadQueueManager) {
        queue.fileFinalizer = { [weak self] projectId, fileName, partURL in
            self?.finalize(partURL: partURL, projectId: projectId, fileName: fileName) ?? .failure(.unknown)
        }
    }

    static func purgeOrphans(
        isSignedIn: Bool,
        directory: URL = DownloadedGsxRegistry.defaultDirectory,
        fileManager: FileManager = .default
    ) {
        guard !isSignedIn else { return }
        try? fileManager.removeItem(at: directory)
    }

    private var registryURL: URL {
        directory.appendingPathComponent("registry.json")
    }

    private func projectDirectory(_ projectId: String) -> URL {
        let safe = String(projectId.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" ? $0 : "_" })
        return directory.appendingPathComponent(safe.isEmpty ? "_" : safe, isDirectory: true)
    }

    private func prepareRoot() {
        guard !fileManager.fileExists(atPath: directory.path) else { return }
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    private func load() {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: registryURL),
              let payload = try? decoder.decode(Payload.self, from: data) else {
            try? fileManager.removeItem(at: directory)
            return
        }
        let present = payload.records.filter { fileManager.fileExists(atPath: fileURL(of: $0).path) }
        records = Dictionary(present.map { ($0.projectId, $0) }, uniquingKeysWith: { _, latest in latest })
        if present.count != payload.records.count { save() }
    }

    private func save() {
        prepareRoot()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(Payload(records: Array(records.values))) else { return }
        try? data.write(to: registryURL, options: .atomic)
    }
}
