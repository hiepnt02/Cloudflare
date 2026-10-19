//
//  UploadPhase.swift
//  Quick3D
//
//  Created by Ha Nguyen on 9/9/26.
//

import Foundation

enum UploadFailureReason: Equatable {
    case network
    case businessError
    case unknown
}

enum UploadPhase: Equatable {
    case idle
    case waiting
    case uploading(Double)

    var isUploading: Bool {
        if case .uploading = self { return true }
        return false
    }

    var isActive: Bool {
        switch self {
        case .waiting, .uploading:
            return true
        case .idle:
            return false
        }
    }

    var progress: Double {
        if case .uploading(let value) = self { return value }
        return 0
    }
}
