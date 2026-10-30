//
//  GsxProject.swift
//  Quick3D
//

import Alamofire
import Foundation
import simd

struct GaussianGeoMetadata: Decodable {
    struct ReferenceGPS: Decodable {
        let latitude: Double
        let longitude: Double
        let altitude: Double
    }

    let csType: String
    let refGPS: ReferenceGPS?
    let offset: [Double]
    let rvec: [Double]
    let scale: Double

    enum CodingKeys: String, CodingKey {
        case csType = "cs_type"
        case refGPS = "ref_GPS"
        case offset
        case rvec
        case scale
    }
}

struct GsxProjectFile: @unchecked Sendable {
    let url: URL
    let georeference: GaussianSplatGeoreference?
}

struct GaussianSplatGeoreference: @unchecked Sendable {
    /// Maps PLY-local coordinates to project CRS coordinates.
    let projectFromPly: simd_double4x4
    /// Shift that places project coordinates in a local frame before centering the splat node.
    let referenceShift: SIMD3<Double>
}

/// Where a project's Gaussian splats come from and how many of them a device keeps loaded.
enum GsxProject {
    /// Project list entries do not consistently expose GSX; use the converter lookup.
    static func isAvailable(projectId: String) async -> Bool {
        struct Lookup: Decodable { let outputKey: String? }
        let url = URL(string: Constant.baseUrl + "api/v1/convert/gsplat/by-project/\(projectId)")!
        let response = await AF.request(url, requestModifier: { $0.timeoutInterval = 15 })
            .validate().serializingDecodable(Lookup.self).response
        return response.value?.outputKey?.isEmpty == false
    }

    /// Splats kept loaded. 8 GB phones report ~7.4 GiB, so the tiers sit below the nominal sizes.
    static var defaultBudget: Int {
        let gb = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        if gb >= 7 { return 5_000_000 }
        if gb >= 5 { return 2_000_000 }
        return 1_000_000
    }

    /// The project's latest converted splat file (the one the web viewer streams), or nil when
    /// it has none. Also installs the CloudFront cookies the file needs.
    static func file(projectId: String) async -> GsxProjectFile? {
        let jobURL = URL(string: Constant.baseUrl + "api/v1/convert/gsplat/by-project/\(projectId)")!
        let job = await AF.request(jobURL).validate().serializingDecodable(JobResponse.self).response
        // 2238 serves GSX via a presigned URL; older servers still use outputKey.
        let signedURL = try? await downloadURL(projectId: projectId, type: "GSX")
        let key = job.value?.outputKey?.drop(while: { $0 == "/" })
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        guard let fileURL = signedURL ?? key.flatMap({ URL(string: Constant.baseUrl + $0) }) else {
            // 404: the project has no converted splats.
            if let error = job.error, job.response?.statusCode != 404 {
                print("[gsplat] by-project failed: \(error)")
            }
            return nil
        }
        // The file sits behind CloudFront: get this project's signed cookies first. They land in
        // HTTPCookieStorage.shared, which GsxStream's session also uses.
        if signedURL == nil {
            let cookieURL = URL(string: Constant.baseUrl + "api/v1/project/\(projectId)/cookie")!
            let cookie = await AF.request(cookieURL).serializingData().response
            if cookie.response?.statusCode != 200 {
                print("[gsplat] project cookie failed: HTTP \(cookie.response?.statusCode ?? 0)")
            }
        }
        do {
            // Deployed 2238 stores JSON separately; retain inline metadata for older projects.
            let data = await metadataData(projectId: projectId)
            let metadata = try data.map { try JSONDecoder().decode(GaussianGeoMetadata.self, from: $0) }
                ?? job.value?.metadata
            var georeference: GaussianSplatGeoreference?
            if let metadata {
                georeference = try await makeGeoreference(metadata: metadata, projectId: projectId)
                print("[gsplat] applied offset JSON: \(metadata.csType)")
            }
            try Task.checkCancellation()
            return GsxProjectFile(url: fileURL, georeference: georeference)
        } catch {
            print("[gsplat] cannot load project georeference: \(error)")
            return nil
        }
    }

    private static func downloadURL(projectId: String, type: String) async throws -> URL? {
        let endpoint = URL(string: Constant.baseUrl + "api/v1/project/\(projectId)/ARdownload/\(type)")!
        let response = await AF.request(endpoint).validate().serializingString().response
        if response.response?.statusCode == 404 { return nil }
        let path = try response.result.get()
        guard let url = URL(string: path), ["https", "http"].contains(url.scheme ?? "") else {
            throw GeoreferenceError.invalidFileURL
        }
        return url
    }

    private static func metadataData(projectId: String) async -> Data? {
        do {
            guard let url = try await downloadURL(projectId: projectId, type: "JSON") else { return nil }
            return try await AF.request(url).validate().serializingData().value
        } catch {
            // JSON is optional, as in Web 2238. S3 may return 403/404 for an absent file.
            print("[gsplat] offset JSON unavailable: \(error)")
            return nil
        }
    }

    private struct JobResponse: Decodable {
        let jobId: String?
        let outputKey: String?
        let metadata: GaussianGeoMetadata?
    }

    private struct GeographicPosition {
        let latitude: Double
        let longitude: Double
        let altitude: Double
    }

    private static let enuBasisStep = 10.0
    private static let wgs84A = 6_378_137.0
    private static let wgs84E2 = 6.6943799901413165e-3

