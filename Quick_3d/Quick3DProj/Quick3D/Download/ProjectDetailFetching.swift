//
//  ProjectDetailFetching.swift
//  Quick3D
//

import Foundation
import Alamofire

enum GsxDetailResult: Equatable {
    case found(fileName: String?, name: String?)
    case offline
    case failed
    case sessionExpired

    private static let connectionErrors: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff,
        .cannotFindHost, .cannotConnectToHost, .callIsActive,
    ]

    static func classify(statusCode: Int?, error: Error?, detail: ProjectDetail?) -> GsxDetailResult {
        if statusCode == 401 || statusCode == 403 { return .sessionExpired }
        if let error {
            let underlying = (error as? AFError)?.underlyingError ?? error
            if let urlError = underlying as? URLError, connectionErrors.contains(urlError.code) { return .offline }
            return .failed
        }
        guard let detail else { return .failed }
        return .found(fileName: detail.gsxFileName, name: detail.name)
    }
}

protocol ProjectDetailFetching: AnyObject {
    func fetchProjectDetail(projectId: String) async -> GsxDetailResult
}
