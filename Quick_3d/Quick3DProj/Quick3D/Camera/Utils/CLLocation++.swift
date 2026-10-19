//
//  CLLocation++.swift
//  Quick3D
//
//  Created by HungNT on 4/2/26.
//

import Foundation
import CoreLocation

extension CLLocation {
    // Tính khoảng cách giữa hai tọa độ bằng công thức Vincenty (WGS-84)
    // Trả về khoảng cách tính bằng mét với độ chính xác cực cao.
    func highPrecisionDistance(from location: CLLocation) -> Double {
        let a = 6378137.0 // Bán trục lớn (WGS-84)
        let b = 6356752.314245 // Bán trục nhỏ
        let f = 1 / 298.257223563 // Độ dẹt
        
        let L = (location.coordinate.longitude - self.coordinate.longitude).radians
        let U1 = atan((1 - f) * tan(self.coordinate.latitude.radians))
        let U2 = atan((1 - f) * tan(location.coordinate.latitude.radians))
        
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
            if sinSigma == 0 { return 0 } // Hai điểm trùng nhau
            
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
        
        if iterLimit == 0 { return Double.nan } // Không hội tụ
        
        let uSq = cosSqAlpha * (a * a - b * b) / (b * b)
        let A = 1 + uSq / 16384 * (4096 + uSq * (-768 + uSq * (320 - 175 * uSq)))
        let B = uSq / 1024 * (256 + uSq * (-128 + uSq * (74 - 47 * uSq)))
        let deltaSigma = B * sinSigma * (cos2SigmaM + B / 4 * (cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM) - B / 6 * cos2SigmaM * (-3 + 4 * sinSigma * sinSigma) * (-3 + 4 * cos2SigmaM * cos2SigmaM)))
        
        let distance = b * A * (sigma - deltaSigma)
        return distance
    }
}
