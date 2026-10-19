//
//  CameraContext.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import Foundation
import ARKit

protocol CameraContext {
    
    associatedtype Delegate
    
    var delegate: Delegate? { set get }
    
    var view: ARSCNView? { get }
    
    func setup(_ view: ARSCNView)
    
    func perform(_ event: Event)
    
    func error(_ error: Error)
    
    func clear()
    
    func restart()
    
    func pause()
    
    func resume()
    
    func start()
    
}

extension CameraContext {
    
    func setupLight(view: ARSCNView) -> (lightNode: SCNNode, ambientNode: SCNNode) {
        return setupLight(scene: view.scene)
    }
    
    func setupLight(scene: SCNScene) -> (lightNode: SCNNode, ambientNode: SCNNode) {
        // 1. Directional Light: Chỉ để tạo khối và hướng sáng (Shader phản hồi)
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.castsShadow = false // Tắt đổ bóng
        directionalLight.intensity = 1000    // Độ sáng mặc định của shader
        
        let lightNode = SCNNode()
        lightNode.light = directionalLight
        
        // Mặc định là Bắc bán cầu (góc âm)
        let pitch: Float = -Float.pi / 3
        // Kiểm tra nếu có dữ liệu tọa độ
        if LocationManager.shared.location.latitude > 0 {
            // Nam bán cầu, xoay trục Y (yaw) một góc 180 độ để ánh sáng chiếu hướng ngược lại
            lightNode.eulerAngles = SCNVector3(pitch, Float.pi, 0)
        } else {
            lightNode.eulerAngles = SCNVector3(pitch, 0, 0)
        }

        lightNode.position = SCNVector3(0, 10, 0)
        scene.rootNode.addChildNode(lightNode)
        
        // 2. Ambient Light: Để vật thể không bị đen ở các góc khuất
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 300
        
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        return (lightNode, ambientNode)
    }
    
    func createAxisNode(radius: CGFloat = 0.01, length: CGFloat = 0.1) -> SCNNode {
        let axisNode = SCNNode()
        
        let yGeometry = SCNCylinder(radius: radius, height: length)
        
        let material = SCNMaterial()
        // Đổi mô hình chiếu sáng thành .constant (Không chịu ảnh hưởng bởi ánh sáng)
        material.lightingModel = .constant
        material.diffuse.contents = UIColor.green
        // Trục toạ độ luôn phải hiển thị đè lên trên, không bị Occlusion hoặc vật thể thật che khuất
        material.readsFromDepthBuffer = false
        material.writesToDepthBuffer = false
        yGeometry.materials = [material]

        let yNode = SCNNode(geometry: yGeometry)
        yNode.position = SCNVector3(0, 0, 0)
        yNode.renderingOrder = 1000
        axisNode.addChildNode(yNode)

        return axisNode
    }
    
}
