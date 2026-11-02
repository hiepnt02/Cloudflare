//
//  GsxUpdateCheck.swift
//  Quick3D
//

import Foundation

enum GsxUpdateResult: Equatable {
    case upToDate
    case updateAvailable(fileName: String)
    case fileRemoved
    case offline
    case checkFailed
    case sessionExpired
}

enum GsxUpdateCheck {

    static func evaluate(record: DownloadedGsx, detail: GsxDetailResult) -> GsxUpdateResult {
        switch detail {
        case .found(let fileName?, _):
            return fileName == record.fileName ? .upToDate : .updateAvailable(fileName: fileName)
        case .found(nil, _):
            return .fileRemoved
        case .offline:
            return .offline
        case .failed:
            return .checkFailed
        case .sessionExpired:
            return .sessionExpired
        }
    }

    static func respond(
        to result: GsxUpdateResult,
        displayName: String,
        prompter: DownloadPrompter,
        onDelete: @escaping () -> Void = {},
        onKeep: @escaping () -> Void = {},
        onSessionExpired: @escaping () -> Void = {},
        download: @escaping (_ fileName: String) -> Void
    ) {
        switch result {
        case .updateAvailable(let fileName):
            prompter.confirmUpdate(displayName: displayName) { download(fileName) }
        case .upToDate:
            prompter.showUpToDate(displayName: displayName)
        case .offline:
            prompter.showError(.network, displayName: displayName)
        case .fileRemoved:
            prompter.confirmRemovedFile(displayName: displayName, onDelete: onDelete, onKeep: onKeep)
        case .checkFailed:
            prompter.showCheckFailed(displayName: displayName)
        case .sessionExpired:
            onSessionExpired()
        }
    }
}
