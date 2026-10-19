//
//  CalibrationCalculator.swift
//  Quick3D
//

import simd

enum CalibrationError: Error {
    /// The two world-space points are too close together to determine a direction.
    case pointsTooClose
}

struct CalibrationResult {
    let position: SIMD3<Float>
    let eulerAngles: SIMD3<Float>
    let scale: Float
}

enum CalibrationCalculator {

    /// Minimum horizontal distance (metres) between the two world-space points.
    private static let minimumDistance: Float = 0.05

    /// Computes the AR model's world-space origin and yaw rotation from two calibration points.
    ///
    /// Algorithm:
    ///  1. Project both model-space and world-space direction vectors onto the horizontal plane (Y = 0).
    ///  2. Compute the yaw angle between the two horizontal directions.
    ///  3. Rotate the model origin using that yaw, then solve for the world-space origin.
    ///
    /// - Parameters:
    ///   - point1: The reference point (基準点) — model-space vertex + real-world pin position.
    ///   - point2: The direction point (方向点) — model-space vertex + real-world pin position.
    /// - Throws: `CalibrationError.pointsTooClose` when world points are within `minimumDistance`.
    static func calculate(point1: CalibrationPoint,
                          point2: CalibrationPoint,
                          modelScale: Float = 1) throws -> CalibrationResult {
        let worldDir = SIMD2<Float>(
            point2.worldPosition.x - point1.worldPosition.x,
            point2.worldPosition.z - point1.worldPosition.z
        )
        guard simd_length(worldDir) >= minimumDistance else {
            throw CalibrationError.pointsTooClose
        }

        // If the two model-space points are coincident horizontally, use world direction only.
        let yaw: Float = yawAngle(from: point1, to: point2)

        // Rotate the model-space origin of point1 by yaw around Y, then compute world origin.
        // Model points are picked in the canonical, unscaled model frame (the
        // panel viewport always renders at scale 1). The AR entity applies
        // addtionalScale separately, so it must be reapplied here too —
        // otherwise P1 and CP1 land at different effective scales.
        let rotatedModelPt1 = rotateY(point1.modelPosition * modelScale, yaw: yaw)
        let position = SIMD3<Float>(
            point1.worldPosition.x - rotatedModelPt1.x,
            point1.worldPosition.y - rotatedModelPt1.y,
            point1.worldPosition.z - rotatedModelPt1.z
        )

        // rotateY uses convention R(-θ) in SceneKit terms, so negate yaw for eulerAngles.y
        // to ensure SceneKit applies the same rotation that was used to compute position.
        let eulerAngles = SIMD3<Float>(0, -yaw, 0)
        return CalibrationResult(position: position, eulerAngles: eulerAngles, scale: modelScale)
    }
    
    static func yawAngle(from pt1: CalibrationPoint, to pt2: CalibrationPoint) -> Float {
        let worldDir = SIMD2<Float>(pt2.worldPosition.x - pt1.worldPosition.x,
                                    pt2.worldPosition.z - pt1.worldPosition.z)
        let modelDir = SIMD2<Float>(pt2.modelPosition.x - pt1.modelPosition.x,
                                    pt2.modelPosition.z - pt1.modelPosition.z)
        guard simd_length(modelDir) >= 1e-6 else { return 0 }
        return atan2(worldDir.y, worldDir.x) - atan2(modelDir.y, modelDir.x)
    }

    // MARK: - Private

    private static func rotateY(_ v: SIMD3<Float>, yaw: Float) -> SIMD3<Float> {
        let cosA = cos(yaw)
        let sinA = sin(yaw)
        return SIMD3<Float>(
            cosA * v.x - sinA * v.z,
            v.y,
            sinA * v.x + cosA * v.z
        )
    }
}
