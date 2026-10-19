//
//  AxisView.swift
//  Quick3D
//
//  Created by HaNST on 04/03/26.
//

import SwiftUI
import ARKit
import SceneKit

struct AxisView: UIViewRepresentable {
    
    // Tách logic tạo trục thành một hàm tĩnh để dùng lại
    private static func createAxisNode(radius: CGFloat, length: CGFloat) -> SCNNode {
        let axisNode = SCNNode()
        let axisLength = Float(length * 0.9)
        let headHeight = length * 0.22
        
        // Helper để tạo từng trục
        func addAxis(color: UIColor, rotation: SCNVector3, position: SCNVector3) {
            let cylinder = SCNCylinder(radius: radius, height: CGFloat(axisLength))
            cylinder.firstMaterial?.diffuse.contents = color
            let node = SCNNode(geometry: cylinder)
            node.eulerAngles = rotation
            node.position = position
            axisNode.addChildNode(node)
            
            let cone = SCNCone(topRadius: 0, bottomRadius: radius * 2.2, height: headHeight)
            cone.firstMaterial?.diffuse.contents = color
            let coneNode = SCNNode(geometry: cone)
            coneNode.eulerAngles = rotation
            
            // Tính toán vị trí mũi tên
            if rotation.z != 0 { // X axis
                coneNode.position = SCNVector3(axisLength, 0, 0)
                coneNode.eulerAngles = SCNVector3(0, 0, -Float.pi / 2)
            } else if rotation.x != 0 { // Z axis
                coneNode.position = SCNVector3(0, 0, axisLength)
                coneNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
            } else { // Y axis
                coneNode.position = SCNVector3(0, axisLength, 0)
            }
            axisNode.addChildNode(coneNode)
        }

        addAxis(color: .red, rotation: SCNVector3(0, 0, Float.pi / 2), position: SCNVector3(axisLength/2, 0, 0))
        addAxis(color: .green, rotation: SCNVector3(0, 0, 0), position: SCNVector3(0, axisLength/2, 0))
        addAxis(color: .blue, rotation: SCNVector3(Float.pi / 2, 0, 0), position: SCNVector3(0, 0, axisLength/2))

        // Tối ưu hóa: Gộp tất cả hình học thành 1 node duy nhất để giảm Draw Call
        return axisNode.flattenedClone()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        let scene = SCNScene()
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 60
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = 10
        cameraNode.simdPosition = [0, 0, 2.5]
        scene.rootNode.addChildNode(cameraNode)
        
        let axisNode = Self.createAxisNode(radius: 0.05, length: 1.0)
        scene.rootNode.addChildNode(axisNode)
        context.coordinator.axisNode = axisNode
        
        scnView.scene = scene
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = true // Bật để trục nhìn có khối 3D hơn
        
        // Lưu reference vào helper an toàn hơn
        AxisHelper.shared.axisNode = axisNode
        
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        AxisHelper.shared.axisNode = nil
    }

    class Coordinator {
        var axisNode: SCNNode?
    }
}

// MARK: - Safe Axis Helper
final class AxisHelper {
    static let shared = AxisHelper()
    private init() {}
    
    weak var axisNode: SCNNode?
    
    func updateAxis(for camera: ARCamera) {
        guard let axisNode = axisNode else { return }
        
        // 1. Lấy ma trận xoay của Camera (loại bỏ phần vị trí/translation)
        let cameraTransform = camera.transform
        let cameraRotationMatrix = simd_float3x3(
            SIMD3(cameraTransform.columns.0.x, cameraTransform.columns.0.y, cameraTransform.columns.0.z),
            SIMD3(cameraTransform.columns.1.x, cameraTransform.columns.1.y, cameraTransform.columns.1.z),
            SIMD3(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
        )
        
        // 2. Chuyển sang Quaternion
        let cameraQuat = simd_quaternion(cameraRotationMatrix)
        
        // 3. Logic bù trừ hướng cho thiết bị
        var finalRotation: simd_quatf
        
        if UIDevice.current.userInterfaceIdiom == .phone {
            // Đối với iPhone Portrait:
            // Cần xoay thêm để khớp với hệ tọa độ màn hình dọc
            let correction = simd_quaternion(Float.pi / 2, SIMD3<Float>(0, 0, 1))
            finalRotation = simd_inverse(cameraQuat * correction)
        } else {
            // Đối với iPad hoặc chế độ Landscape chuẩn
            finalRotation = simd_inverse(cameraQuat)
        }
        
        // 4. Cập nhật UI mượt mà
        DispatchQueue.main.async {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.05 // Giảm xuống để phản hồi nhanh hơn
            axisNode.simdOrientation = finalRotation
            SCNTransaction.commit()
        }
    }
}
