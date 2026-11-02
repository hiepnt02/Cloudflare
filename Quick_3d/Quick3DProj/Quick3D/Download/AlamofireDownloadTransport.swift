//
//  AlamofireDownloadTransport.swift
//  Quick3D
//

import Foundation
import Alamofire

final class AlamofireDownloadTransport: DownloadJobTransport {

    private let session: Session
    private var request: DownloadRequest?
    private var isStopped = false

    init(session: Session) {
        self.session = session
    }

    func start(
        job: DownloadJob,
        link: GSXDownloadLink,
        destination: URL,
        resumeData: Data?,
        onProgress: @escaping (Int64, Int64) -> Void,
        onFinish: @escaping (DownloadJobOutcome) -> Void
    ) {
        isStopped = false
        let to: DownloadRequest.Destination = { _, _ in
            (destination, [.removePreviousFile, .createIntermediateDirectories])
        }

        let request: DownloadRequest
        if let resumeData {
            request = session.download(resumingWith: resumeData, to: to)
        } else {
            request = session.download(link.url, headers: HTTPHeaders(link.headers), to: to)
        }

        self.request = request
            .downloadProgress { progress in
                onProgress(progress.completedUnitCount, progress.totalUnitCount)
            }
            .response { [weak self] response in
                debugPrint(response)
                guard let self, !self.isStopped else { return }
                self.request = nil
                onFinish(Self.outcome(
                    statusCode: response.response?.statusCode,
                    error: response.error,
                    fileURL: response.fileURL
                ))
            }
    }

    func pause(completion: @escaping (Data?) -> Void) {
        isStopped = true
        guard let request else {
            completion(nil)
            return
        }
        self.request = nil
        request.cancel(byProducingResumeData: completion)
    }

    func cancel() {
        isStopped = true
        request?.cancel()
        request = nil
    }

    static func outcome(statusCode: Int?, error: AFError?, fileURL: URL?) -> DownloadJobOutcome {
        if let statusCode, !(200..<300).contains(statusCode) {
            switch statusCode {
            case 401, 403: return .failure(.unauthorized)
            case 500..<600: return .failure(.server)
            default: return .failure(.invalidResponse)
            }
        }
        if let error {
            return .failure(reason(for: error.underlyingError ?? error))
        }
        guard let fileURL else { return .failure(.invalidResponse) }
        return .success(fileURL)
    }

    private static func reason(for error: Error) -> DownloadFailureReason {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteOutOfSpaceError
            || nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(ENOSPC) {
            return .storageFull
        }
        if nsError.domain == NSURLErrorDomain {
            return .network
        }
        return .unknown
    }
}

final class AppDownloadTransportFactory: DownloadJobTransportFactory {

    let session: Session

    init(session: Session = AF) {
        self.session = session
    }

    func transport(for job: DownloadJob) -> DownloadJobTransport {
        AlamofireDownloadTransport(session: session)
    }
}
