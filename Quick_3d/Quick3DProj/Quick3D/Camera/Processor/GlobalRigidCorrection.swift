//
//  GlobalRigidCorrection.swift
//  Quick3D
//
//

import Foundation
import simd

enum GlobalRigidCorrection {

    struct Result {
        /// Rigid transform: applying this to an AR-world point/pose yields its RTK-datum-aligned counterpart.
        let transform: simd_float4x4
        /// Rotation about +Y embedded in `transform`, radians. Zero when `isTranslationOnly`.
        let yaw: Double
        /// (x, verticalOffset, z) embedded in `transform`'s translation column.
        let translation: simd_double3
        /// RMS of the horizontal (x, z) fit residual, meters.
        let rms: Double
        /// Number of frames that passed the accuracy gate and were used for the fit.
        let fitPointCount: Int
        /// True when the fix points were too degenerate (e.g. collinear) to determine rotation reliably.
        let isTranslationOnly: Bool
    }

    /// AC-4 / Q-2: fewer fix points than this → not enough data to trust any fit → nil.
    static let minimumFitPointCount = 10

    static let rmsThreshold: Double = 0.5

    /// T-R4: starting constant — ratio of the covariance matrix's smaller to larger singular
    /// value below this means the fix points are too close to collinear to fix a rotation from
    /// (e.g. a straight flight/walk line), so we fall back to translation-only.
    static let degenerateSingularValueRatio: Double = 0.05

    /// - Parameters:
    ///   - frames: full frame set for the session; internally filtered to those meeting the RTK
    ///     accuracy gate (`ImageCalculator.checkCriteriaAccuracy`, ≤1.5cm) — the same predicate
    ///     `CaptureSession.isEligibleForGlobalCorrection` uses to decide whether to defer at all.
    ///   - root: local-frame origin shared with the rest of the geo-fusion pipeline.
    static func compute(frames: [FrameMetadata], root: LocationModel) -> Result? {
        let fitFrames = frames.filter { ImageCalculator.checkCriteriaAccuracy($0.location) }
        guard fitFrames.count >= minimumFitPointCount else { return nil }

        let arPoints = fitFrames.map { simd_double2(Double($0.position.x), Double($0.position.z)) }
        let rtkXyz = fitFrames.map { WGSLocalConverter.llaToXyz(location: $0.location, originLocation: root) }
        let rtkPoints = rtkXyz.map { simd_double2($0.x, $0.z) }

        let verticalOffset = zip(rtkXyz, fitFrames)
            .map { $0.0.y - Double($0.1.position.y) }
            .reduce(0, +) / Double(fitFrames.count)

        let centroidAR = Math2D.centroid(arPoints)
        let centroidRTK = Math2D.centroid(rtkPoints)
        let covariance = Math2D.covarianceMatrix(A: arPoints, B: rtkPoints, centroidA: centroidAR, centroidB: centroidRTK)
        let (_, singularValues, _) = Math2D.svd(covariance, m: 2, n: 2)
        let largestSingularValue = singularValues[0]
        let smallestSingularValue = singularValues[3]
        let isDegenerate = largestSingularValue <= .ulpOfOne
            || (smallestSingularValue / largestSingularValue) < degenerateSingularValueRatio

        var transform: simd_double4x4
        if isDegenerate {
            // Rotation is unreliable from near-collinear fix points — keep it identity and only
            // align centroids (BR-1 still holds: cloud and camera get the exact same T).
            transform = matrix_identity_double4x4
            transform.columns.3 = simd_double4(centroidRTK.x - centroidAR.x, 0, centroidRTK.y - centroidAR.y, 1)
        } else {
            transform = SVD2D(rtkPoints, arPoints, false).getRTMatrix4x4SVD()
        }
        transform.columns.3.y = verticalOffset

        let fittedPoints = arPoints.map { point -> simd_double2 in
            let p = transform * simd_double4(point.x, 0, point.y, 1)
            return simd_double2(p.x, p.z)
        }
        let rms = sqrt(zip(fittedPoints, rtkPoints)
            .map { simd_distance_squared($0, $1) }
            .reduce(0, +) / Double(fitFrames.count))

        guard rms <= rmsThreshold else { return nil }

        // The 2D Procrustes fit's raw angle is the negative of the physical rotation embedded
        // about +Y here (T-R2) — negate back so `yaw` reads as "how much the AR block was
        // rotated".
        let yaw = isDegenerate ? 0 : -atan2(transform.columns.0.z, transform.columns.0.x)

        return Result(
            transform: simd_float4x4(
                SIMD4<Float>(Float(transform.columns.0.x), Float(transform.columns.0.y), Float(transform.columns.0.z), Float(transform.columns.0.w)),
                SIMD4<Float>(Float(transform.columns.1.x), Float(transform.columns.1.y), Float(transform.columns.1.z), Float(transform.columns.1.w)),
                SIMD4<Float>(Float(transform.columns.2.x), Float(transform.columns.2.y), Float(transform.columns.2.z), Float(transform.columns.2.w)),
                SIMD4<Float>(Float(transform.columns.3.x), Float(transform.columns.3.y), Float(transform.columns.3.z), Float(transform.columns.3.w))
            ),
            yaw: yaw,
            translation: simd_double3(transform.columns.3.x, verticalOffset, transform.columns.3.z),
            rms: rms,
            fitPointCount: fitFrames.count,
            isTranslationOnly: isDegenerate
        )
    }
}
