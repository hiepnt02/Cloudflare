//
//  ICP.swift
//  Swift ICP
//
//  Created by Sam Brooks on 05/12/2017.
//  Copyright © 2017 Sam Brooks. All rights reserved.
//

import KDTree
import Accelerate
import GLKit
import simd

// MARK: - Shared Math Utilities
enum Math2D {
    static func centroid(_ pointCloud: [simd_double2]) -> simd_double2 {
        guard !pointCloud.isEmpty else { return .zero }
        let vectorSum = pointCloud.reduce(.zero, +)
        return vectorSum / Double(pointCloud.count)
    }
    
    static func covarianceMatrix(A: [simd_double2], B: [simd_double2], centroidA: simd_double2, centroidB: simd_double2) -> [Double] {
        // 2D Covariance matrix requires only 4 elements (2x2)
        var H: [Double] = [0.0, 0.0, 0.0, 0.0]
        
        for i in 0..<A.count {
            let AX = A[i].x - centroidA.x
            let AY = A[i].y - centroidA.y
            let BX = B[i].x - centroidB.x
            let BY = B[i].y - centroidB.y
            
            H[0] += AX * BX
            H[1] += AX * BY
            H[2] += AY * BX
            H[3] += AY * BY
        }
        return H
    }
    
    // Copied directly from https://gist.github.com/wannyk/04c1f48161780322c0bb
    static func svd(_ x: [Double], m: Int, n: Int) -> (u: [Double], s: [Double], v: [Double]) {
        var JOBZ = Int8(UnicodeScalar("A").value)
        var M = __CLPK_integer(m)
        var N = __CLPK_integer(n)
        var A = x
        var LDA = __CLPK_integer(m)
        var S = [__CLPK_doublereal](repeating: 0.0, count: min(m, n))
        var U = [__CLPK_doublereal](repeating: 0.0, count: m * m)
        var LDU = __CLPK_integer(m)
        var VT = [__CLPK_doublereal](repeating: 0.0, count: n * n)
        var LDVT = __CLPK_integer(n)
        let lwork = min(m, n) * (6 + 4 * min(m, n)) + max(m, n)
        var WORK = [__CLPK_doublereal](repeating: 0.0, count: lwork)
        var LWORK = __CLPK_integer(lwork)
        var IWORK = [__CLPK_integer](repeating: 0, count: 8 * min(m, n))
        var INFO = __CLPK_integer(0)
        
        dgesdd_(&JOBZ, &M, &N, &A, &LDA, &S, &U, &LDU, &VT, &LDVT, &WORK, &LWORK, &IWORK, &INFO)
        
        var s = [Double](repeating: 0.0, count: m * n)
        for ni in 0..<n {
            s[ni * m + ni] = S[ni]
        }
        
        var v = [Double](repeating: 0.0, count: n * n)
        vDSP_mtransD(VT, 1, &v, 1, vDSP_Length(n), vDSP_Length(n))
        return (U, s, v)
    }
}

// MARK: - KDTree Extension
extension simd_double2: @retroactive KDTreePoint {
    public static var dimensions: Int { return 2 }
    
    public func kdDimension(_ dimension: Int) -> Double {
        return dimension == 0 ? self.x : self.y
    }
    
    public func squaredDistance(to otherPoint: simd_double2) -> Double {
        return simd_distance_squared(self, otherPoint)
    }
}

// MARK: - ICP2D
class ICP2D {
    var tree: KDTree<simd_double2>
    var points: [simd_double2]
    var points2: [simd_double2]
    var totalTransform = matrix_identity_double3x3
    
    init(_ basePointCloud: [simd_double2], _ secondPointCloud: [simd_double2]) {
        self.tree = KDTree(values: basePointCloud)
        self.points = basePointCloud
        self.points2 = secondPointCloud
    }
    
    func iterate(maxIterations: Int, minErrorChange: Double) -> simd_double3x3 {
        var lastTransform = matrix_identity_double3x3
        var lastError: Double = .greatestFiniteMagnitude
        var (trimmedPoints2, trimmedPoints, error) = closestPoints(pointSet2: points2)
        
        for _ in 0..<maxIterations {
            points2 = icpStep(pointSet1: trimmedPoints, pointSet2: trimmedPoints2, fullPointSet2: points2)
            (trimmedPoints2, trimmedPoints, error) = closestPoints(pointSet2: points2)
            
            if (lastError - error) < minErrorChange {
                totalTransform = lastTransform
                break
            }
            lastTransform = totalTransform
            lastError = error
        }
        return totalTransform
    }
    
    func closestPoints(pointSet2: [simd_double2]) -> (trimmedSet2: [simd_double2], pairedPoints: [simd_double2], error: Double) {
        var pairedPoints = [simd_double2]()
        var trimmedSet2 = [simd_double2]()
        var totalError = 0.0
        
        for point in pointSet2 {
            // Safely unwrap closest point to prevent crashes
            guard let closest = tree.nearest(to: point) else { continue }
            
            let distance = simd_distance(closest, point)
            totalError += distance
            pairedPoints.append(closest)
            trimmedSet2.append(point)
        }
        
        let error = trimmedSet2.isEmpty ? 0.0 : totalError / Double(trimmedSet2.count)
        return (trimmedSet2, pairedPoints, error)
    }
    
