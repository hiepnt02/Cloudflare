//
//  ViewARPreviewContext.swift
//  Quick3D
//
//  Created by HaNST on 20/4/26.
//

import Foundation
import SceneKit

class ViewARPreviewContext: PreviewContextTemplate, PreviewContext {
    
    var delegate: PreviewDelegate?
    
    let live: Bool = true
    
    private var arNode: SCNNode?
    
    private var camera: SCNNode?
    
    private var device: SCNNode?
    
    public private(set) var cameraTransform: simd_float4x4 = matrix_identity_float4x4
    public private(set) var cameraEulerAngles: simd_float3 = .zero
    public private(set) var cameraDistance: Float = 5.0
    
    public private(set) var deviceTransform: simd_float4x4 = matrix_identity_float4x4
    public private(set) var deviceEulerAngles: simd_float3 = .zero
    
    public private(set) var cameraMaxDistance: Float = 0.0
    public private(set) var cameraMinDistance: Float = 0.0
    public private(set) var cameraInitDistance: Float = 0.0
    
    private var isUserControl: ThreadSafeValue<Bool> = .init(false)

    private var nodeMap: [ObjectIdentifier: SCNNode] = [:]
    
    private var cameraFOV: [SIMD3<Float>] = []
    
    private var cameraFOVHeight: Float = 0.0
    
    private var cameraFOVArea: Float = 0.0
    
    func perform(_ event: any Event) {
        handle(event) { [weak self] in
            if let ctx = self, let e = event as? ViewARPreviewEvent {
                DispatchQueue.main.async {
                    e.call(ctx)
                }
            }
        }
    }
    
    override func setup(_ view: SCNView) {
        super.setup(view)
        
        view.backgroundColor = .black
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = false
        
        let scene = SCNScene()
        
        camera = {
            let node = SCNNode()
            let cam = SCNCamera()
            cam.fieldOfView = 60
            cam.zNear = 0.01
            cam.zFar = 1000
            node.camera = cam
            
            return node
        }()

        scene.rootNode.addChildNode(camera!)
        
        view.scene = scene
        view.preferredFramesPerSecond = 15
    }
    
    func createDeviceNode(length: CGFloat) {
        
        self.device?.removeFromParentNode()
        self.device = nil
        
        let deviceNode = SCNNode()
        let themeColor = UIColor.blue
        
        // Helper để thiết lập vật liệu luôn hiển thị phía trước (Render on top)
        func applyAlwaysOnTopStyle(to geometry: SCNGeometry?, color: UIColor, isTransparent: Bool = false) {
            let material = SCNMaterial()
            material.diffuse.contents = isTransparent ? color.withAlphaComponent(0.8) : color
            material.readsFromDepthBuffer = false
            material.writesToDepthBuffer = false
            geometry?.materials = [material]
        }

        // 1. Tạo phần thân (Pyramid)
        let pyramid = SCNPyramid(width: length, height: length, length: length)
        applyAlwaysOnTopStyle(to: pyramid, color: themeColor, isTransparent: true)
        
        let pyramidNode = SCNNode(geometry: pyramid)
        pyramidNode.renderingOrder = 1000
        pyramidNode.simdEulerAngles = SIMD3<Float>(.pi / 2, 0, 0)
        pyramidNode.simdPosition = SIMD3<Float>(0, 0, Float(-length))
        deviceNode.addChildNode(pyramidNode)

        // 2. Tạo phần tâm (Sphere)
        let sphere = SCNSphere(radius: length / 8)
        applyAlwaysOnTopStyle(to: sphere, color: themeColor)
        
        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.renderingOrder = 1000
        deviceNode.addChildNode(sphereNode)

        // Đảm bảo node cha cũng có rendering order cao
        deviceNode.renderingOrder = 100
        
        self.device = deviceNode
        
        self.view?.scene?.rootNode.addChildNode(deviceNode)
    }
    
    override func clear() {
        super.clear()
        self.camera?.removeFromParentNode()
        self.camera = nil
        self.device?.removeFromParentNode()
        self.device = nil
        clearNode()
    }
    
    private func clearNode() {
        if let arNode = self.arNode {
            DispatchQueue.main.async {
                arNode.enumerateChildNodes { (node, _) in
                    node.removeFromParentNode()
                }
                arNode.removeFromParentNode()
            }
        }
        self.arNode = nil
        self.nodeMap.removeAll()
    }
    
    private func fetchNode(_ node: SCNNode) -> SCNNode {
        let _node: SCNNode = SCNNode(geometry: node.geometry)
        _node.name = node.name
        _node.simdTransform = node.simdTransform
        _node.renderingOrder = node.renderingOrder
        _node.opacity = node.opacity
        _node.isHidden = node.isHidden

        // Copy cả node đang ẩn để updateNode tìm được khi hiện lại / kéo opacity > 0
        node.childNodes.forEach { child in
            _node.addChildNode(fetchNode(child))
        }
        
        nodeMap[ObjectIdentifier(node)] = _node
        
        return _node
    }
    
    func load(_ arContext: ViewARContext) {
        clearNode()
        DispatchQueue.main.async {
            let node = self.fetchNode(arContext.arNode)
            self.arNode = node
            self.view?.scene?.rootNode.addChildNode(node)
            self.setupInitialCamera()
        }
    }
    
    func updateNode(_ node: SCNNode?, recursively: Bool = false) {
        DispatchQueue.main.async {
            guard let n = node else { return }
            self.syncNode(n)
            if recursively {
                n.enumerateChildNodes { child, _ in self.syncNode(child) }
            }
        }
    }

