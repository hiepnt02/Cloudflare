//
//  GsxFileValidator.swift
//  Quick3D
//

import Foundation

enum GsxFileValidator {

    static let magic: [UInt8] = Array("GSX1".utf8)

    static func isGsx(at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: magic.count) else { return false }
        return Array(head) == magic
    }
}
