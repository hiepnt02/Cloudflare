//
//  GsxProject.swift
//  Quick3D
//

import Alamofire
import Foundation
import simd

/// Mirrors Web SC_QUICK-2238 (geoMetadata.ts): PLY-local -> project CRS, Z-up, metres.
struct GaussianSplatGeoreference {
    let projectFromPly: simd_double4x4
    /// Project coordinates of the PLY origin: splats are drawn relative to this when no point
    /// cloud fixes the scene origin.
    let referenceOrigin: SIMD3<Double>
}

/// geo_desc.json uploaded next to the PLY (LOCAL_ENU_CS, Atlas output) or the converted form
/// (PROJECTED_CS). offset / rvec / scale default to identity, as the server validator does.
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

    private enum CodingKeys: String, CodingKey {
        case csType = "cs_type"
        case refGPS = "ref_GPS"
        case offset, rvec, scale
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        csType = try c.decode(String.self, forKey: .csType)
        refGPS = try c.decodeIfPresent(ReferenceGPS.self, forKey: .refGPS)
        offset = try c.decodeIfPresent([Double].self, forKey: .offset) ?? [0, 0, 0]
        rvec = try c.decodeIfPresent([Double].self, forKey: .rvec) ?? [0, 0, 0]
        scale = try c.decodeIfPresent(Double.self, forKey: .scale) ?? 1
    }
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
    /// the project has none. Cheap: two requests at most, so streaming can start at once; the
    /// georeference is fetched separately (`georeference(projectId:)`).
    /// 2238 servers sign a URL for the GSX; older ones only expose outputKey behind CloudFront.
    static func fileURL(projectId: String) async -> URL? {
        if let signed = try? await downloadURL(projectId: projectId, type: "GSX") {
            return signed
        }
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

    /// `api/v1/project/{id}/ARdownload/{type}` answers a presigned URL as plain text, 404 when
    /// the project has no such file.
    private static func downloadURL(projectId: String, type: String) async throws -> URL? {
        let endpoint = URL(string: Constant.baseUrl + "api/v1/project/\(projectId)/ARdownload/\(type)")!
        let response = await AF.request(endpoint).validate().serializingString().response
        if response.response?.statusCode == 404 { return nil }
        let text = try response.result.get().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: text), ["https", "http"].contains(url.scheme ?? "") else {
            throw GeoreferenceError.invalidFileURL
        }
        return url
    }

    /// nil when the project has no geo JSON or it cannot be used; the splats then draw as they
    /// are, like the web viewer.
    static func georeference(projectId: String) async -> GaussianSplatGeoreference? {
        do {
            // 404: no geo JSON was uploaded with the PLY.
            guard let url = try await downloadURL(projectId: projectId, type: "JSON") else { return nil }
            let data = try await AF.request(url).validate().serializingData().value
            let metadata = try JSONDecoder().decode(GaussianGeoMetadata.self, from: data)
            return try await makeGeoreference(metadata: metadata, projectId: projectId)
        } catch {
            print("[gsplat] georeference unavailable: \(error)")
            return nil
        }
    }

    private struct JobResponse: Decodable {
        let jobId: String?
        let outputKey: String?
    }

    // MARK: - Georeference maths (same as Web geoMetadata.ts)

    private struct GeographicPosition {
        let latitude: Double
        let longitude: Double
        let altitude: Double
    }

    private static let enuBasisStep = 10.0
    private static let wgs84A = 6_378_137.0
    private static let wgs84E2 = 6.6943799901413165e-3

    private static func makeGeoreference(
        metadata: GaussianGeoMetadata,
        projectId: String
    ) async throws -> GaussianSplatGeoreference {
        guard metadata.offset.count == 3, metadata.rvec.count == 3,
              metadata.offset.allSatisfy({ $0.isFinite }), metadata.rvec.allSatisfy({ $0.isFinite }),
              metadata.scale.isFinite, metadata.scale > 0 else {
            throw GeoreferenceError.invalidMetadata
        }

        // p_out = R(rvec) * (scale * p_PLY) + offset, rvec as axis-angle in radians.
        let rvec = SIMD3<Double>(metadata.rvec[0], metadata.rvec[1], metadata.rvec[2])
        let angle = simd_length(rvec)
        let rotation = angle > 0
            ? simd_double4x4(simd_quatd(angle: angle, axis: rvec / angle))
            : matrix_identity_double4x4
        let offset = SIMD3<Double>(metadata.offset[0], metadata.offset[1], metadata.offset[2])
        let scaledRotation = simd_double4x4(columns: (
            rotation.columns.0 * metadata.scale,
            rotation.columns.1 * metadata.scale,
            rotation.columns.2 * metadata.scale,
            SIMD4<Double>(offset, 1)
        ))

        switch metadata.csType {
        case "PROJECTED_CS":
            return GaussianSplatGeoreference(projectFromPly: scaledRotation, referenceOrigin: offset)
        case "LOCAL_ENU_CS":
            guard let gps = metadata.refGPS,
                  [gps.latitude, gps.longitude, gps.altitude].allSatisfy({ $0.isFinite }),
                  abs(gps.latitude) <= 90, abs(gps.longitude) <= 180 else {
                throw GeoreferenceError.invalidMetadata
            }
            // Project the ENU origin and three 10 m axis points instead of every splat; the
            // server handles the project's horizontal and vertical CRS. The four requests go
            // out together: each is a pyproj run on the server, in series they add up.
            let basis = enuBasis(gps)
            var byIndex: [Int: SIMD3<Double>] = [:]
            try await withThrowingTaskGroup(of: (Int, TransformItem?).self) { group in
                for (index, point) in basis.enumerated() {
                    group.addTask { (index, try await projectPoint(point, projectId: projectId)) }
                }
                for try await (index, item) in group {
                    guard let converted = projectedPoint(item) else {
                        throw GeoreferenceError.coordinateTransformFailed
                    }
                    byIndex[index] = converted
                }
            }
            let projected = basis.indices.compactMap { byIndex[$0] }
            guard projected.count == 4 else { throw GeoreferenceError.coordinateTransformFailed }
            let origin = projected[0]
            let projectFromENU = simd_double4x4(columns: (
                SIMD4<Double>((projected[1] - origin) / enuBasisStep, 0),
                SIMD4<Double>((projected[2] - origin) / enuBasisStep, 0),
                SIMD4<Double>((projected[3] - origin) / enuBasisStep, 0),
                SIMD4<Double>(origin, 1)
            ))
            let determinant = simd_determinant(projectFromENU)
            guard determinant.isFinite, abs(determinant) > 1e-12 else {
                throw GeoreferenceError.invalidProjectionBasis
            }
            return GaussianSplatGeoreference(
                projectFromPly: projectFromENU * scaledRotation,
                referenceOrigin: origin
            )
        default:
            throw GeoreferenceError.invalidMetadata
        }
    }

    /// One await per call, outside any guard: keeps the async frame simple for the compiler.
    private static func projectPoint(_ point: GeographicPosition, projectId: String) async throws -> TransformItem? {
        let location = LocationModel(latitude: point.latitude, longitude: point.longitude, altitude: point.altitude)
        return try await PositionModel.transformLocations("EPSG:4979", location, projectId)
    }

    private static func projectedPoint(_ item: TransformItem?) -> SIMD3<Double>? {
        guard let item, let x = Double(item.x), let y = Double(item.y), let z = Double(item.z),
              x.isFinite, y.isFinite, z.isFinite else { return nil }
        return SIMD3<Double>(x, y, z)
    }

    /// ref_GPS plus the points 10 m east, north and up of it, as lat/lon/ellipsoidal height.
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
            SIMD3<Double>(-sinLatitude * cos(longitude), -sinLatitude * sin(longitude), cos(latitude)),
            SIMD3<Double>(cos(latitude) * cos(longitude), cos(latitude) * sin(longitude), sinLatitude)
        ]
        let reference = GeographicPosition(latitude: gps.latitude, longitude: gps.longitude, altitude: gps.altitude)
        return [reference] + axes.map { axis in
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
