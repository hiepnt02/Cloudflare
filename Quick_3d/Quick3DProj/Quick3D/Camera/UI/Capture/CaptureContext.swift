//
//  CaptureContext.swift
//  Quick3D
//
//  Created by HaNST on 16/3/26.
//

import Foundation
import SwiftUI
import ARKit
import Accelerate

class CaptureContext: CameraContextTemplate, CameraContext {
    
    var delegate: CaptureDelegate?
    
    public private(set) var status: ARStatus = .initial
    
    let meshNode: SCNNode = SCNNode()
    
    var meshes: [UUID: SCNNode] = [:]
    
    private var isEnableMesh = false
    
    private var resolution: ImageResolutionEnum = .normal
    
    private var isReady = false
    
    private var overlapCalculator: OverlapCalculator = FovOverlapCalculator()
    
    private let imageProcessor: ImageProcessor = .init()
    
    private var isProcessing: ThreadSafeValue<Bool> = .init(false)

    private var lastProcessingTime: TimeInterval = 0
     
    private var lastFrameTime: TimeInterval = 0
    
    override func configuration() -> ARConfiguration {
        
        let configuration = ARWorldTrackingConfiguration()
        
        configuration.worldAlignment = .gravity
        configuration.frameSemantics = [.sceneDepth]
        configuration.isAutoFocusEnabled = true
        configuration.environmentTexturing = .none
        configuration.isLightEstimationEnabled = false
        
        isEnableMesh = UserSession.shared.isEnableMesh || UserSession.shared.isSaveMesh
        
        if isEnableMesh {
            configuration.sceneReconstruction = .mesh
        }
        
         
        // Set capture resolution base on setting
        resolution = UserSession.shared.imageResolution
        
        if let format = CameraVideoFormatHelper.videoFromats[resolution] {
             configuration.videoFormat = format
        }
        
        return configuration
    }
    
    override func options() -> ARSession.RunOptions {
        return [.resetTracking, .resetSceneReconstruction, .removeExistingAnchors]
    }
    
    override func setup(_ view: ARSCNView) {

        super.setup(view)

        view.preferredFramesPerSecond = CameraVideoFormatHelper.maxFramesPerSecond

        applyDisplaySettings()

        view.autoenablesDefaultLighting = false
        view.automaticallyUpdatesLighting = false
        
        view.focusEffect = nil
        
        view.session.delegate = self
        
        view.scene.rootNode.addChildNode(meshNode)
    }
    
    func applyDisplaySettings() {
        view?.debugOptions = UserSession.shared.isShowFeaturePoints
            ? [ARSCNDebugOptions.showFeaturePoints]
            : []
    }

    func resetDistances() {
        overlapCalculator.resetDistances()
    }
    
    func perform(_ event: any Event) {
        handle(event) { [weak self] in
            if let ctx = self, let e = event as? CaptureEvent {
                DispatchQueue.main.async {
                    e.call(ctx)
                }
            }
        }
    }
    
    func error(_ error: any Error) {
        CaptureSession.current?.sessionLogger.logProcessing("capture", "error", level: .error, ["error": "\(error)"])
        delegate?.capture(CaptureSession.current, error: error, action: nil)
    }
    
    override func clear() {
        super.clear()
        ARTrackingObject.shared.reset()
    }
    
    func discard() {
        
        imageProcessor.cancel()
        
        StorageManager.cancel()
        
        CaptureSession.stop()
        
        overlapCalculator.lastFrame = nil
        
        DispatchQueue.main.async {
            self.cleanupMesh()
            self.delegate?.capture(CaptureSession.current, didCapture: 0)
            self.delegate?.capture(CaptureSession.current, didCalculateOverlap: 0.0, zDistance: 0.0)
            self.delegate?.capture(CaptureSession.current, didStart: self.isReady)
        }
    }
    
    func cleanupMesh() {
        // Duyệt và xóa sạch các thành phần của từng Mesh node
        for (_, node) in meshes {
            // Giải phóng hình học và vật liệu
            node.geometry?.materials.forEach { $0.diffuse.contents = nil }
            node.geometry = nil
            node.removeFromParentNode()
        }
        
        // Xóa sạch Dictionary
        meshes.removeAll(keepingCapacity: false)
        
        // Đảm bảo node cha cũng sạch sẽ
        meshNode.enumerateChildNodes { (node, _) in
            node.geometry = nil
            node.removeFromParentNode()
        }
    }
    
