//
//  Transformation.swift
//  Test4
//
//  Created by HaNST on 18/6/25.
//

import Foundation
import simd

struct Transformation {
    
    let matrix: simd_double4x4
    let rotation: simd_double3x3
    let translation: simd_double3
    let eulerAngles: EulerAngles
    let order: EulerAnglesOrder
    
    public init(_ matrix: simd_float4x4, order: EulerAnglesOrder = .xyz) {
        let t = simd_double4x4 (
            [Double(matrix.columns.0.x), Double(matrix.columns.0.y), Double(matrix.columns.0.z), Double(matrix.columns.0.w)],
            [Double(matrix.columns.1.x), Double(matrix.columns.1.y), Double(matrix.columns.1.z), Double(matrix.columns.1.w)],
            [Double(matrix.columns.2.x), Double(matrix.columns.2.y), Double(matrix.columns.2.z), Double(matrix.columns.2.w)],
            [Double(matrix.columns.3.x), Double(matrix.columns.3.y), Double(matrix.columns.3.z), Double(matrix.columns.3.w)]
        )
        self.init(t, order: order)
    }
    
    public init(_ matrix: simd_double4x4, order: EulerAnglesOrder = .xyz) {
        self.matrix = matrix
        
        self.rotation = simd_double3x3(
            [self.matrix.columns.0.x, self.matrix.columns.0.y, self.matrix.columns.0.z],
            [self.matrix.columns.1.x, self.matrix.columns.1.y, self.matrix.columns.1.z],
            [self.matrix.columns.2.x, self.matrix.columns.2.y, self.matrix.columns.2.z]
        )
        
        self.translation = simd_double3(self.matrix.columns.3.x, self.matrix.columns.3.y, self.matrix.columns.3.z)
        
        self.order = order
        
        self.eulerAngles = EulerAngles(self.rotation, order: order)
    }
    
    public init(_ matrix: simd_float4x4, _ eulerAngles: simd_float3) {
        self.matrix = simd_double4x4 (
            [Double(matrix.columns.0.x), Double(matrix.columns.0.y), Double(matrix.columns.0.z), Double(matrix.columns.0.w)],
            [Double(matrix.columns.1.x), Double(matrix.columns.1.y), Double(matrix.columns.1.z), Double(matrix.columns.1.w)],
            [Double(matrix.columns.2.x), Double(matrix.columns.2.y), Double(matrix.columns.2.z), Double(matrix.columns.2.w)],
            [Double(matrix.columns.3.x), Double(matrix.columns.3.y), Double(matrix.columns.3.z), Double(matrix.columns.3.w)]
        )
        
        self.rotation = simd_double3x3(
            [self.matrix.columns.0.x, self.matrix.columns.0.y, self.matrix.columns.0.z],
            [self.matrix.columns.1.x, self.matrix.columns.1.y, self.matrix.columns.1.z],
            [self.matrix.columns.2.x, self.matrix.columns.2.y, self.matrix.columns.2.z]
        )
        
        self.translation = simd_double3(self.matrix.columns.3.x, self.matrix.columns.3.y, self.matrix.columns.3.z)
        
        self.order = .yzx
        
        self.eulerAngles = EulerAngles(eulerAngles)
    }
    
    public init(_ eulerAngles: EulerAngles, order: EulerAnglesOrder = .xyz) {
        self.rotation = eulerAngles.getRotationMatrix(order: order)
        
        self.matrix = simd_double4x4(
            simd_double4(self.rotation.columns.0, 0),
            simd_double4(self.rotation.columns.1, 0),
            simd_double4(self.rotation.columns.2, 0),
            simd_double4(0, 0, 0, 1))

        self.translation = simd_double3(0, 0, 0)
        
        self.order = .yzx
        
        self.eulerAngles = eulerAngles
    }
}

extension Transformation {
    static func * (lhs: Transformation, rhs: Transformation) -> Transformation {
        let matrix = lhs.matrix * rhs.matrix
        return Transformation(matrix, order: lhs.order)
    }
}
