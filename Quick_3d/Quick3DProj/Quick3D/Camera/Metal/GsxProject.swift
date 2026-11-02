//
//  GsxProject.swift
//  Quick3D
//

import Alamofire
import Foundation

/// Where a project's Gaussian splats come from and how many of them a device keeps loaded.
enum GsxProject {
    /// Splats kept loaded. 8 GB phones report ~7.4 GiB, so the tiers sit below the nominal sizes.
    static var defaultBudget: Int {
        let gb = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        if gb >= 7 { return 5_000_000 }
        if gb >= 5 { return 2_000_000 }
        return 1_000_000
    }

    /// The project's latest converted splat file (the one the web viewer streams), or nil when
    /// it has none. Also installs the CloudFront cookies the file needs.
    static func fileURL(projectId: String) async -> URL? {
        let jobURL = URL(string: Constant.baseUrl + "api/v1/convert/gsplat/by-project/\(projectId)")!
        let job = await AF.request(jobURL).validate().serializingDecodable(JobResponse.self).response
        // Converted files keep the uploaded name, which may contain spaces.
        guard let key = job.value?.outputKey?.drop(while: { $0 == "/" })
                .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let fileURL = URL(string: Constant.baseUrl + key) else {
            // 404: the project has no converted splats.
            if let error = job.error, job.response?.statusCode != 404 {
                print("[gsplat] by-project failed: \(error)")
            }
            return nil
        }
        // The file sits behind CloudFront: get this project's signed cookies first. They land in
        // HTTPCookieStorage.shared, which GsxStream's session also uses.
        let cookieURL = URL(string: Constant.baseUrl + "api/v1/project/\(projectId)/cookie")!
        let cookie = await AF.request(cookieURL).serializingData().response
        if cookie.response?.statusCode != 200 {
            print("[gsplat] project cookie failed: HTTP \(cookie.response?.statusCode ?? 0)")
        }
        return fileURL
    }

    private struct JobResponse: Decodable {
        let jobId: String?
        let outputKey: String?
    }
}
