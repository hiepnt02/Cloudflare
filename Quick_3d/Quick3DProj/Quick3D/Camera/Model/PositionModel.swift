//
//  PositionModel.swift
//  Quick3D
//
//  Created by Admin on 16/12/24.
//

import Foundation
import Alamofire
import CoreLocation
import Keys

fileprivate let WGS84_A = 6378137.0
fileprivate let WGS84_D = WGS84_A.radians
fileprivate let WGS84_IF = 298.257223563
fileprivate let WGS84_F  = 1.0 / WGS84_IF
fileprivate let WGS84_B = WGS84_A * (1 - WGS84_F)
fileprivate let WGS84_E = sqrt(2 * WGS84_F - WGS84_F * WGS84_F)

fileprivate func geoToEcef(latitude: Double, longitude: Double, altitude: Double) -> (x: Double, y: Double, z: Double) {
    
    let latRad = latitude.radians
    let lonRad = longitude.radians
    
    let d = WGS84_E * sin(latRad);
    let N = WGS84_A / sqrt(1.0 - d * d);

    let x = (N + altitude) * cos(latRad) * cos(lonRad);
    let y = (N + altitude) * cos(latRad) * sin(lonRad);
    let z = ((1 - WGS84_E * WGS84_E) * N + altitude) * sin(latRad);
    
    return (x: x, y:y, z: z)
}

fileprivate func ecefToGeo(x: Double, y: Double, z: Double) -> (latitude: Double, longitude: Double, altitude: Double) {
    
    var latRad = -1.0
    var lonRad = -1.0
    var alt = 0.0
    
    let p = sqrt(x * x + y * y);
    
    if (p != 0) {
        lonRad = atan2(y, x);
    } else {
        lonRad = 0;
    }
    
    if (p < WGS84_A * 1e-16) {
        latRad = copysign(.pi, z);
        alt = fabs(z) - WGS84_B;
        return (latitude: latRad.degrees, longitude: lonRad.degrees, altitude: alt)
    }
    
    let P = p / WGS84_A;
    let e_c = sqrt(1.0 - WGS84_E * WGS84_E);
    let Z = fabs(z) * e_c / WGS84_A;
    
    var S = Z;
    var C = e_c * P;
    
    var prev_C = -1.0;
    var prev_S = -1.0;
    
    var A_n = 0.0
    var B_n = 0.0
    var D_n = 0.0
    var F_n = 0.0
    
    for _ in 0..<10 {
        A_n = sqrt(S * S + C * C)
        D_n = Z * A_n * A_n * A_n + WGS84_E * WGS84_E * S * S * S
        F_n = P * A_n * A_n * A_n - WGS84_E * WGS84_E * C * C * C
        B_n = 1.5 * WGS84_E * S * C * C * (A_n * (P * S - Z * C) - WGS84_E * S * C)
        
        S = D_n * F_n - B_n * S
        C = F_n * F_n - B_n * C
        
        
        if (S > C) {
            C = C / S
            S = 1
        } else {
            S = S / C
            C = 1
        }
        
        if (fabs(S - prev_S) < 1e-16 && fabs(C - prev_C) < 1e-16) {
            break
        }
        prev_S = S
        prev_C = C
    }
    
    A_n = sqrt(S * S + C * C)
    latRad = copysign(1.0,z) * atan(S / (e_c * C))
    alt = (p * e_c * C + fabs(z) * S - WGS84_A * e_c * A_n) / sqrt(e_c * e_c * C * C + S * S)
    
    return (latitude: latRad.degrees, longitude: lonRad.degrees, altitude: alt)
}

fileprivate func calculateGeo(latitude: Double, longitude: Double, x: Double, y: Double) -> (latitude: Double, longitude: Double) {
    
//    let latRad = latitude.radians
//    let lonRad = longitude.radians
//    
//    let dy = y / WGS84_D
//    let dx = (x / WGS84_D) / cos(latRad)
//    
//    return (latitude: latitude + dy, longitude: longitude + dx)
    
    var result = calculateGeo(latitude: latitude, longitude: longitude, distance: x, bearing: 90)
    
    result = calculateGeo(latitude: result.latitude, longitude: result.longitude, distance: y, bearing: 0)
    
    return result
}