    private func syncNode(_ n: SCNNode) {
        guard let _node = nodeMap[ObjectIdentifier(n)] else { return }
        _node.simdTransform = n.simdTransform
        _node.opacity = n.opacity
        _node.isHidden = n.isHidden
        _node.renderingOrder = n.renderingOrder
        // Point cloud đổi depth write bằng cách thay geometry mới
        if _node.geometry !== n.geometry {
            _node.geometry = n.geometry
        }
    }
    
    func updateCamera(_ transform: simd_float4x4, _ eulerAngles: simd_float3) {
        
        deviceTransform = transform
        deviceEulerAngles = eulerAngles
        
        updateDevicePosition()
        
        if !isUserControl.value {
            cameraTransform = transform
            cameraEulerAngles = eulerAngles
            updateCamera()
        }
        
    }
    
    func updateCamera(_ distance: Float, isUserControl: Bool = false) {
        self.isUserControl.value = self.isUserControl.value || isUserControl
        cameraDistance = distance
        updateCamera()
    }
    
    func updateCamera(_ position: SIMD3<Float>, isUserControl: Bool = false) {
        self.isUserControl.value = self.isUserControl.value || isUserControl
        cameraTransform.columns.3 = SIMD4(position, 1.0)
        updateCamera()
    }
    
    func resetCamera() {
        self.isUserControl.value = false
        cameraTransform = deviceTransform
        cameraEulerAngles = deviceEulerAngles
        updateCamera(cameraInitDistance)
    }
    
    private func updateCamera() {
        camera?.simdPosition = [
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y + cameraDistance,
            cameraTransform.columns.3.z
        ]
        camera?.simdEulerAngles = [-.pi / 2, cameraEulerAngles.y, 0]
        calculateFOV()
    }
    
    private func updateDevicePosition() {
        device?.simdPosition = [
            deviceTransform.columns.3.x,
            0,
            deviceTransform.columns.3.z
        ]
        device?.simdEulerAngles = [0, deviceEulerAngles.y, 0]
    }
    
    func setBackgroundColor(_ color: UIColor) {
        view?.backgroundColor = color
    }
    
    func calculateFOV() {
        guard let view = self.view, let camera = self.camera else { return }

        if let fov = view.pointOfView?.camera?.fieldOfView {
            
            let aspect = Float(view.bounds.width / view.bounds.height)
            
            let y = camera.simdPosition.y
            
            let halfHeight = y * tan(Float(fov).radians / 2)
            let halfWidth = halfHeight * aspect

            let height = halfHeight * 2
            let width = halfWidth * 2
            
            let topLeft     = camera.simdTransform * SIMD4(-halfWidth, y, halfHeight, 1)
            let topRight    = camera.simdTransform * SIMD4( halfWidth, y, halfHeight, 1)
            let bottomLeft  = camera.simdTransform * SIMD4(-halfWidth, y, -halfHeight, 1)
            let bottomRight = camera.simdTransform * SIMD4( halfWidth, y, -halfHeight, 1)
            
            cameraFOV = [topLeft.xyz, topRight.xyz, bottomLeft.xyz, bottomRight.xyz]
            
            cameraFOVArea = height * width
            
            cameraFOVHeight = height
            
            let scaleFactor = cameraFOVHeight / 10.0
            device?.simdScale = [scaleFactor, scaleFactor, scaleFactor]
        }
        
    }
    
    func calculateDistance(height: Float) -> Float {
        guard let view = self.view,
              let fov = view.pointOfView?.camera?.fieldOfView else { return 0.0 }
        return height / (2 * tan(Float(fov).radians / 2))
    }
    
    func translated(left: Float, down: Float) -> SIMD3<Float> {

        guard let _view = view else { return .zero }
        
        let p1 = SIMD2<Float>(cameraFOV[0].x, cameraFOV[0].z)
        let p2 = SIMD2<Float>(cameraFOV[1].x, cameraFOV[1].z)

        let leng = cameraFOVHeight / Float(_view.bounds.width)
        
        let _x = left * leng
        let _y = down * leng
        
        let u = simd_normalize(p2 - p1)

        let v = SIMD2<Float>(-u.y, u.x)

        let translation = -_x * u - _y * v

        return [translation.x, 0, translation.y]
    }
    
    private func setupInitialCamera() {
        
        guard let view = self.view,
              let node = arNode else { return }
        
        let aspect = Float(view.bounds.width / view.bounds.height)
        
        let box = node.boundingBox
        let vMin = SIMD3<Float>(box.min)
        let vMax = SIMD3<Float>(box.max)
        let size = vMax - vMin
        
        let maxDimension = max(size.x, max(size.y, size.z))
        
        cameraDistance = maxDimension * 1.0 + 1.0
        
        cameraInitDistance = cameraDistance
        
        if cameraInitDistance < cameraMinDistance {
            cameraInitDistance = cameraMinDistance
            cameraDistance = cameraMinDistance
        }
        
        let a = SIMD2<Float>(vMin.x, vMin.z)
        let b = SIMD2<Float>(vMin.x, vMax.z)
        let c = SIMD2<Float>(vMax.x, vMin.z)
        
        let area = length(a - b) * length(a - c)
        
        let height = sqrt(area * 20 / aspect)
        
        cameraMaxDistance = calculateDistance(height: height)
        
        createDeviceNode(length: 1)
        
        updateCamera()
        
        updateDevicePosition()
    }

}
