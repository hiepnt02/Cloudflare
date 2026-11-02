//
//  GSXDownloadLinkProvider.swift
//  Quick3D
//

import Foundation
import Alamofire

struct GSXDownloadLink: Equatable {
    let url: URL

    let headers: [String: String]

    let expectedBytes: Int64?
}

protocol GSXDownloadLinkProvider {
    func link(
        for job: DownloadJob,
        completion: @escaping (Result<GSXDownloadLink, DownloadFailureReason>) -> Void
    )
}

struct ARGsxLinkProvider: GSXDownloadLinkProvider {
    var baseURL = URL(string: Constant.baseUrl)!
    var cookieFetcher: ProjectCookieFetching = AFProjectCookieFetcher()

    func link(
        for job: DownloadJob,
        completion: @escaping (Result<GSXDownloadLink, DownloadFailureReason>) -> Void
    ) {
        guard !job.projectId.isEmpty, !job.fileName.isEmpty else {
            completion(.failure(.invalidResponse))
            return
        }
        let url = baseURL
            .appendingPathComponent("project_\(job.projectId)")
            .appendingPathComponent("AR")
            .appendingPathComponent(job.fileName)
        let cookieURL = baseURL
            .appendingPathComponent("api/v1/project")
            .appendingPathComponent(job.projectId)
            .appendingPathComponent("cookie")
        cookieFetcher.fetchCookie(from: cookieURL) { result in
            completion(result.map { GSXDownloadLink(url: url, headers: [:], expectedBytes: nil) })
        }
    }
}

protocol ProjectCookieFetching {
    func fetchCookie(from url: URL, completion: @escaping (Result<Void, DownloadFailureReason>) -> Void)
}

struct AFProjectCookieFetcher: ProjectCookieFetching {
    var session: Session = AF

    func fetchCookie(from url: URL, completion: @escaping (Result<Void, DownloadFailureReason>) -> Void) {
        session.request(url).response { response in
            completion(Self.result(statusCode: response.response?.statusCode, error: response.error))
        }
    }

    static func result(statusCode: Int?, error: AFError?) -> Result<Void, DownloadFailureReason> {
        if let statusCode, !(200..<300).contains(statusCode) {
            switch statusCode {
            case 401, 403: return .failure(.unauthorized)
            case 500..<600: return .failure(.server)
            default: return .failure(.invalidResponse)
            }
        }
        if let error {
            let underlying = error.underlyingError ?? error
            return .failure((underlying as NSError).domain == NSURLErrorDomain ? .network : .unknown)
        }
        return statusCode == nil ? .failure(.invalidResponse) : .success(())
    }
}
