//
//  PreviewContext.swift
//  Quick3D
//
//  Created by HaNST on 10/10/25.
//

import Foundation
import SceneKit

protocol PreviewContext {
    
    associatedtype Delegate
    
    var delegate: Delegate? { set get }
    
    var live: Bool { get }
    
    var view: SCNView? { get }
    
    func setup(_ view: SCNView)
    
    func perform(_ event: Event)
    
    func clear()
    
}

open class PreviewContextTemplate: NSObject {
    
    let queue = DispatchQueue(label: "ltd.landlog.scquick3d.PreviewContextTemplate", attributes: [])

    private var eventLast: Int = -1
 
    public private(set) var view: SCNView?
    
    func handle(_ event: Event, execute: @escaping () -> Void) {
        queue.async { [weak self] in
            if self?.eventLast != event.id {
                self?.eventLast = event.id
                execute()
            }
        }
    }
    
    func setup(_ view: SCNView) {
        self.view = view
    }
    
    func clear() {
        self.view?.delegate = nil
        self.view = nil
    }
    
}


class CapturePreviewContext: PreviewContextTemplate, PreviewContext {
    
    var delegate: PreviewDelegate?
    
    private var eventLast: Int = -1
    
    private var pointCloudIndex: Int = 0
    
    private var cameraIndex: Int = 0
    
    // Sử dụng lazy hoặc hằng số để tránh khởi tạo lại
    public private(set) var points: SCNNode?
    public private(set) var frames: SCNNode?
    public private(set) var camera: SCNNode?
    
    public private(set) var isCustomControl: Bool = false
    
    public private(set) var live: Bool
    
    var isWorld: Bool = true
    
    private var cameraTransform: simd_float4x4 = matrix_identity_float4x4
    private var cameraEulerAngles: simd_float3 = .zero
    private let cameraDistance: Float = 4.0
    
    init(live: Bool) {
        self.live = live
    }
    
    func perform(_ event: Event) {
        handle(event) { [weak self] in
            if let ctx = self, let e = event as? CapturePreviewEvent {
                DispatchQueue.main.async {
                    e.call(ctx)
                }
            }
        }
    }
    
    override func clear() {
        super.clear()
        self.pointCloudIndex = 0
        self.cameraIndex = 0
        self.points?.removeFromParentNode()
        self.points = nil
        self.frames?.removeFromParentNode()
        self.frames = nil
        self.camera?.removeFromParentNode()
        self.camera = nil
    }
    
    override func setup(_ view: SCNView) {
        
        super.setup(view)
        
        view.backgroundColor = .black
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = true
        view.delegate = self
        
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
        
        points = SCNNode()
        frames = SCNNode()
        
        scene.rootNode.addChildNode(camera!)
        scene.rootNode.addChildNode(points!)
        scene.rootNode.addChildNode(frames!)
        
        view.scene = scene
        view.preferredFramesPerSecond = 15
        // Tắt rendersContinuously nếu không có chuyển động liên tục để tiết kiệm pin
//        view.rendersContinuously = true
        
        updatePointClouds()
        updateCameras()
        
        if !live, let session = CaptureSession.current {
            setupInitialCamera(session: session)
        }
        
    }
    
    func updatePointClouds() {
        guard let session = CaptureSession.current, let points = self.points else { return }
        
        let currentCloudCount = session.pointClouds.data.count
        if pointCloudIndex < currentCloudCount {
            let dataSlice = session.pointClouds.data[pointCloudIndex..<currentCloudCount]
            pointCloudIndex = currentCloudCount
            for cloud in dataSlice {
                points.addChildNode(cloud.makeSCNNode())
            }
        }
    }
    
    func updateCameras() {
        guard let session = CaptureSession.current, let frames = self.frames  else { return }
        
        let currentCamCount = session.cameras.data.count
        if cameraIndex < currentCamCount {
            let dataSlice = session.cameras.data[cameraIndex..<currentCamCount]
            cameraIndex = currentCamCount
            
            for camData in dataSlice {
                frames.addChildNode(camData.makeSCNNode(live))
            }
        }
    }
    
    private func setupInitialCamera(session: CaptureSession) {
        guard let firstFrame = session.frames.first,
              let frames = self.frames,
              let camera = self.camera
        else { return }
        
        let box = frames.boundingBox
        let vMin = SIMD3<Float>(box.min)
        let vMax = SIMD3<Float>(box.max)
        let center = (vMin + vMax) / 2
        let size = vMax - vMin
        
        let maxDimension = max(size.x, max(size.y, size.z))
        let distance = maxDimension * 1.0
        let elevation = Float.pi / 2
        let azimuth = firstFrame.eulerAngles.y
        
        let x = center.x + distance * cos(elevation) * sin(azimuth)
        let y = center.y + distance * sin(elevation)
        let z = center.z + distance * cos(elevation) * cos(azimuth)
        
        camera.simdPosition = [x, y, z]
        camera.look(at: SCNVector3(center.x, center.y, center.z))
    }
    
    func resetCamera() {
        view?.pointOfView = camera
        if live {
            updateCamera()
        }
    }
    
    func update(_ transform: simd_float4x4, _ eulerAngles: simd_float3) {
        self.cameraTransform = transform
        self.cameraEulerAngles = eulerAngles
        if !isCustomControl {
            updateCamera()
        }
    }

    func updateCamera() {
        if !isWorld {
            if UIDevice.current.isIphone {
                let correctionRotation = SCNMatrix4MakeRotation(.pi / 2, 0, 0, 1)
                let scnTransform = SCNMatrix4Mult(correctionRotation, SCNMatrix4(cameraTransform))
                camera?.transform = scnTransform
            } else {
                camera?.simdTransform = cameraTransform
            }
        } else {
            camera?.simdPosition = [
                cameraTransform.columns.3.x,
                cameraTransform.columns.3.y + cameraDistance,
                cameraTransform.columns.3.z
            ]
            camera?.simdEulerAngles = [-.pi / 2, cameraEulerAngles.y, 0]
        }
    }
    
}

extension CapturePreviewContext: SCNSceneRendererDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if let pointOfView = renderer.pointOfView {
            isCustomControl = camera != pointOfView
            delegate?.preview(CaptureSession.current, didControlCamera: isCustomControl)
        }
    }
    
}

class PreviewContextWrapper<C: PreviewContext>: PreviewContext {
    
    typealias Delegate = C.Delegate
    
    var view: SCNView? {
        context?.view
    }
    
    var delegate: Delegate? {
        get { context?.delegate }
        set { context?.delegate = newValue }
    }
    
    var live: Bool {
        context?.live ?? false
    }
    
    private var context: C? = nil
 
    init(context: C?) {
        self.context = context
    }
    
    public func clear() {
        self.context?.clear()
        self.context = nil
    }
    
    public func setup(_ view: SCNView) {
        context?.setup(view)
    }
    
    func perform(_ event: Event) {
        context?.perform(event)
    }
    
}
