//
//  CalibrationVectorArrow.swift
//  Quick3D
//

import SceneKit
import UIKit
import simd

enum CalibrationVectorArrow {

    static let nodeName = "calibration_vector_arrow"
    static let color = UIColor(hex: 0x00FF26)

    private static let extensionRatio: Float = 0.2
    private static let shaftRadiusRatio: Float = 0.008
    private static let dotRadiusRatio: Float = 0.032
    private static let minimumDirectionLength: Float = 1e-5

    /// Vẽ sau cùng để nằm trên mọi geometry khác trong scene.
    static let renderingOrder = 1000

    /// Material không dùng depth nên vật vẽ sau đè vật vẽ trước. Dot phải vẽ sau mũi
    /// tên — chung một renderingOrder thì thứ tự giữa chúng không xác định.
    static let dotRenderingOrder = renderingOrder + 1

    /// Radius for the CP1/CP2 sphere markers so they scale with the same reference
    /// as the arrow drawn between them and never get visually swallowed by it.
    static func dotRadius(boundingRadius: Float) -> Float {
        max(boundingRadius * dotRadiusRatio, 0.01)
    }

    static func tipPosition(from p1: SCNVector3, through p2: SCNVector3, boundingRadius: Float) -> SCNVector3 {
        let origin = SIMD3<Float>(p1)
        let through = SIMD3<Float>(p2)
        let distance = simd_distance(origin, through)
        guard distance > minimumDirectionLength else { return p2 }
        let direction = (through - origin) / distance
        return SCNVector3(through + direction * extensionLength(boundingRadius: boundingRadius))
    }

    /// Builds the full arrow node (shaft + head), or nil when P1 and P2 coincide (EC-1).
    static func makeNode(from p1: SCNVector3, through p2: SCNVector3, boundingRadius: Float) -> SCNNode? {
        let origin = SIMD3<Float>(p1)
        let through = SIMD3<Float>(p2)
        let distance = simd_distance(origin, through)
        guard distance > minimumDirectionLength else { return nil }

        let direction = (through - origin) / distance
        let tip = SIMD3<Float>(tipPosition(from: p1, through: p2, boundingRadius: boundingRadius))
        let totalLength = simd_distance(origin, tip)

        let shaftRadius = max(boundingRadius * shaftRadiusRatio, 0.002)
        let headHeight = min(shaftRadius * 6, totalLength * 0.3)
        let shaftLength = totalLength - headHeight

        let container = SCNNode()
        container.name = nodeName
        container.renderingOrder = renderingOrder

        let shaft = SCNNode(geometry: applyMaterial(SCNCylinder(radius: CGFloat(shaftRadius), height: CGFloat(shaftLength))))
        shaft.simdPosition = origin + direction * (shaftLength / 2)
        shaft.simdOrientation = orientation(for: direction)
        shaft.renderingOrder = renderingOrder
        container.addChildNode(shaft)

        let head = SCNNode(geometry: applyMaterial(SCNCone(topRadius: 0, bottomRadius: CGFloat(shaftRadius * 3), height: CGFloat(headHeight))))
        head.simdPosition = origin + direction * (shaftLength + headHeight / 2)
        head.simdOrientation = orientation(for: direction)
        head.renderingOrder = renderingOrder
        container.addChildNode(head)

        return container
    }

    /// Replaces any existing arrow under `rootNode` with one for the given points;
    /// passing `through: nil` just removes the current arrow (BR-3).
    static func update(in rootNode: SCNNode, from p1: SCNVector3, through p2: SCNVector3?, boundingRadius: Float) {
        rootNode.childNodes
            .filter { $0.name == nodeName }
            .forEach { $0.removeFromParentNode() }
        guard let p2 = p2, let arrow = makeNode(from: p1, through: p2, boundingRadius: boundingRadius) else { return }
        rootNode.addChildNode(arrow)
    }

    // MARK: - Helpers

    private static func extensionLength(boundingRadius: Float) -> Float {
        max(boundingRadius * extensionRatio, 0.01)
    }

    private static func applyMaterial(_ geometry: SCNGeometry) -> SCNGeometry {
        geometry.materials = [alwaysVisibleMaterial(color: color)]
        return geometry
    }

    /// Material của marker hiệu chỉnh: không đọc/ghi depth buffer nên không bao giờ
    /// bị model hay vật thể thật che (QUICK-1024 AC-1 — trước đây mũi tên chìm vào
    /// model tuỳ góc nhìn). Cùng cách làm với trục toạ độ ở CameraContext.
    static func alwaysVisibleMaterial(color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .constant
        material.readsFromDepthBuffer = false
        material.writesToDepthBuffer = false
        return material
    }

    private static func orientation(for direction: SIMD3<Float>) -> simd_quatf {
        let up = SIMD3<Float>(0, 1, 0)
        if simd_dot(up, direction) < -0.9999 {
            return simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
        }
        return simd_quatf(from: up, to: direction)
    }
}