fileprivate func calculateGeo(latitude: Double, longitude: Double, distance: Double, bearing: Double) -> (latitude: Double, longitude: Double) {
    
    let lat1 = latitude.radians
    let lon1 = longitude.radians
    let bearingRad = bearing.radians
    
    let lat2 = asin(sin(lat1) * cos(distance / WGS84_A) + cos(lat1) * sin(distance / WGS84_A) * cos(bearingRad))
    
    let lon2 = lon1 + atan2(sin(bearingRad) * sin(distance / WGS84_A) * cos(lat1), cos(distance / WGS84_A) - sin(lat1) * sin(lat2))
    
    let newLatitude = lat2.degrees
    let newLongitude = lon2.degrees
    
    return (newLatitude, newLongitude)
}

struct CoordTransformRequest: Codable {
    let latitude: String
    let longitude: String
    let altitude: String
    let inputCRS: String
}

struct EPSGTransform: Decodable {
    let results: [TransformItem]

    enum CodingKeys: String, CodingKey {
        case results
    }
}

struct TransformItem: Decodable {
    let x: String
    let y: String
    let z: String
    
    var longitude: Double {
        Double(x) ?? 0
    }
    
    var latitude: Double {
        Double(y) ?? 0
    }
    
    var altitude: Double {
        Double(z) ?? 0
    }
}

struct PositionModel {
    
    var arPosition: (x: Double, y: Double, z: Double)
    
    var eulerAngles: EulerAnglesModel
    
    var gpsLocation: LocationModel
    
    var rtkLocation: LocationModel?
    
    var location: LocationModel {
        rtkLocation ?? gpsLocation
    }
    
    var isRTK: Bool {
        rtkLocation != nil
    }
    
    var intrinsics: simd_float3x3
    var transform: simd_float4x4
    
    static func calculate(latitude: Double, longitude: Double, altitude: Double, x: Double, y: Double, z: Double, horizontal: Double = 0.1, vertical: Double = 0.1) -> LocationModel {
        
        let geo = calculateGeo(latitude: latitude, longitude: longitude, x: x, y: -z)
        
        return LocationModel(latitude: geo.latitude.rounding(places: 10), longitude: geo.longitude.rounding(places: 10), altitude: altitude + y, horizontal: horizontal, vertical: vertical, heading: 0)
    }
    
    static func calculate(location: LocationModel, x: Double, y: Double, z: Double, horizontal: Double = 0.1, vertical: Double = 0.1) -> LocationModel {
        return calculate(latitude: location.latitude, longitude: location.longitude, altitude: location.altitude, x: x, y: y, z: z, horizontal: horizontal, vertical: vertical)
    }
    
    static func calculate(_ position: SIMD3<Double>, _ location1: LocationModel, _ location2: LocationModel) -> SIMD3<Double> {
        let x = calculateX(location1, location2)
        let y = calculateY(location1, location2)
        let z = calculateZ(location1, location2)
        return SIMD3<Double>(position.x + x, position.y + y, position.z + z)
    }
    
    static func calculateX(_ location1: LocationModel, _ location2: LocationModel) -> Double {
        let coordinate1 = CLLocation(latitude: location1.latitude, longitude: location1.longitude)
        let coordinate2 = CLLocation(latitude: location1.latitude, longitude: location2.longitude)
        let delta = coordinate1.highPrecisionDistance(from: coordinate2)
        return location1.longitude > location2.longitude ? -delta : delta
    }
    
    static func calculateZ(_ location1: LocationModel, _ location2: LocationModel) -> Double {
        let coordinate1 = CLLocation(latitude: location1.latitude, longitude: location1.longitude)
        let coordinate2 = CLLocation(latitude: location2.latitude, longitude: location1.longitude)
        let delta = coordinate1.highPrecisionDistance(from: coordinate2)
        return location1.latitude > location2.latitude ? delta : -delta
    }
    
    static func calculateY(_ location1: LocationModel, _ location2: LocationModel) -> Double {
        return location2.altitude - location1.altitude
    }
    
