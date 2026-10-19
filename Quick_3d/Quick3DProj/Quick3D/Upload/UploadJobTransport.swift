//
//  UploadJobTransport.swift
//  Quick3D
//
//  QU3DW-1423 — the one way the queue talks to the network.
//

import Foundation

protocol UploadJobTransport: AnyObject {
    func start(
        job: UploadJob,
        onProgress: @escaping (_ fraction: Double) -> Void,
        onFinish: @escaping (UploadJobOutcome) -> Void
    )

    func cancel()
}

protocol UploadJobTransportFactory {
    func transport(for job: UploadJob) -> UploadJobTransport
}

enum UploadAbortReason: Equatable {
    case sessionEnded
}