    func ready(_ value: Bool) {
        if isReady != value {
            isReady = value
            DispatchQueue.main.async {
                self.delegate?.capture(CaptureSession.current, didStart: self.isReady)
            }
        }
    }
    
    func changeStatus(_ status: ARStatus) {
        DispatchQueue.main.async {
            if self.status == status {
                return
            }

            self.status = status
            CaptureSession.current?.sessionLogger.logOperation("statusChanged", ["status": "\(status)"])

            self.delegate?.capture(CaptureSession.current, didChange: status)
        }
    }

    func handleAsync(error: Error, action: (() -> Void)? = nil) {
        CaptureSession.current?.sessionLogger.logProcessing("capture", "error", level: .error, ["error": "\(error)"])
        DispatchQueue.main.async {
            self.delegate?.capture(CaptureSession.current, error: error, action: action)
        }
    }
    
    func waitUntilCompleted() {
        imageProcessor.waitUntilCompleted()
        StorageManager.waitUntilCompleted()
    }
    
    func combine() async throws {
        waitUntilCompleted()
        try await imageProcessor.combine()
    }
}

extension CaptureContext {
    
    private static let sharedWireframeMaterial: SCNMaterial = {
        let mat = SCNMaterial()
        mat.fillMode = .lines
        mat.isDoubleSided = false
        mat.cullMode = .back
        mat.lightingModel = .constant
        mat.diffuse.contents = UIColor.white//UIColor.white.withAlphaComponent(0.7)
        return mat
    }()
    
    private static let sharedOcclusionMaterial: SCNMaterial = {
        let mat = SCNMaterial()
        mat.fillMode = .fill
        mat.isDoubleSided = false
        mat.cullMode = .back
        mat.lightingModel = .constant
        mat.diffuse.contents = UIColor.clear
        return mat
    }()
    
    private func updateMeshGeometry(_ node: SCNNode, anchor: ARMeshAnchor) {
        // TỐI ƯU: Chỉ cập nhật geometry, hạn chế tối đa việc can thiệp vào vật liệu
        let geometry = SCNGeometry(from: anchor.geometry)
        
        // Chỉ gán vật liệu nếu node chưa có hoặc cần thay đổi trạng thái
        if status == .running {
            geometry.firstMaterial = Self.sharedWireframeMaterial
        } else {
            geometry.firstMaterial = Self.sharedOcclusionMaterial
        }
        
        node.geometry = geometry
    }
    
}

extension CaptureContext: ARSessionDelegate {

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard status == .running, isEnableMesh else { return }
                
