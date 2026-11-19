//
//  ProjectZipFileName.swift
//  Quick3D
//

import Foundation

enum ProjectZipFileName {
    private static let dateFormat = "yyyy-MM-dd-HH-mm-ss"

    static func make(for date: Date, timeZone: TimeZone = .current) -> String {
        let stamp = date.toString(format: dateFormat, locale: Locale(identifier: "en_US_POSIX"), timeZone: timeZone)
        return "\(stamp).zip"
    }

    static func find(in folder: URL, preferredName: String? = nil) -> URL? {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            return nil
        }
        let zips = contents.filter { $0.pathExtension.lowercased() == "zip" }
        if let preferredName = preferredName, let match = zips.first(where: { $0.lastPathComponent == preferredName }) {
            return match
        }
        return zips.min { $0.lastPathComponent < $1.lastPathComponent }
    }

    static var defaultCameraDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Camera")
    }

    static func fileNameForSaving(source: URL, date: Date, reusingFrom folder: URL?, cameraDirectory: URL = defaultCameraDirectory, timeZone: TimeZone = .current) -> String {
        if isInside(source, directory: cameraDirectory) {
            return source.lastPathComponent
        }
        if let folder = folder, let existing = find(in: folder) {
            return existing.lastPathComponent
        }
        return make(for: date, timeZone: timeZone)
    }

    static func copy(from source: URL, toFolder folder: URL, date: Date, reusingFrom previous: URL?, cameraDirectory: URL = defaultCameraDirectory, timeZone: TimeZone = .current) -> URL? {
        let name = fileNameForSaving(source: source, date: date, reusingFrom: previous, cameraDirectory: cameraDirectory, timeZone: timeZone)
        let destination = folder.appendingPathComponent(name)
        return FileManager.default.secureCopyItem(at: source, to: destination) ? destination : nil
    }

    private static func isInside(_ url: URL, directory: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        let root = directory.resolvingSymlinksInPath().standardizedFileURL.path
        return path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }
}
