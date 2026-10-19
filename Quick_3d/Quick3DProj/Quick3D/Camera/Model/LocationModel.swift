//
//  QLocation.swift
//  Quick3D
//
//  Created by HaNST on 13/10/25.
//

import Foundation
import CoreLocation
import VigramSDK

struct LocationModel: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontal: Double
    let vertical: Double
    let course: Double
    let courseAccuracy: Double
    let coordinate: String
    let isRTK: Bool
    let timestamp: Date
    
    var simdCoordinate: SIMD3<Double> {
        [longitude, altitude, latitude]
    }
    
    var simdAccuracy: SIMD2<Double> {
        [horizontal, vertical]
    }
    
    init() {
        self.latitude = 0
        self.longitude = 0
        self.altitude = 0
        self.horizontal = 0
        self.vertical = 0
        self.course = 0
        self.courseAccuracy = 0
        self.coordinate = defaultCoordinate
        self.isRTK = false
        self.timestamp = Date()
    }
    
    init(_ location: CLLocation, coordinate: String = defaultCoordinate, isRTK: Bool = false) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.ellipsoidalAltitude
        self.horizontal = location.horizontalAccuracy
        self.vertical = location.verticalAccuracy
        self.course = location.course
        self.courseAccuracy = location.courseAccuracy
        self.coordinate = coordinate
        self.isRTK = isRTK
        self.timestamp = location.timestamp
    }
    
    init(_ data: EnvironmentData, coordinate: String = defaultCoordinate) {
        self.latitude = data.correctedCoordinate.latitude
        self.longitude = data.correctedCoordinate.longitude
        self.altitude = data.correctedCoordinate.altitude
        self.horizontal = data.horizontalAccuracy
        self.vertical = data.verticalAccuracy
        self.course = 0
        self.courseAccuracy = 0
        self.coordinate = coordinate
        self.isRTK = true
        self.timestamp = data.date
    }
    
    init(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        horizontal: Double,
        vertical: Double,
        heading: Double,
        coordinate: String,
        isRTK: Bool = false,
        timestamp:Date = Date()
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontal = horizontal
        self.vertical = vertical
        self.course = heading
        self.courseAccuracy = 0
        self.coordinate = coordinate
        self.isRTK = isRTK
        self.timestamp = timestamp
    }
    
    init(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        horizontal: Double,
        vertical: Double,
        heading: Double
    ) {
        self.init(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            horizontal: horizontal,
            vertical: vertical,
            heading: heading,
            coordinate: defaultCoordinate
        )
    }
    
    init(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        horizontal: Double,
        vertical: Double
    ) {
        self.init(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            horizontal: horizontal,
            vertical: vertical,
            heading: 0
        )
    }
    
    init(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        horizontal: Double,
        vertical: Double,
        coordinate: String
    ) {
        self.init(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            horizontal: horizontal,
            vertical: vertical,
            heading: 0,
            coordinate: coordinate
        )
    }
    
    init(
        latitude: Double,
        longitude: Double,
        altitude: Double
    ) {
        self.init(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            horizontal: 0.01,
            vertical: 0.01,
            heading: 0
        )
    }
}

extension LocationModel {
    // Bán trục nhỏ
    var EARTH_RADIUS_MINOR: Double { 6356752.314245 }
    // Bán trục lớn (WGS-84)
    var EARTH_RADIUS_MAJOR: Double { 6378137.0 }
    // Độ dẹt
    var EARTH_FLATTENING: Double { 1 / 298.257223563 }
    
    func vincentyDistance(from location: LocationModel) -> SIMD3<Float> {
        
        let a = EARTH_RADIUS_MAJOR
        let b = EARTH_RADIUS_MINOR
        let f = EARTH_FLATTENING
        
        let lat1 = self.latitude
        let lon1 = self.longitude
        
        let lat2 = location.latitude
        let lon2 = location.longitude
        
        let L = (lon2 - lon1).radians
        let U1 = atan((1 - f) * tan(lat1.radians))
        let U2 = atan((1 - f) * tan(lat2.radians))
        
        let sinU1 = sin(U1), cosU1 = cos(U1)
        let sinU2 = sin(U2), cosU2 = cos(U2)
        
        var lambda = L
        var lambdaP: Double
        var iterLimit = 100
        
        var sinLambda: Double = 0, cosLambda: Double = 0
        var sinSigma: Double = 0, cosSigma: Double = 0
        var sigma: Double = 0, sinAlpha: Double = 0
        var cosSqAlpha: Double = 0, cos2SigmaM: Double = 0
        var C: Double = 0
        
        // Vòng lặp hội tụ
        repeat {
            sinLambda = sin(lambda)
            cosLambda = cos(lambda)
            
            sinSigma = sqrt(pow(cosU2 * sinLambda, 2) + pow(cosU1 * sinU2 - sinU1 * cosU2 * cosLambda, 2))
            if sinSigma == 0 { return .zero } // Hai điểm trùng nhau
            
            cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosLambda
            sigma = atan2(sinSigma, cosSigma)
            sinAlpha = cosU1 * cosU2 * sinLambda / sinSigma
            cosSqAlpha = 1 - sinAlpha * sinAlpha
            
            // Trường hợp điểm nằm trên đường xích đạo
            cos2SigmaM = (cosSqAlpha == 0) ? 0 : (cosSigma - 2 * sinU1 * sinU2 / cosSqAlpha)
            
            C = f / 16 * cosSqAlpha * (4 + f * (4 - 3 * cosSqAlpha))
            lambdaP = lambda
            lambda = L + (1 - C) * f * sinAlpha * (sigma + C * sinSigma * (cos2SigmaM + C * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)))
            
            iterLimit -= 1
        } while (abs(lambda - lambdaP) > 1e-12 && iterLimit > 0)
        
