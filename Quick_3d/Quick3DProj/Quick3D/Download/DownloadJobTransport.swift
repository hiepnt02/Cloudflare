//
//  DownloadJobTransport.swift
//  Quick3D
//

import Foundation

struct DownloadJob: Identifiable, Equatable {
    let id: UUID

    let projectId: String

    let displayName: String

    let fileName: String

    init(projectId: String, displayName: String, fileName: String) {
        self.id = UUID()
        self.projectId = projectId
        self.displayName = displayName
        self.fileName = fileName
    }
}

enum DownloadPhase: Equatable {
    case waiting
    case downloading(received: Int64, total: Int64)
    case paused(received: Int64, total: Int64)
    case completed
    case failed(DownloadFailureReason)

    var fraction: Double {
        switch self {
        case .downloading(let received, let total), .paused(let received, let total):
            guard total > 0 else { return 0 }
            return min(max(Double(received) / Double(total), 0), 1)
        case .waiting, .completed, .failed:
            return 0
        }
    }

    var isActive: Bool {
        switch self {
        case .waiting, .downloading, .paused: return true
        case .completed, .failed: return false
        }
    }
}

enum DownloadFailureReason: Error, Equatable {
    case network
    case interrupted
    case unauthorized
    case server
    case storageFull
    case invalidResponse
    case unknown
}

enum DownloadJobOutcome: Equatable {
    case success(URL)
    case failure(DownloadFailureReason)
}

enum DownloadAbortReason {
    case sessionEnded
}

protocol DownloadJobTransport: AnyObject {
    func start(
        job: DownloadJob,
        link: GSXDownloadLink,
        destination: URL,
        resumeData: Data?,
        onProgress: @escaping (_ received: Int64, _ total: Int64) -> Void,
        onFinish: @escaping (DownloadJobOutcome) -> Void
    )

    func pause(completion: @escaping (_ resumeData: Data?) -> Void)

    func cancel()
}

protocol DownloadJobTransportFactory {
    func transport(for job: DownloadJob) -> DownloadJobTransport
}
