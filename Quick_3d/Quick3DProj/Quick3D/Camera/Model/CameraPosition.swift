//
//  Point.swift
//  Test4
//
//  Created by HaNST on 19/6/25.
//

import Foundation
import simd
import CoreLocation

fileprivate let EARTH = 6378137.0

struct CameraPosition {
    
    let coord: SIMD3<Double>
    let location: LocationModel
    let isRTK: Bool
    
    init(coord: SIMD3<Double>, location: LocationModel, isRTK: Bool = false) {
        self.coord = coord
        self.location = location
        self.isRTK = isRTK
    }
    
    static func calculate(location: LocationModel, distance: Double, bearing: Double) -> LocationModel {
        
        let lat1 = location.latitude.radians
        let lon1 = location.longitude.radians
        let bearingRad = bearing.radians
        
        let lat2 = asin(sin(lat1) * cos(distance / EARTH) + cos(lat1) * sin(distance / EARTH) * cos(bearingRad))
        
        let lon2 = lon1 + atan2(sin(bearingRad) * sin(distance / EARTH) * cos(lat1), cos(distance / EARTH) - sin(lat1) * sin(lat2))
        
        let newLatitude = lat2.degrees
        let newLongitude = lon2.degrees
        
        return LocationModel(latitude: newLatitude, longitude: newLongitude, altitude: location.altitude, horizontal: location.horizontal, vertical: location.vertical, heading: 0)
    }
    
    static func calculate(location: LocationModel, coord: SIMD3<Double>) -> LocationModel {
        
        var geo = calculate(location: location, distance: coord.x, bearing: 90)
        
        geo = calculate(location: geo, distance: -coord.z, bearing: 0)
        
        return LocationModel(
            latitude: geo.latitude.rounding(places: 10),
            longitude: geo.longitude.rounding(places: 10),
            altitude: location.altitude + coord.y,
            horizontal: location.horizontal,
            vertical: location.vertical,
            heading: 0)
    }
    
    static func distance(location1: CLLocation, location2: CLLocation) -> Double {
        
        let lat1 = location1.coordinate.latitude
        let lon1 = location1.coordinate.longitude
        let lat2 = location2.coordinate.latitude
        let lon2 = location2.coordinate.longitude
        
        let dLat = (lat2 - lat1).radians
        let dLon = (lon2 - lon1).radians
        
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1.radians) * cos(lat2.radians) * sin(dLon / 2) * sin(dLon / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        let distance = EARTH * c
        return distance
    }

    static func calculateX(_ location1: LocationModel, _ location2: LocationModel) -> Double {
        let coordinate1 = CLLocation(latitude: location1.latitude, longitude: location1.longitude)
        let coordinate2 = CLLocation(latitude: location1.latitude, longitude: location2.longitude)
        let delta = CameraPosition.distance(location1: coordinate1, location2: coordinate2)
        return location1.longitude > location2.longitude ? -delta : delta
    }
    
    static func calculateZ(_ location1: LocationModel, _ location2: LocationModel) -> Double {
        let coordinate1 = CLLocation(latitude: location1.latitude, longitude: location1.longitude)
        let coordinate2 = CLLocation(latitude: location2.latitude, longitude: location1.longitude)
        let delta = CameraPosition.distance(location1: coordinate1, location2: coordinate2)
        return location1.latitude > location2.latitude ? delta : -delta
    }
    
    static func calculateY(_ location1: LocationModel, _ location2: LocationModel) -> Double {
        return location2.altitude - location1.altitude
    }
    
    static func calculate(_ coord: SIMD3<Double>, _ location1: LocationModel, _ location2: LocationModel) -> SIMD3<Double> {
        let x = CameraPosition.calculateX(location1, location2)
        let y = CameraPosition.calculateY(location1, location2)
        let z = CameraPosition.calculateZ(location1, location2)
        return SIMD3<Double>(coord.x + x, coord.y + y, coord.z + z)
    }
    
    func root() -> CameraPosition {
        let location = CameraPosition.calculate(location: self.location, coord: -self.coord)
        return CameraPosition(coord: [0, 0, 0], location: location, isRTK: self.isRTK)
    }
    
    func location(_ coord: SIMD3<Double>) -> CameraPosition {
        let location = CameraPosition.calculate(location: self.location, coord: coord)
        return CameraPosition(coord: coord, location: location, isRTK: self.isRTK)
    }
    
    func coordinates(_ location: LocationModel) -> CameraPosition {
        let coord = CameraPosition.calculate(self.coord, self.location, location)
        return CameraPosition(coord: coord, location: location, isRTK: self.isRTK)
    }
}
