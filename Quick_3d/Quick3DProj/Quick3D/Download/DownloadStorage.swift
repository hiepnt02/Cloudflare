//
//  DownloadStorage.swift
//  Quick3D
//

import Foundation

final class DownloadStorage {

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GSXDownloads", isDirectory: true)
    }

    let directory: URL

    private let availableCapacity: () -> Int64?
    private let fileManager = FileManager.default

    init(
        directory: URL = DownloadStorage.defaultDirectory,
        availableCapacity: @escaping () -> Int64? = DownloadStorage.volumeAvailableCapacity
    ) {
        self.directory = directory
        self.availableCapacity = availableCapacity
    }

    static func hasSpace(needed: Int64?, reserved: Int64, available: Int64) -> Bool {
        let (total, overflow) = (needed ?? 0).addingReportingOverflow(reserved)
        return !overflow && total <= available
    }

    func canStore(bytes: Int64?, reserved: Int64) -> Bool {
        guard let available = availableCapacity() else { return true }
        return Self.hasSpace(needed: bytes, reserved: reserved, available: available)
    }

    var freeBytes: Int64? {
        availableCapacity()
    }

    static func volumeAvailableCapacity() -> Int64? {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    func partURL(for projectId: String) -> URL {
        prepareDirectory()
        return directory.appendingPathComponent(Self.fileName(for: projectId) + ".gsx.part")
    }

    func removePart(for projectId: String) {
        try? fileManager.removeItem(at: directory.appendingPathComponent(Self.fileName(for: projectId) + ".gsx.part"))
    }

    func purgeAll() {
        try? fileManager.removeItem(at: directory)
        prepareDirectory()
    }

    private static func fileName(for projectId: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let name = String(projectId.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        return name.isEmpty ? "_" : name
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
}
