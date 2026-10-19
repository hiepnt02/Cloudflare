//
//  OverlapCalculator.swift
//  Quick3D
//
//  Created by Admin on 13/10/25.
//

import Foundation
import ARKit

protocol OverlapCalculator {
    
    var lastFrame: FrameMetadata? { get set }
    
    func calculateFromFov(
        _ frame: FrameCalculationData,
        _ scanRatio: Float,
        _ maxSmoothingFrames: Int
    ) -> (Float, Float)
    
    func resetDistances()
}
