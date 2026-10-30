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
    let refGPS: ReferenceGPS
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
        let georeference: GaussianSplatGeoreference?
        if let metadata = job.value?.metadata {
            do {
                georeference = try await makeGeoreference(metadata: metadata, projectId: projectId)
            } catch {
                // Keep legacy/local rendering available if the project CRS endpoint is unavailable.
                print("[gsplat] georeference failed; rendering in local coordinates: \(error)")
                georeference = nil
            }
        } else {
            georeference = nil
        }
        return GsxProjectFile(url: fileURL, georeference: georeference)
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
        guard metadata.csType == "LOCAL_ENU_CS",
              metadata.offset.count == 3,
              metadata.rvec.count == 3,
              metadata.offset.allSatisfy({ $0.isFinite }),
              metadata.rvec.allSatisfy({ $0.isFinite }),
              metadata.scale.isFinite,
              metadata.scale != 0 else {
            throw GeoreferenceError.invalidMetadata
        }

        let geographicBasis = enuBasis(metadata.refGPS)
        var projectedBasis: [SIMD3<Double>] = []
        for point in geographicBasis {
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

        let rvec = SIMD3<Double>(metadata.rvec[0], metadata.rvec[1], metadata.rvec[2])
        let angle = simd_length(rvec)
        let rotation = angle > 0
            ? simd_double4x4(simd_quatd(angle: angle, axis: rvec / angle))
            : matrix_identity_double4x4
        let scaledRotation = simd_double4x4(columns: (
            rotation.columns.0 * metadata.scale,
            rotation.columns.1 * metadata.scale,
            rotation.columns.2 * metadata.scale,
            SIMD4<Double>(SIMD3<Double>(metadata.offset[0], metadata.offset[1], metadata.offset[2]), 1)
        ))
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
        case coordinateTransformFailed
        case invalidProjectionBasis
    }
}