    func icpStep(pointSet1: [simd_double2], pointSet2: [simd_double2], fullPointSet2: [simd_double2]) -> [simd_double2] {
        let (R, T) = getRTMatrixSVD(A: pointSet2, B: pointSet1)
        
        let guessedTransformMatrix = simd_double3x3(
            simd_double3(R.columns.0, 0),
            simd_double3(R.columns.1, 0),
            simd_double3(T, 1) // Corrected from 0 to 1 for valid affine transform
        )
        
        totalTransform = guessedTransformMatrix * totalTransform

        return fullPointSet2.map { point in
            let newVector = guessedTransformMatrix * simd_double3(point, 1)
            return simd_double2(newVector.x, newVector.y)
        }
    }
    
    func getRTMatrixSVD(A: [simd_double2], B: [simd_double2]) -> (R: simd_double2x2, T: simd_double2) {
        assert(A.count == B.count, "Point clouds to transform are not the same length")
        
        let centroidA = Math2D.centroid(A)
        let centroidB = Math2D.centroid(B)
        let H = Math2D.covarianceMatrix(A: A, B: B, centroidA: centroidA, centroidB: centroidB)
        
        let (v, _, u) = Math2D.svd(H, m: 2, n: 2)
        
        let V = simd_double2x2(simd_double2(v[0], v[1]), simd_double2(v[2], v[3]))
        let U = simd_double2x2(simd_double2(u[0], u[1]), simd_double2(u[2], u[3]))
        
        let R = V * simd_transpose(U)
        let T = -R * centroidA + centroidB
        
        return (R, T)
    }
}

// MARK: - SVD2D
class SVD2D {
    var pointBase: [simd_double2]
    var pointSecond: [simd_double2]
    var withScale: Bool
    var scale: Double?
    
    init(_ basePointCloud: [simd_double2], _ secondPointCloud: [simd_double2], _ withScale: Bool = false, _ scale: Double? = nil) {
        self.pointBase = basePointCloud
        self.pointSecond = secondPointCloud
        self.withScale = withScale
        self.scale = scale
    }
    
    func getScale(A: [simd_double2], B: [simd_double2]) -> Double {
        guard !A.isEmpty, !B.isEmpty else { return 1.0 }
        
        let maxScale = 2.0
        let minScale = 0.5
        
        let centroidA = Math2D.centroid(A)
        let centroidB = Math2D.centroid(B)
        
        let pointDistanceA = A.reduce(0.0) { $0 + simd_distance($1, centroidA) }
        let pointDistanceB = B.reduce(0.0) { $0 + simd_distance($1, centroidB) }
        
        guard pointDistanceA > 0 else { return 1.0 }
        
        let calculatedScale = pointDistanceB / pointDistanceA
        return (maxScale < calculatedScale || calculatedScale < minScale) ? 1.0 : calculatedScale
    }
    
    func getRTMatrix3x3SVD() -> simd_double3x3 {
        let (R, T) = getRTMatrixSVD(A: pointSecond, B: pointBase)
        return simd_double3x3(
            simd_double3(R.columns.0, 0),
            simd_double3(R.columns.1, 0),
            simd_double3(T, 1)
        )
    }
    
    func getRTMatrix4x4SVD() -> simd_double4x4 {
        let (R, T) = getRTMatrixSVD(A: pointSecond, B: pointBase)
        return simd_double4x4(
            simd_double4(R.columns.0.x, 0.0, R.columns.0.y, 0.0),
            simd_double4(0.0, 1.0, 0.0, 0.0),
            simd_double4(R.columns.1.x, 0.0, R.columns.1.y, 0.0),
            simd_double4(T.x, 0.0, T.y, 1.0)
        )
    }
    
    func getRTMatrixSVD(A: [simd_double2], B: [simd_double2]) -> (R: simd_double2x2, T: simd_double2) {
        assert(A.count == B.count, "Point clouds to transform are not the same length")
        
        var centroidA = Math2D.centroid(A)
        let centroidB = Math2D.centroid(B)
        
        let currentScale = self.scale ?? getScale(A: A, B: B)
        
        let H = Math2D.covarianceMatrix(A: A, B: B, centroidA: centroidA, centroidB: centroidB)
        
        let (v, _, u) = Math2D.svd(H, m: 2, n: 2)
        
        let V = simd_double2x2(simd_double2(v[0], v[1]), simd_double2(v[2], v[3]))
        let U = simd_double2x2(simd_double2(u[0], u[1]), simd_double2(u[2], u[3]))
        
        var R = V * simd_transpose(U)
        if withScale {
            R = currentScale * R
        }
        let T = -R * centroidA + centroidB
        
        return (R, T)
    }
}