        // TỐI ƯU: Sử dụng vòng lặp for thay vì compactMap để đạt hiệu năng tốt nhất
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                if !meshNode.isHidden {
                    let node = SCNNode()
                    node.castsShadow = false
                    updateMeshGeometry(node, anchor: meshAnchor)
                    node.simdTransform = meshAnchor.transform
                    
                    meshes[meshAnchor.identifier] = node
                    meshNode.addChildNode(node)
                }
                CaptureSession.current?.appendMesh(meshAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard status == .running, isEnableMesh else { return }
        
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                if !meshNode.isHidden {
                    if let node = meshes[meshAnchor.identifier] {
                        // Cập nhật node hiện có
                        updateMeshGeometry(node, anchor: meshAnchor)
                        node.simdTransform = meshAnchor.transform
                    } else {
                        // Tạo mới nếu chưa có trong dictionary meshes
                        let node = SCNNode()
                        node.castsShadow = false
                        updateMeshGeometry(node, anchor: meshAnchor)
                        node.simdTransform = meshAnchor.transform
                        meshes[meshAnchor.identifier] = node
                        meshNode.addChildNode(node)
                    }
                }
                CaptureSession.current?.appendMesh(meshAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard status == .running, isEnableMesh else { return }
                
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                if let node = meshes.removeValue(forKey: meshAnchor.identifier) {
                    node.removeFromParentNode()
                }
                CaptureSession.current?.removeMesh(meshAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        defer {
            lastFrameTime = frame.timestamp
        }
        
        switch frame.camera.trackingState {
        case .normal:
            break
        default:
            return
        }
        
        ready(true)
        
        // Camera preview update
        CaptureSession.current?.livePreviewContext?.update(frame.camera.transform, frame.camera.eulerAngles)
        
        guard status == .running,
              !isProcessing.value,
              !imageProcessor.isLimited
        else { return }
        
        // Set processing status
        isProcessing.value = true
        
        let fps = 1 / (frame.timestamp - lastFrameTime)
        
        // Handling heavy/async logic in Tasks
        queue.async {
            
            guard let captureSession = CaptureSession.current else {
                self.isProcessing.value = false
                return
            }

            let overlapRate = Float(captureSession.overlapRate)
            let ratioRate = Float(captureSession.ratioRate)
            let smoothingFrames = captureSession.maxSmoothingFrames
            
            guard frame.sceneDepth != nil else {
                self.isProcessing.value = false
                return
            }
            
            let (distance, overlapRatio) = self.overlapCalculator.calculateFromFov(frame, ratioRate, smoothingFrames)
            
            DispatchQueue.main.async {
                self.delegate?.capture(
                    captureSession,
                    didCalculateOverlap: Float(overlapRatio),
                    zDistance: distance
                )
            }
            
            if overlapRatio > overlapRate {
                self.isProcessing.value = false
                return
            }
            
            if #available(iOS 16.0, *), self.resolution == .maximum {
                session.captureHighResolutionFrame { frame, error in
                    if let f = frame {
                        self.process(captureSession, frame: f, fps: fps)
                    } else {
                        self.isProcessing.value = false
                    }
                }
            } else {
                self.process(captureSession, frame: frame, fps: fps)
            }
        }
    }
    
    func process(_ captureSession: CaptureSession, frame: ARFrame, fps: Double) {
        defer {
            self.isProcessing.value = false
        }
        
        // Kiểm tra sự tồn tại của dữ liệu depth
        guard let depthData = frame.sceneDepth else { return }
        
        // Thực hiện lọc dữ liệu (In-place modification)
        applyDepthFilter(depthBuffer: depthData.depthMap,
                        confidenceBuffer: depthData.confidenceMap!)
        
        let index = (self.overlapCalculator.lastFrame?.index ?? 0) + 1
        
        // Khởi tạo FrameData với dữ liệu đã được làm sạch
        if let frameData = try? FrameData(frame: frame, index: index, fps: fps) {
            self.overlapCalculator.lastFrame = FrameMetadata(frameData)
            
            self.imageProcessor.process(captureSession, frame: frameData) {
                DispatchQueue.main.async {
                    self.delegate?.capture(captureSession, didCapture: index)
                }
            } onError: { error in
                self.changeStatus(.pausing)
                self.handleAsync(error: error) {
                    self.discard()
                    self.changeStatus(.stopped)
                }
            }
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        ARTrackingObject.shared.update(state: camera.trackingState)
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        CaptureSession.current?.sessionLogger.logProcessing("ar", "sessionFailed", level: .error, ["error": "\(error)"])
    }

    func sessionWasInterrupted(_ session: ARSession) {
        CaptureSession.current?.sessionLogger.logProcessing("ar", "sessionInterrupted", level: .warning)
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        CaptureSession.current?.sessionLogger.logProcessing("ar", "interruptionEnded")
    }

    func applyDepthFilter(depthBuffer: CVPixelBuffer, confidenceBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(depthBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(confidenceBuffer, .readOnly) // Lock để ghi
        
        defer {
            CVPixelBufferUnlockBaseAddress(depthBuffer, .readOnly)
            CVPixelBufferUnlockBaseAddress(confidenceBuffer, .readOnly)
        }
        
        guard let depthAddr = CVPixelBufferGetBaseAddress(depthBuffer),
              let confAddr = CVPixelBufferGetBaseAddress(confidenceBuffer) else { return }
        
        let width = CVPixelBufferGetWidth(depthBuffer)
        let height = CVPixelBufferGetHeight(depthBuffer)
        let totalPixels = width * height
        
        let depthPtr = depthAddr.assumingMemoryBound(to: Float32.self)
        let confPtr = confAddr.assumingMemoryBound(to: UInt8.self)
        
        // Tìm các vị trí depth > 18 hoặc NaN
        for i in 0..<totalPixels {
            let d = depthPtr[i]
            // d != d là cách kiểm tra NaN nhanh nhất trong Swift
            if d > 18.0 || d != d {
                confPtr[i] = 0
            }
        }
    }
}
