//
//  PositionHistory.swift
//  Quick3D
//
//  Created by HungNT on 11/12/25.
//

import Foundation

class PositionHistory {
    
    let coord: SIMD3<Double>
    let location: LocationModel
    let projectId: String
    let frameTimestamp: Date
    
    var offset: SIMD3<Double>? = nil
    
    private var convertTask: Task<(), Never>? = nil
    
    init(coord: SIMD3<Double>, location: LocationModel, projectId: String, frameTimestamp:Date = Date()) {
        self.coord = coord
        self.location = location
        self.projectId = projectId
        self.frameTimestamp = frameTimestamp
        self.convertTask = Task {
            self.offset = try? await calculateOffset()
        }
    }
    
    init(coord: SIMD3<Double>, location: LocationModel, offset: SIMD3<Double>, frameTimestamp:Date = Date()) {
        self.coord = coord
        self.location = location
        self.offset = offset
        self.projectId = ""
        self.frameTimestamp = frameTimestamp
    }
    
    func calculateOffset() async throws -> SIMD3<Double>? {
        if let convertedPosition = try? await PositionModel.transformLocations(self.location.coordinate, location, projectId) {
            return [
                Double(convertedPosition.longitude),
                Double(convertedPosition.altitude),
                Double(-convertedPosition.latitude)
            ]
        }
        return nil
    }
    
    func cancel() {
        convertTask?.cancel()
        convertTask = nil
    }
    
    func coordinates(_ position: PositionHistory) -> PositionHistory {
        let delta = position.offset! - self.offset!
        let coord = self.coord + delta
        return PositionHistory(coord: coord, location: position.location, offset: position.offset!, frameTimestamp: position.frameTimestamp)
    }
    
    func distance(_ coord: SIMD3<Double>) -> Double {
        let dx = self.coord.x - coord.x
        let dz = self.coord.z - coord.z
        return sqrt(dx*dx + dz*dz)
    }
}