    /// Mirrors Web SC_QUICK-2238: map the PLY-local -> ENU -> project-CRS transform
    /// using four points, so we do not need to transform every splat.
    private static func makeGeoreference(
        metadata: GaussianGeoMetadata,
        projectId: String
    ) async throws -> GaussianSplatGeoreference {
        guard metadata.offset.count == 3,
              metadata.rvec.count == 3,
              metadata.offset.allSatisfy({ $0.isFinite }),
              metadata.rvec.allSatisfy({ $0.isFinite }),
              metadata.scale.isFinite,
              metadata.scale > 0 else {
            throw GeoreferenceError.invalidMetadata
        }

        let rvec = SIMD3<Double>(metadata.rvec[0], metadata.rvec[1], metadata.rvec[2])
        let angle = simd_length(rvec)
        guard angle.isFinite else { throw GeoreferenceError.invalidMetadata }
        let rotation = angle > 0
            ? simd_double4x4(simd_quatd(angle: angle, axis: rvec / angle))
            : matrix_identity_double4x4
        let offset = SIMD3<Double>(metadata.offset[0], metadata.offset[1], metadata.offset[2])
        // Web 2238: p_project/ENU = R(rvec) * (scale * p_PLY) + offset.
        let scaledRotation = simd_double4x4(columns: (
            rotation.columns.0 * metadata.scale,
            rotation.columns.1 * metadata.scale,
            rotation.columns.2 * metadata.scale,
            SIMD4<Double>(offset, 1)
        ))
        if metadata.csType == "PROJECTED_CS" {
            return GaussianSplatGeoreference(projectFromPly: scaledRotation, referenceShift: -offset)
        }
        guard metadata.csType == "LOCAL_ENU_CS", let gps = metadata.refGPS,
              [gps.latitude, gps.longitude, gps.altitude].allSatisfy({ $0.isFinite }),
              abs(gps.latitude) <= 90, abs(gps.longitude) <= 180 else {
            throw GeoreferenceError.invalidMetadata
        }
        let geographicBasis = enuBasis(gps)
        var projectedBasis: [SIMD3<Double>] = []
        for point in geographicBasis {
            try Task.checkCancellation()
            let location = LocationModel(
                latitude: point.latitude,
                longitude: point.longitude,
                altitude: point.altitude
            )
            guard let projected = try await PositionModel.transformLocations("EPSG:4979", location, projectId),
                  let x = Double(projected.x), let y = Double(projected.y), let z = Double(projected.z),
                  x.isFinite, y.isFinite, z.isFinite else {
                throw GeoreferenceError.coordinateTransformFailed
            }
            projectedBasis.append(SIMD3<Double>(x, y, z))
        }

        let origin = projectedBasis[0]
        let east = (projectedBasis[1] - origin) / enuBasisStep
        let north = (projectedBasis[2] - origin) / enuBasisStep
        let up = (projectedBasis[3] - origin) / enuBasisStep
        let projectFromENU = simd_double4x4(columns: (
            SIMD4<Double>(east, 0),
            SIMD4<Double>(north, 0),
            SIMD4<Double>(up, 0),
            SIMD4<Double>(origin, 1)
        ))
        let determinant = simd_determinant(projectFromENU)
        guard determinant.isFinite, abs(determinant) > 1e-12 else {
            throw GeoreferenceError.invalidProjectionBasis
        }

        let projectFromPly = projectFromENU * scaledRotation

        return GaussianSplatGeoreference(
            projectFromPly: projectFromPly,
            referenceShift: -origin
        )
    }

    private static func enuBasis(_ gps: GaussianGeoMetadata.ReferenceGPS) -> [GeographicPosition] {
        let radians = Double.pi / 180
        let latitude = gps.latitude * radians
        let longitude = gps.longitude * radians
        let sinLatitude = sin(latitude)
        let n = wgs84A / sqrt(1 - wgs84E2 * sinLatitude * sinLatitude)
        let origin = SIMD3<Double>(
            (n + gps.altitude) * cos(latitude) * cos(longitude),
            (n + gps.altitude) * cos(latitude) * sin(longitude),
            (n * (1 - wgs84E2) + gps.altitude) * sinLatitude
        )
        let axes = [
            SIMD3<Double>(-sin(longitude), cos(longitude), 0),
            SIMD3<Double>(-sin(latitude) * cos(longitude), -sin(latitude) * sin(longitude), cos(latitude)),
            SIMD3<Double>(cos(latitude) * cos(longitude), cos(latitude) * sin(longitude), sin(latitude))
        ]
        return [GeographicPosition(latitude: gps.latitude, longitude: gps.longitude, altitude: gps.altitude)] + axes.map { axis in
            let point = origin + axis * enuBasisStep
            let radial = hypot(point.x, point.y)
            var phi = atan2(point.z, radial * (1 - wgs84E2))
            for _ in 0..<12 {
                let radius = wgs84A / sqrt(1 - wgs84E2 * sin(phi) * sin(phi))
                phi = atan2(point.z + wgs84E2 * radius * sin(phi), radial)
            }
            let radius = wgs84A / sqrt(1 - wgs84E2 * sin(phi) * sin(phi))
            let altitude = abs(cos(phi)) > 1e-8
                ? radial / cos(phi) - radius
                : abs(point.z) - radius * (1 - wgs84E2)
            return GeographicPosition(
                latitude: phi / radians,
                longitude: atan2(point.y, point.x) / radians,
                altitude: altitude
            )
        }
    }

    private enum GeoreferenceError: Error {
        case invalidMetadata
        case invalidFileURL
        case coordinateTransformFailed
        case invalidProjectionBasis
    }
}
