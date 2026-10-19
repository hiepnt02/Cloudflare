//
//  RTKZAccuracy.swift
//  Quick3D
//
//  Created by Admin on 22/10/25.
//

import Foundation
import UIKit

enum RTKZAccuracyEnum {
    case high, medium, low
    
    func color() -> UIColor {
        switch self {
        case .high:
            return .green
        case .medium:
            return .yellow
        case .low:
            return .red
        }
    }
    
    func rgb() -> SIMD3<Float> {
        switch self {
        case .high:
            return [0, 1, 0]
        case .medium:
            return [1, 1, 0]
        case .low:
            return [1, 0, 0]
        }
    }
    
    static func from(value: Double) -> RTKZAccuracyEnum {
        if value <= 0.0148 {
            return .high
        } else if value <= 0.0198 {
            return .medium
        } else {
            return .low
        }
    }
    
    static func from(string: String) -> RTKZAccuracyEnum? {
        guard let value = Double(string) else {
            return nil
        }
        return from(value: value)
    }
}
