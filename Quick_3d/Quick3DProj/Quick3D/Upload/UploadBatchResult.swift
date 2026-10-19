//
//  UploadBatchResult.swift
//  Quick3D
//
//  QU3DW-1423 — per-project outcome of one upload batch.
//

import Foundation

enum UploadJobOutcome: Equatable {
    case success
    case failure(UploadFailureReason)

    var isSuccess: Bool {
        self == .success
    }
}

struct UploadBatchResult: Equatable {

    struct Entry: Equatable, Identifiable {
        let id: UUID
        let catId: String
        let displayName: String
        let fileNames: [String]
        let outcome: UploadJobOutcome
    }

    private(set) var entries: [Entry] = []

    var isEmpty: Bool { entries.isEmpty }

    var successCount: Int {
        entries.filter { $0.outcome.isSuccess }.count
    }

    var failureCount: Int {
        entries.count - successCount
    }

    var hasFailure: Bool { failureCount > 0 }

    mutating func record(_ job: UploadJob, outcome: UploadJobOutcome) {
        entries.append(
            Entry(
                id: job.id,
                catId: job.catId,
                displayName: job.displayName,
                fileNames: job.fileNames,
                outcome: outcome
            )
        )
    }
}