        if iterLimit == 0 { return [.nan, .nan, .nan] } // Không hội tụ
        
        let uSq = cosSqAlpha * (a * a - b * b) / (b * b)
        let A = 1 + uSq / 16384 * (4096 + uSq * (-768 + uSq * (320 - 175 * uSq)))
        let B = uSq / 1024 * (256 + uSq * (-128 + uSq * (74 - 47 * uSq)))
        let deltaSigma = B * sinSigma * (cos2SigmaM + B / 4 * (cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM) - B / 6 * cos2SigmaM * (-3 + 4 * sinSigma * sinSigma) * (-3 + 4 * cos2SigmaM * cos2SigmaM)))
        
        let distance = b * A * (sigma - deltaSigma)
        
        // Initial bearing
        let bearing = atan2(
            cosU2*sinLambda,
            cosU1*sinU2 - sinU1*cosU2*cosLambda
        )
        
        let x = distance * sin(bearing)
        let z = distance * cos(bearing)
        let y = self.altitude - location.altitude
        
        return [Float(x.rounding(places: 6)), Float(y), Float(z.rounding(places: 6))]
    }
    
    func vincentyLocation(_ value: SIMD3<Float>) -> LocationModel {
        
        let a = EARTH_RADIUS_MAJOR
        let b = EARTH_RADIUS_MINOR
        let f = EARTH_FLATTENING
        
        let x = Double(value.x)
        let y = Double(value.z)
        
        let distance = hypot(x, y)
        let bearing = atan2(x, y)
        
        let lat1 = self.latitude
        let lon1 = self.longitude
        
        let sinBearing = sin(bearing)
        let cosBearing = cos(bearing)
        
        let tanReducedLat1 = (1 - f) * tan(lat1)
        let cosReducedLat1 = 1 / sqrt(1 + tanReducedLat1 * tanReducedLat1)
        let sinReducedLat1 = tanReducedLat1 * cosReducedLat1
        
        let sigma1 = atan2(tanReducedLat1, cosBearing)
        
        let sinAlpha = cosReducedLat1 * sinBearing
        let cosSqAlpha = 1 - sinAlpha * sinAlpha
        
        let uSquared = cosSqAlpha * (a * a - b * b) / (b * b)
        
        let A = 1 + uSquared / 16384 * (4096 + uSquared * (-768 + uSquared * (320 - 175 * uSquared)))
        let B = uSquared / 1024 * (256 + uSquared * (-128 + uSquared * (74 - 47 * uSquared)))
        
        var sigma = distance / (b * A)
        var sigmaPrev = 0.0
        
        var sinSigma = 0.0
        var cosSigma = 0.0
        var cos2SigmaM = 0.0
        
        repeat {
            cos2SigmaM = cos(2 * sigma1 + sigma)
            sinSigma = sin(sigma)
            cosSigma = cos(sigma)
            
            let deltaSigma = B * sinSigma * (cos2SigmaM + B / 4 * (cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM) - B / 6 * cos2SigmaM * (-3 + 4 * sinSigma * sinSigma) * (-3 + 4 * cos2SigmaM * cos2SigmaM)))
            
            sigmaPrev = sigma
            sigma = distance / (b * A) + deltaSigma
            
        } while abs(sigma - sigmaPrev) > 1e-12
        
        let temp = sinReducedLat1 * sinSigma - cosReducedLat1 * cosSigma * cosBearing
        
        let lat2 = atan2(sinReducedLat1 * cosSigma + cosReducedLat1 * sinSigma * cosBearing, (1 - f) * sqrt(sinAlpha * sinAlpha + temp * temp))
        
        let lambda = atan2(sinSigma * sinBearing, cosReducedLat1 * cosSigma - sinReducedLat1 * sinSigma * cosBearing)
        
        let C = f / 16 * cosSqAlpha * (4 + f * (4 - 3 * cosSqAlpha))
        
        let L = lambda - (1 - C) * f * sinAlpha * (sigma + C * sinSigma * (cos2SigmaM + C * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)))
        
        let lon2 = lon1 + L
        
        return LocationModel(latitude: lat2.degrees,
                             longitude: lon2.degrees,
                             altitude: self.altitude + Double(value.y),
                             horizontal: self.horizontal,
                             vertical: self.vertical)
    }
}