    static func transformLocations(
        _ inputCoord: String,
        _ location: LocationModel,
        _ projectId: String
    ) async throws -> TransformItem? {
        return try await withCheckedThrowingContinuation { continuation in
            let params = CoordTransformRequest(
                latitude: "\(location.latitude)",
                longitude: "\(location.longitude)",
                altitude: "\(location.altitude)",
                inputCRS: inputCoord
            )
            AF.request(
                URL(string: Constant.baseUrl + "api/v1/app/\(projectId)/convertCoordinateSystem")!,
                method: .post,
                parameters: params,
                encoder: JSONParameterEncoder.default
            )
            .responseDecodable(of: TransformItem.self) { response in
                debugPrint(response)
                switch response.result {
                case .success(let model):
                    continuation.resume(returning: model)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    static func transformPositions(_ inputCoord: String, _ outputCoord: String, _ positions: [(x: Double, y: Double)]) async throws -> [TransformItem] {
        var parameters: [String: Any] = [:]
        parameters["input_data"] = positions.map{ position in
            ["x": position.x, "y": position.y]
        }
        parameters["input_coord"] = inputCoord
        parameters["output_coord"] = outputCoord
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(URL(string: Constant.baseUrl + "api/v1/util/coordinate-convert")!,
                       method: .post,
                       parameters: parameters,
                       encoding: JSONEncoding.default)
            .responseDecodable(of: [TransformItem].self) { result in
                if let error = result.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result.value!)
                }
            }
        }
    }
}

class EulerAnglesModel: NSObject {
    var yaw: Double
    var roll: Double
    var pitch: Double
    
    init(yaw: Double, roll: Double, pitch: Double) {
        self.yaw = yaw
        self.roll = roll
        self.pitch = pitch
    }
    
    func setAngles(_ model: EulerAnglesModel) {
        self.yaw = model.yaw
        self.roll = model.roll
        self.pitch = model.pitch
    }
    
    static func get(eulerAngles: simd_float3) -> EulerAnglesModel {
        let x = -Double(eulerAngles.z)
        let y = Double(eulerAngles.x)
        let z = -Double(eulerAngles.y)
        return EulerAnglesModel(yaw: z.degrees, roll: x.degrees, pitch: y.degrees)
    }
    
    static func transform(eulerAngles: simd_float3) -> EulerAnglesModel {
        let x = -Double(eulerAngles.z)
        let y = Double(eulerAngles.x)
        let z = -Double(eulerAngles.y)

        let sinx = sin(x)
        let cosx = cos(x)
        let siny = sin(y)
        let cosy = cos(y)
        let sinz = sin(z)
        let cosz = cos(z)
        
        let rx = simd_double3x3(
            simd_double3(1.0,  0.0,  0.0),
            simd_double3(0.0, cosx, -sinx),
            simd_double3(0.0, sinx,  cosx)
        )

        let ry = simd_double3x3(
            simd_double3( cosy, 0.0, siny),
            simd_double3(  0.0, 1.0,  0.0),
            simd_double3(-siny, 0.0, cosy)
        )

        let rz = simd_double3x3(
            simd_double3(cosz, -sinz, 0.0),
            simd_double3(sinz,  cosz, 0.0),
            simd_double3( 0.0,   0.0, 1.0)
        )

        let rotationMatrix = rx * ry * rz
        
        let r1 = simd_double3x3(
            simd_double3(0.0, 0.0, -1.0),
            simd_double3(0.0, 1.0,  0.0),
            simd_double3(1.0, 0.0,  0.0)
        )
        
        let r2 = simd_double3x3(
            simd_double3(-1.0, 0.0,  0.0),
            simd_double3( 0.0, 1.0,  0.0),
            simd_double3( 0.0, 0.0, -1.0)
        )
        
        let combinedRotationMatrix = r1 * r2 * rotationMatrix
        
        let r11 = combinedRotationMatrix.columns.0.x
        let r12 = combinedRotationMatrix.columns.0.y
        let r13 = combinedRotationMatrix.columns.0.z
        let r21 = combinedRotationMatrix.columns.1.x
        let r22 = combinedRotationMatrix.columns.1.y
        let r23 = combinedRotationMatrix.columns.1.z
        let r31 = combinedRotationMatrix.columns.2.x
        let r32 = combinedRotationMatrix.columns.2.y
        let r33 = combinedRotationMatrix.columns.2.z
        
        let combinedPitch = asin(-r31)
        var combinedYaw: Double
        var combinedRoll: Double
        if abs(r31) < 1.0 {
            combinedYaw = atan2(r21, r11)
            combinedRoll = atan2(r32, r33)
        } else {
            combinedYaw = atan2(-r12, r22)
            combinedRoll = 0.0
        }
        return EulerAnglesModel(yaw: combinedYaw.degrees, roll: combinedRoll.degrees, pitch: combinedPitch.degrees)
    }
}

extension LocationModel {
    var raw: [String: Double] {
        return [
            "latitude": latitude,
            "longitude": longitude,
            "altitude": altitude,
            "horizontal": horizontal,
            "vertical": vertical
        ]
    }
}
