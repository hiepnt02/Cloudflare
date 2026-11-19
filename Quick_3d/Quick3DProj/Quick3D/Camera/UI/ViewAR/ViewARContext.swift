//
//  ViewARContext.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import Foundation
import SwiftUI
import RealityKit
import ARKit
import simd
import Alamofire
import Combine

import SceneKit
import VigramSDK

extension SCNGeometry {
    static func from(meshAnchor: ARMeshAnchor) -> SCNGeometry {
        let vertices = meshAnchor.geometry.vertices
        let faces = meshAnchor.geometry.faces
        
        let vertexSource = SCNGeometrySource(
            buffer: vertices.buffer,
            vertexFormat: vertices.format,
            semantic: .vertex,
            vertexCount: vertices.count,
            dataOffset: vertices.offset,
            dataStride: vertices.stride
        )
        
        let element = SCNGeometryElement(
            buffer: faces.buffer,
            primitiveType: .triangles,
            primitiveCount: faces.count,
            bytesPerIndex: faces.bytesPerIndex
        )
        
        return SCNGeometry(sources: [vertexSource], elements: [element])
    }
}


class ViewARContext: CameraContextTemplate, CameraContext, @unchecked Sendable {
    
    var delegate: ViewARDelegate?
    private var subscription = Set<AnyCancellable>()

    private var isReady = false
    private var project: SfmProject?
    private var arRendered = false
    private var isCalculating = false
    
    var arUpdatePosition = false
    var isAllowARUpdatePosition = true
    var arPosition: SIMD3<Float> = .zero
    var arEulerAngles: SIMD3<Float> = .zero
    
    var addtionalPosition: SIMD3<Float> = .zero
    var addtionalEulerAngles: SIMD3<Float> = .zero
    var addtionalScale: Float = 1
    
    // Position History Settings
    var positionHistories: [PositionHistory] = []
    var positionHistoryTime: Date = .init()
    var positionHistoryMaxSize: Int = 50
    var positionHistoryHorizontal: Double = 0.015
    var positionHistoryDistance: Double = 0.5
    var positionHistoryDuration: Double = 0.25
    var isPositionHisttory = false
    
    private var previousCameraCoordinate: SIMD3<Double> = .zero
    private var previousFrameTimestamp: TimeInterval = Date().timeIntervalSince1970
    var cameraVelocitySmoothing: SIMD3<Double> = .zero
    
    var calculateAccuracy: Double = 0.0
    
    // SceneKit Nodes
    let arNode: SCNNode = SCNNode()
    let axisNode: SCNNode = SCNNode()
    var lightNode: SCNNode?
    var ambientNode: SCNNode?
    var pointCloudNode: SCNNode?
    var ifcNode: SCNNode? {
        didSet {
            // Gắn ngay khi model vừa nạp xong: material của USDZ chỉ tồn tại
            // từ lúc này, và độ cao sàn có thể đã biết từ trước đó.
            guard let node = ifcNode else {
                ifcMaterials = []
                return
            }
            ifcMaterials = BelowGroundFade.attach(to: node)
            pushGroundPlaneFade()
            applyIfcRenderState()
        }
    }

    /// Material của model design đã gắn shader modifier làm nhạt phần dưới sàn.
    /// Cache lại để mỗi lần đổi độ cao sàn không phải duyệt lại cả cây USDZ.
    private var ifcMaterials: [SCNMaterial] = []

    private var downloadLasTask: Task<Void, Never>?
    
    @AppStorage("isLightOn")
    private var isLightOn: Bool = true
    
    weak var previewContext: ViewARPreviewContext?

    private var nodesRenderingOrder: Int = 0

    private enum TransparentOrderOffset {
        static let ifc = 1
        static let pointCloud = 2
    }

    weak var arSceneView: ARSCNView?
    private let sharedOcclusionMaterial: SCNMaterial = {
        let mat = SCNMaterial()
        mat.colorBufferWriteMask = []
        mat.readsFromDepthBuffer = true
        mat.writesToDepthBuffer = true
        mat.lightingModel = .constant
        mat.isDoubleSided = false
        return mat
    }()
    
    /// Anchor của mặt sàn đang được vẽ lưới, cùng diện tích của nó. ARKit tách
    /// mặt sàn thành nhiều plane anchor chồng lấn nên chỉ giữ một cái lớn nhất.
    private var groundPlaneAnchorId: UUID?
    private var groundPlaneArea: Float = 0

    /// Độ cao (world-space, scene-root-space) của mặt sàn đang được vẽ lưới,
    /// hoặc nil nếu chưa phát hiện được mặt sàn nào. Đẩy xuống
    /// MetalViewARProgram để point cloud tự làm nhạt phần dưới mặt sàn —
    /// độc lập với PlaneGridNode.fillAlpha, giờ chỉ còn là giá trị trang trí.
    private var groundPlaneWorldY: Float?

    /// Ngưỡng thay đổi Y tối thiểu (mét) trước khi đẩy lại xuống shader. ARKit
    /// tinh chỉnh plane anchor liên tục vài mm mỗi lần cập nhật; không có
    /// ngưỡng này thì ranh giới nhạt sẽ rung theo, giống lý do
    /// PlaneGridNode.updateThreshold tồn tại.
    private static let groundPlaneWorldYThreshold: Float = 0.01

    private var lastMeshUpdateTimes: [UUID: TimeInterval] = [:]
    private let meshUpdateInterval: TimeInterval = 0.3
    private var meshVertexCounts: [UUID: Int] = [:]
    
    var isAROcclusion: Bool = false
    var isShowMeshWireframe: Bool = false
    var isEnablePlaneDetection: Bool = false

    /// Hiển thị lưới ô vuông trên mặt sàn mà ARKit phát hiện được.
    /// Mặc định tắt, người dùng bật trong panel setting của màn AR.
    var isShowPlaneGrid: Bool = false

    /// Occlusion bằng plane chỉ dành cho máy không hỗ trợ scene mesh: máy có mesh
    /// đã occlusion đúng theo hình dạng thực, còn plane là hình chữ nhật thường
    /// tràn ra ngoài vùng thực nên sẽ che sai vật thể ảo.
    private var isPlaneOcclusionEnabled: Bool {
        isAROcclusion && !ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    private lazy var sharedWireframeMaterial: SCNMaterial = {
        let mat = SCNMaterial()
        mat.fillMode = .lines
        mat.diffuse.contents = UIColor.white.withAlphaComponent(0.6)
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        return mat
    }()
    
    override func setup(_ view: ARSCNView) {
        super.setup(view)
        
        self.arSceneView = view
        
        view.debugOptions = []
        view.autoenablesDefaultLighting = false
        view.automaticallyUpdatesLighting = false
        view.session.delegate = self
        view.delegate = self
        
        // Setup Nodes trên Main Thread
        DispatchQueue.main.async {
            (self.lightNode, self.ambientNode) = self.setupLight(view: view)
            self.lightNode?.isHidden = !self.isLightOn
            
            view.scene.rootNode.addChildNode(self.arNode)
            view.scene.rootNode.addChildNode(self.axisNode)
            self.axisNode.addChildNode(self.createAxisNode(radius: 0.001, length: 100))
            self.axisNode.isHidden = true
        }
    }
    
    func perform(_ event: any Event) {
        handle(event) { [weak self] in
            guard let self = self, let e = event as? ViewAREvent else { return }
            // Đảm bảo event call luôn chạy trên Main Actor nếu nó tác động UI
            Task { @MainActor in
                e.call(self)
            }
        }
    }
    
    func error(_ error: Error) {
        Task { @MainActor in
            delegate?.ar(project, error: error)
        }
    }
    
    override func clear() {
        super.clear()
        downloadLasTask?.cancel()
        downloadLasTask = nil
        lastMeshUpdateTimes.removeAll()
        meshVertexCounts.removeAll()

        DispatchQueue.main.async {
            self.arNode.enumerateChildNodes { (node, _) in
                node.removeFromParentNode()
            }
            self.arNode.removeFromParentNode()
            self.axisNode.removeFromParentNode()
            self.lightNode?.removeFromParentNode()
        }
    }
    
    override func configuration() -> ARConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.isAutoFocusEnabled = true
        configuration.environmentTexturing = .none
        
        if isAROcclusion {
            configureOcclusionEnabled(configuration)
        } else {
            configureOcclusionDisabled(configuration)
        }

        if let format = CameraVideoFormatHelper.videoFromats[.normal] {
             configuration.videoFormat = format
        }
        
        return configuration
    }
    
    override func options() -> ARSession.RunOptions {
        return [.resetTracking, .removeExistingAnchors]
    }
    
    func ready() {
        guard !isReady else { return }
        isReady = true
        Task { @MainActor in
            delegate?.ar(project, didStart: isReady)
        }
    }
    
    func cancel() {
        clear()
        project?.cancel()
    }
    
    // MARK: - UI & Node Updates (Main Thread Safe)
    func updatePointCloudOpacity(for node: SCNNode, opacity: CGFloat) {
        project?.program.pointCloudNodeOpacity = Float(opacity)
        DispatchQueue.main.async {
            self.pointCloudNode?.isHidden = opacity == 0
            self.applyPointCloudRenderState()
        }
    }

    private func applyPointCloudRenderState() {
        guard let root = pointCloudNode else { return }

        let opacity = project?.program.pointCloudNodeOpacity ?? 1.0
        let isTransparent = opacity < 1.0
        let order = nodesRenderingOrder + (isTransparent ? TransparentOrderOffset.pointCloud : 0)
        let writesDepth = !isTransparent

        let apply: (SCNNode) -> Void = { node in
            node.renderingOrder = order

            guard let geometry = node.geometry,
                  geometry.firstMaterial?.writesToDepthBuffer != writesDepth else { return }

            let rebuilt = SCNGeometry(sources: geometry.sources, elements: geometry.elements)
            rebuilt.firstMaterial = ARProjectHelper.makePointCloudMaterial(writesDepth: writesDepth)
            rebuilt.program = geometry.program
            node.geometry = rebuilt
        }

        apply(root)
        root.enumerateChildNodes { node, _ in apply(node) }
        previewContext?.updateNode(root, recursively: true)
    }

    private func applyIfcRenderState() {
        guard let root = ifcNode else { return }

        let apply: (SCNNode) -> Void = { node in
            let isTransparent = node.geometry?.materials.contains { !$0.writesToDepthBuffer } ?? false
            node.renderingOrder = self.nodesRenderingOrder + (isTransparent ? TransparentOrderOffset.ifc : 0)
        }

        apply(root)
        root.enumerateChildNodes { node, _ in apply(node) }
        previewContext?.updateNode(root, recursively: true)
    }
    
    func setLightNodeVisible(_ visible: Bool) {
        lightNode?.isHidden = !visible
    }
    
    func setVisibility(nodeName: String?, visible: Bool) {
        DispatchQueue.main.async {
            if let name = nodeName {
                let node = self.arNode.childNode(withName: name, recursively: true)
                node?.isHidden = !visible
                self.previewContext?.updateNode(node)
            } else {
                self.ifcNode?.isHidden = !visible
                self.previewContext?.updateNode(self.ifcNode)
            }
        }
    }
    
    func updateOpacity(for node: LayerNode?, opacity: Double) {
        DispatchQueue.main.async {
            if let node = node {
                self.setLayerOpacity(node, opacity: opacity)
            } else {
                self.ifcNode?.opacity = CGFloat(opacity)
                self.setIfcDepthWrite(on: self.ifcNode, isTransparent: opacity < 1.0, recursively: true)
                self.previewContext?.updateNode(self.ifcNode)
            }
            self.applyIfcRenderState()
        }
    }

    private func setLayerOpacity(_ node: LayerNode, opacity: Double) {
        setOpacity(nodeName: node.name, opacity: opacity)
        for child in node.children {
            setLayerOpacity(child, opacity: opacity)
        }
    }
    
    private func setOpacity(nodeName: String, opacity: Double) {
        if let scnNode = arNode.childNode(withName: nodeName, recursively: true) {
            let material = scnNode.geometry?.firstMaterial
            material?.transparency = CGFloat(1.0 - opacity)
            material?.transparencyMode = .rgbZero
            setIfcDepthWrite(on: scnNode, isTransparent: opacity < 1.0, recursively: false)
            previewContext?.updateNode(scnNode)
        }
    }

    private func setIfcDepthWrite(on node: SCNNode?, isTransparent: Bool, recursively: Bool) {
        guard let node = node else { return }

        let apply: (SCNNode) -> Void = { target in
            target.geometry?.materials.forEach { material in
                material.writesToDepthBuffer = !isTransparent
            }
        }

        apply(node)
        if recursively {
            node.enumerateChildNodes { child, _ in apply(child) }
        }
    }
    
    func updatePointCloudSize(to newSize: CGFloat) {
        project?.program.pointSize = Float(newSize)
    }
    
    func updateARPosition(position: SIMD3<Float>, eulerAngles: SIMD3<Float>, scale: Float) {
        self.addtionalPosition = position
        self.addtionalEulerAngles = eulerAngles
        self.addtionalScale = scale
        DispatchQueue.main.async {
            self.arNode.simdPosition = self.arPosition + self.addtionalPosition
            self.arNode.simdEulerAngles = self.arEulerAngles + self.addtionalEulerAngles
            self.arNode.simdScale = SIMD3<Float>(self.addtionalScale, self.addtionalScale, self.addtionalScale)

            self.updateNodesRenderingOrder(to: self.isAROcclusion ? 100 : 0)

            self.updateAxisPosition()
            self.updateCalculateAccuracy()
        }
    }

    func applyCalibrationBaseline(position: SIMD3<Float>, eulerAngles: SIMD3<Float>, scale: Float) {
        self.arPosition = position
        self.arEulerAngles = eulerAngles
        updateARPosition(position: .zero, eulerAngles: .zero, scale: scale)
    }

    func updateAxisPosition() {
        if Thread.isMainThread {
            axisNode.simdPosition = arNode.simdPosition
        } else {
            DispatchQueue.main.async { self.axisNode.simdPosition = self.arNode.simdPosition }
        }
        
        previewContext?.updateNode(arNode)
    }
}

// MARK: - ARSessionDelegate & Calculation
extension ViewARContext: ARSessionDelegate {
    
    func scaleAxis(for camera: ARCamera) {
        let axisPos = axisNode.simdPosition
        let cameraPos = camera.transform.columns.3.xyz
        
        let distance = simd_length(axisPos - cameraPos)
        
        let scaleFactor = max(1, distance * 2)
        
        axisNode.simdScale = [scaleFactor, scaleFactor, scaleFactor]

    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard case .normal = frame.camera.trackingState else { return }
        
        ready()
        
        updateCameraVelocity(cameraCoordinate: SIMD3<Double>(frame.camera.transform.columns.3.xyz),
                             timestamp: frame.timestamp)
        
        // Background updates
        updatePositionHistory(frame: frame)
        
        if isAllowARUpdatePosition && arUpdatePosition {
            let camPosition = simd_make_float3(frame.camera.transform.columns.3)
            let location = LocationManager.shared.location
            
            Task(priority: .userInitiated) {
                await calculateARPosition(position: camPosition, location: location)
            }
            arUpdatePosition = false
        }
        
        // UI Helper update
        DispatchQueue.main.async {
            AxisHelper.shared.updateAxis(for: frame.camera)
            self.previewContext?.updateCamera(frame.camera.transform, frame.camera.eulerAngles)
            self.scaleAxis(for: frame.camera)
        }
    }
    
    private func updateCameraVelocity(cameraCoordinate: SIMD3<Double>, timestamp: TimeInterval){
        let smoothingRatio = 0.8
        if previousCameraCoordinate == .zero {
            previousCameraCoordinate = cameraCoordinate
            previousFrameTimestamp = timestamp
            return
        }
        
        let currentCameraVelocity = (cameraCoordinate - previousCameraCoordinate) / (timestamp - previousFrameTimestamp)
        
        cameraVelocitySmoothing = cameraVelocitySmoothing * smoothingRatio + currentCameraVelocity * (1 - smoothingRatio)
        previousCameraCoordinate = cameraCoordinate
        previousFrameTimestamp = timestamp
        
    }
    
    private func calculateARPosition(position: SIMD3<Float>, location: LocationModel) async {
        guard !isCalculating, let sfmProject = project else { return }
        isCalculating = true
        
        await MainActor.run { delegate?.ar(sfmProject, willCalculate: sfmProject.offset) }
        
        do {
            let offset = try await calculateOffset(location, sfmProject.projectId)
            let orientationMatrix = calculateOrientationMatrix(Double(self.addtionalScale))
            
            let filterdHistory = positionHistories.filter { $0.offset != nil }
            if filterdHistory.count > 2 {
                delegate?.ar(sfmProject, arPositionDidMatch: true)
            }
            let finalTransform: simd_double4x4 = {
                var t = orientationMatrix
                if positionHistories.count > 1 {
                    t.columns.3 -= simd_double4(sfmProject.offset, 0.0)
                }
                return t.inverse
            }()
            
            print("count:", filterdHistory.count)
            print("finalTransform", finalTransform)
            let T = Transformation(finalTransform, order: .yxz)
            let newPos = simd_float3(T.translation)
            let newEuler = T.eulerAngles.float3
            
            await MainActor.run {
                self.arPosition = newPos
                self.arEulerAngles = newEuler
                self.arNode.simdPosition = self.arPosition + self.addtionalPosition
                self.arNode.simdEulerAngles = self.arEulerAngles + self.addtionalEulerAngles
                
                self.updateNodesRenderingOrder(to: self.isAROcclusion ? 100 : 0)

                let currentScale = self.addtionalScale
                self.arNode.simdScale = SIMD3<Float>(currentScale, currentScale, currentScale)
                
                UserSession.shared.position = newPos
                UserSession.shared.eulerAngles = newEuler
                
                self.updateAxisPosition()
                self.delegate?.ar(sfmProject, didCalculate: SIMD3<Double>(newPos))
                
                updateCalculateAccuracy()
            }
        } catch {
            await MainActor.run {
                self.delegate?.ar(sfmProject, didFailToCalculate: error)
            }
        }
        isCalculating = false
    }
    
    private func updatePositionHistory(frame: ARFrame) {
        guard isPositionHisttory, let sfmProject = project else { return }
        
        let now = Date()
        guard now.timeIntervalSince(positionHistoryTime) > positionHistoryDuration else { return }
        
        let coord = make_simd_double3(frame.camera.transform.columns.3)
        let location = LocationManager.shared.location
        
        let lastDistance = positionHistories.last?.distance(coord) ?? Double.greatestFiniteMagnitude
        let isLocationAccurate = location.horizontal <= positionHistoryHorizontal && location.horizontal > 0.0
        let isDistanceSignificant = lastDistance >= positionHistoryDistance
        
        if isLocationAccurate && isDistanceSignificant {
            positionHistoryTime = now
            let frameTimestamp = frame.time
            let location = self.createGGALocation()
            
            let duration = location.timestamp.timeIntervalSince1970 - frameTimestamp.timeIntervalSince1970
            let delta = self.cameraVelocitySmoothing * (duration < 1 ? duration : 0.0)
            
            let position = PositionHistory(coord: coord + delta, location: location, projectId: sfmProject.projectId, frameTimestamp: frameTimestamp)
            
            if positionHistories.count >= positionHistoryMaxSize {
                positionHistories.removeFirst().cancel()
            }
            positionHistories.append(position)
            arUpdatePosition = true
        }
    }
    
    private func createGGALocation() -> LocationModel {
        guard let gga: GGAMessage = RTKManager.shared.nmea.value.gga,
              let attitude = MotionManager.shared.attitude.value,
              let coordinateCorrected:GPSCoordinate = gga.coordinate?.translate(offset: RTKManager.shared.mapToAntennaOffset(),
                                                         orientation: .init(pitch: attitude.pitch,
                                                                            roll: attitude.roll,
                                                                            yaw: attitude.yaw))
        else {
            return LocationManager.shared.location
        }
       
        
        let calendar = Calendar(identifier:.gregorian)
        var vigramTimeStamp = nil as Date?
        if gga.time != nil {
            var components = calendar.dateComponents(in: TimeZone(secondsFromGMT: 0)! , from: Date())
            components.hour = gga.time?.hour
            components.minute = gga.time?.minute
            let originalSec = gga.time!.second
            components.second = Int(floor(originalSec))
            components.nanosecond = Int((originalSec - floor(originalSec)) * 1_000_000_000)
            vigramTimeStamp = calendar.date(from: components)!
        }
        let deviceTimeStamp = vigramTimeStamp ?? (gga.timeStampUnix as Date?) ?? Date()
        
        let location: LocationModel = .init(
            latitude: coordinateCorrected.latitude,
            longitude: coordinateCorrected.longitude,
            altitude: coordinateCorrected.altitude,
            horizontal: gga.accuracy?.horizontal ?? 0.2,
            vertical: gga.accuracy?.vertical ?? 0.2,
            heading: 0.10,
            coordinate: UserSession.shared.coordinateSystemNtrip?.id ?? defaultCoordinate,
            isRTK: true,
            timestamp: deviceTimeStamp)
                                            
        return location
    }
    
    private func calculateOffset(_ location: LocationModel, _ projectId: String) async throws -> SIMD3<Double> {
        if let converted = try await PositionModel.transformLocations(location.coordinate, location, projectId) {
            return [converted.longitude, converted.altitude, -converted.latitude]
        }
        return .zero
    }
    
    private func calculateOrientationMatrix(_ scale: Double) -> simd_double4x4 {
        let filtered = positionHistories.filter { $0.offset != nil }
        let transformD = ImageCalculator.calculateLocations(filtered, scale)
        return simd_double4x4(
            transformD.columns.0,
            transformD.columns.1,
            transformD.columns.2,
            transformD.columns.3
        )
    }
    
    private func updateCalculateAccuracy(){
        guard let sfmProject = project else { return }
        let filterdHistory = positionHistories.filter { $0.offset != nil }
        
        self.calculateAccuracy = ImageCalculator.calculateAccuracy(matrix: self.arNode.simdTransform,
                                          offset: sfmProject.offset,
                                          source: filterdHistory.map{$0.coord},
                                          target: filterdHistory.map{$0.offset!})
    }
}

// MARK: - Networking
extension ViewARContext {
    
    func downloadARProject(projectId: String, isAR: Bool) {
        project = SfmProject(projectId: projectId, isAR: isAR)
        // project vừa được gán có MetalViewARProgram mới toanh (hasGroundPlane
        // mặc định false) — đẩy lại trạng thái mặt sàn đã biết trước đó (nếu có)
        // để không bị mất khi màn hình tải project mới.
        pushGroundPlaneFade()
        isPositionHisttory = true
        var isUpdatedBefore = false

        downloadLasTask = Task(priority: .background) { [weak self] in
            guard let self = self else { return }

            await MainActor.run { self.delegate?.ar(self.project, willDownload: projectId) }

            self.project?.render(arNode: self.arNode) { [weak self] pcNode, ifcNode in
                self?.pointCloudNode = pcNode
                self?.ifcNode = ifcNode
            } onUpdateOffset: { [weak self] offset in
                guard let self = self else { return }
                self.arUpdatePosition = true
                self.arRendered = true
                if !isUpdatedBefore {
                    self.delegate?.ar(self.project, didDownloadPointCloudItem: offset)
                    isUpdatedBefore = true
                }
            } onError: { [weak self] error in
                let code = (error as? AFError)?.responseCode ?? 500
                self?.delegate?.ar(self?.project, didFailToDownload: code)
            } onLasError: { [weak self] error in
                self?.delegate?.ar(self?.project, didFailToDownloadPointCloud: error)
            } onIfcError: { [weak self] error in
                self?.delegate?.ar(self?.project, didFailToDownloadIFC: error)
            } onComplete: { [weak self] in
                self?.placeArNodeOnHorizontalPlane()
                self?.delegate?.ar(self?.project, didDownload: self?.project?.offset ?? .zero )
            } onLasComplete: { [weak self] in
                guard let self = self else { return }
                self.nodesRenderingOrder = self.isAROcclusion ? 100 : 0
                self.applyPointCloudRenderState()
                self.delegate?.ar(self.project, didDownloadPointCloud: self.project?.offset ?? .zero )
            } onLasProgressChanged: { [weak self] progress in
                self?.delegate?.ar(self?.project, onPointCloudProgressChanged: progress)
            } onIfcComplete: { [weak self] layers in
                self?.delegate?.ar(self?.project, didDownloadIFC: layers)
            }
        }
    }
}

extension ViewARContext {
    
    /// Reconfigure the running session without resetting world tracking.
    /// Use this instead of start() when tracking must be preserved (e.g. after calibration).
    func reconfigureWithoutReset() {
        guard let session = arSceneView?.session,
              let config = session.configuration as? ARWorldTrackingConfiguration else { return }

        if self.isAROcclusion {
            configureOcclusionEnabled(config)
            setupHighQualityRendering()
        } else {
            configureOcclusionDisabled(config)
        }
        session.run(config)
    }

    /// Bật hoặc tắt lưới sàn và cập nhật lại cấu hình phiên AR (plane detection).
    func togglePlaneGrid(isEnabled: Bool) {
        print("ARContext: Plane grid is now \(isEnabled)")
        self.isShowPlaneGrid = isEnabled

        guard let session = self.arSceneView?.session,
              let config = session.configuration as? ARWorldTrackingConfiguration else { return }

        if isAROcclusion {
            configureOcclusionEnabled(config)
        } else {
            configureOcclusionDisabled(config)
        }

        session.run(config)

        if isEnabled {
            addPlaneGridToExistingAnchors()
        } else {
            removePlaneGrids()
        }
    }

    /// Vẽ lưới cho những plane anchor đã tồn tại trước khi tính năng được bật.
    private func addPlaneGridToExistingAnchors() {
        guard let anchors = arSceneView?.session.currentFrame?.anchors else { return }

        for anchor in anchors {
            guard let planeAnchor = anchor as? ARPlaneAnchor,
                  let node = arSceneView?.node(for: anchor) else { continue }
            node.isHidden = false
            updatePlaneGrid(on: node, for: planeAnchor)
        }
    }

    /// Bật hoặc tắt tính năng bao phủ (Occlusion) và cập nhật lại cấu hình phiên AR
    func toggleOcclusion(isEnabled: Bool) {
        print("ARContext: Occlusion is now \(isEnabled)")
        self.isAROcclusion = isEnabled
        
        guard let session = self.arSceneView?.session,
              let config = session.configuration as? ARWorldTrackingConfiguration else { return }
        
        // 1. Cập nhật cấu hình Session
        if isEnabled {
            configureOcclusionEnabled(config)
            setupHighQualityRendering()
        } else {
            configureOcclusionDisabled(config)
        }
        
        session.run(config)
        
        // 2. Cập nhật các Node hiện có trong Frame
        updateExistingAnchors(isEnabled: isEnabled)
    }
    
    private func configureOcclusionEnabled(_ config: ARWorldTrackingConfiguration) {
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
            // Config này được chia sẻ với màn calibration (đang cần cả mặt đứng
            // cho raycast) nên chỉ bổ sung mặt ngang cho lưới sàn, không ghi đè
            config.planeDetection.formUnion(planeGridDetection())
        } else {
            config.planeDetection = [.horizontal, .vertical]
        }
        
        updateNodesRenderingOrder(to: 100)
    }
    
    private func configureOcclusionDisabled(_ config: ARWorldTrackingConfiguration) {
        config.frameSemantics = []
        if isShowMeshWireframe, ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        } else {
            config.sceneReconstruction = []
        }
        config.planeDetection = isEnablePlaneDetection ? [.horizontal, .vertical] : planeGridDetection()

        updateNodesRenderingOrder(to: 0)
    }

    /// Lưới sàn cần plane detection ngang, kể cả khi các chế độ khác không dùng plane.
    private func planeGridDetection() -> ARWorldTrackingConfiguration.PlaneDetection {
        isShowPlaneGrid ? [.horizontal] : []
    }

    private func updateExistingAnchors(isEnabled: Bool) {
        guard let anchors = arSceneView?.session.currentFrame?.anchors else { return }
        
        // Occlusion bằng plane chỉ dùng cho máy không hỗ trợ scene mesh
        let isPlaneOcclusion = isEnabled && !ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        
        for anchor in anchors {
            guard let node = arSceneView?.node(for: anchor) else { continue }
            
            if let meshAnchor = anchor as? ARMeshAnchor {
                // Chỉ hiển thị các node mesh khi bật Occlusion
                node.isHidden = !isEnabled
                guard isEnabled else { continue }
                updateMeshNode(node, with: meshAnchor)
            } else if let planeAnchor = anchor as? ARPlaneAnchor {
                // Lưới sàn hiển thị độc lập với Occlusion nên chỉ ẩn/hiện node
                // occlusion thay vì ẩn cả node của anchor
                node.isHidden = !(isPlaneOcclusion || isShowPlaneGrid)
                node.childNode(withName: "PlaneOcclusionNode", recursively: false)?.isHidden = !isPlaneOcclusion
                if isPlaneOcclusion {
                    handlePlaneOcclusion(node, for: planeAnchor)
                }
                if isShowPlaneGrid {
                    updatePlaneGrid(on: node, for: planeAnchor)
                }
            }
        }
    }
    
    private func handlePlaneOcclusion(_ node: SCNNode, for planeAnchor: ARPlaneAnchor) {
        if node.childNode(withName: "PlaneOcclusionNode", recursively: false) == nil {
            addPlaneOcclusion(to: node, for: planeAnchor)
        } else {
            updatePlaneOcclusion(node, for: planeAnchor)
        }
    }

    private func setupHighQualityRendering() {
        self.arSceneView?.antialiasingMode = .multisampling4X
        self.arSceneView?.preferredFramesPerSecond = 60
        self.arSceneView?.isJitteringEnabled = false
    }
    
    private func updateNodesRenderingOrder(to order: Int) {
        // Sử dụng giá trị truyền vào thay vì fix cứng 100
        nodesRenderingOrder = order
        arNode.renderingOrder = order
        ifcNode?.renderingOrder = order
        pointCloudNode?.renderingOrder = order
        
        arNode.enumerateChildNodes { (node, _) in
            node.renderingOrder = order
            node.geometry?.firstMaterial?.readsFromDepthBuffer = true
        }

        applyPointCloudRenderState()
        applyIfcRenderState()
    }
}

extension ViewARContext: ARSCNViewDelegate {

    // MARK: - Delegate Methods
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let meshAnchor = anchor as? ARMeshAnchor {
            guard isAROcclusion || isShowMeshWireframe else { return }
            updateMeshNode(node, with: meshAnchor)
        } else if let planeAnchor = anchor as? ARPlaneAnchor {
            if isPlaneOcclusionEnabled {
                addPlaneOcclusion(to: node, for: planeAnchor)
            }
            if isShowPlaneGrid {
                updatePlaneGrid(on: node, for: planeAnchor)
            }
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let meshAnchor = anchor as? ARMeshAnchor {
            guard isAROcclusion || isShowMeshWireframe else { return }
            handleMeshUpdate(node, with: meshAnchor)
        } else if let planeAnchor = anchor as? ARPlaneAnchor {
            if isPlaneOcclusionEnabled {
                updatePlaneOcclusion(node, for: planeAnchor)
            }
            if isShowPlaneGrid {
                updatePlaneGrid(on: node, for: planeAnchor)
            }
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        // ARKit gộp plane thì anchor nhỏ bị xoá; nếu đó là mặt sàn đang vẽ lưới
        // thì nhường chỗ cho anchor còn lại nhận lưới ở lần cập nhật tới.
        guard let planeAnchor = anchor as? ARPlaneAnchor,
              planeAnchor.identifier == groundPlaneAnchorId else { return }
        groundPlaneAnchorId = nil
        groundPlaneArea = 0
        groundPlaneWorldY = nil
        pushGroundPlaneFade()
    }

    // MARK: - Mesh Logic

    private func handleMeshUpdate(_ node: SCNNode, with anchor: ARMeshAnchor) {
        node.simdTransform = anchor.transform
        let now = CACurrentMediaTime()
        let lastUpdate = lastMeshUpdateTimes[anchor.identifier] ?? 0
        guard now - lastUpdate > meshUpdateInterval else { return }
        let currentCount = anchor.geometry.vertices.count
        let lastCount = meshVertexCounts[anchor.identifier] ?? 0
        if lastCount > 0 && abs(currentCount - lastCount) < 5 { return }
        lastMeshUpdateTimes[anchor.identifier] = now
        meshVertexCounts[anchor.identifier] = currentCount
        updateMeshNode(node, with: anchor)
    }

    private func updateMeshNode(_ node: SCNNode, with anchor: ARMeshAnchor) {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            let geometry = SCNGeometry.from(meshAnchor: anchor)
            let material = self.isShowMeshWireframe ? self.sharedWireframeMaterial : self.sharedOcclusionMaterial
            geometry.materials = [material]
            DispatchQueue.main.async {
                // Occlusion có thể đã bị tắt trong lúc geometry đang được dựng ở
                // background thread. Vẫn phải cho qua khi đang ở chế độ wireframe
                // (ManualCalibration) — chế độ này hiển thị mesh dù occlusion tắt.
                guard self.isAROcclusion || self.isShowMeshWireframe else { return }

                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0

                node.geometry = geometry
                if self.isShowMeshWireframe {
                    node.renderingOrder = 0
                    node.castsShadow = false
                    node.isHidden = false
                } else {
                    self.applyOcclusionSettings(to: node)
                }

                SCNTransaction.commit()
            }
        }
    }

    // MARK: - Plane Logic
    private func addPlaneOcclusion(to node: SCNNode, for anchor: ARPlaneAnchor) {
        let plane = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        plane.materials = [sharedOcclusionMaterial]
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.name = "PlaneOcclusionNode"
        planeNode.eulerAngles.x = -.pi / 2
        applyOcclusionSettings(to: planeNode)
        
        node.addChildNode(planeNode)
    }

    private func updatePlaneOcclusion(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        guard let planeNode = node.childNode(withName: "PlaneOcclusionNode", recursively: false),
              let plane = planeNode.geometry as? SCNPlane else { return }
        
        plane.width = CGFloat(anchor.extent.x)
        plane.height = CGFloat(anchor.extent.z)
        planeNode.simdPosition = anchor.center
    }

    // MARK: - Plane Grid Logic

    /// Thêm mới hoặc cập nhật lưới ô vuông cho mặt phẳng vừa được phát hiện.
    ///
    /// Chỉ mặt sàn lớn nhất được vẽ lưới: các plane anchor của cùng một mặt sàn
    /// chồng lấn nhau nhưng lệch nhau cả hướng lẫn độ cao, vẽ hết thì các lưới
    /// xếp lệch lên nhau trông như bị nhân đôi.
    private func updatePlaneGrid(on node: SCNNode, for anchor: ARPlaneAnchor) {
        let gridNode = node.childNode(withName: PlaneGridNode.nodeName, recursively: false) as? PlaneGridNode

        guard PlaneGridNode.canDisplay(for: anchor), isGroundPlane(anchor) else {
            gridNode?.removeFromParentNode()
            return
        }

        updateGroundPlaneWorldY(anchorNode: node, anchor: anchor)

        if let gridNode = gridNode {
            gridNode.update(with: anchor)
        } else {
            node.addChildNode(PlaneGridNode(anchor: anchor))
        }
    }

    /// Cập nhật độ cao world-space của mặt sàn đang bám, bỏ qua các thay đổi
    /// li tí (xem `groundPlaneWorldYThreshold`).
    private func updateGroundPlaneWorldY(anchorNode: SCNNode, anchor: ARPlaneAnchor) {
        let worldY = anchorNode.simdConvertPosition(anchor.center, to: nil).y
        if let current = groundPlaneWorldY,
           abs(worldY - current) < ViewARContext.groundPlaneWorldYThreshold {
            return
        }
        groundPlaneWorldY = worldY
        pushGroundPlaneFade()
    }

    /// Đẩy trạng thái độ cao sàn xuống hai chỗ tự làm nhạt phần nằm dưới mặt
    /// sàn: shader Metal của point cloud, và shader modifier gắn trên material
    /// của model design (xem `BelowGroundFade`). Cả hai đọc cùng một
    /// `groundPlaneWorldY` nên ranh giới trùng nhau.
    ///
    /// Đây là điểm đẩy duy nhất, được gọi ở mọi chỗ `groundPlaneWorldY` đổi —
    /// kể cả khi bị xoá về nil lúc tắt switch Ground grid hoặc lúc ARKit gộp
    /// mất anchor đang bám — nên hiệu ứng tự bám theo switch mà không cần thêm
    /// chỗ gọi nào.
    private func pushGroundPlaneFade() {
        BelowGroundFade.update(ifcMaterials, groundPlaneY: groundPlaneWorldY)

        // Point cloud: no-op nếu chưa có project — được gọi lại ngay sau khi
        // project được gán để không mất trạng thái đã biết trước đó.
        guard let program = project?.program else { return }
        program.hasGroundPlane = groundPlaneWorldY != nil
        if let y = groundPlaneWorldY {
            program.groundPlaneY = y
        }
    }

    /// Anchor này có phải mặt sàn đang được chọn để vẽ lưới hay không.
    ///
    /// Mặt sàn đã chọn được giữ nguyên cho tới khi có anchor rộng hơn hẳn (20%),
    /// để lưới không nhảy qua lại giữa các anchor có diện tích xấp xỉ nhau.
    private func isGroundPlane(_ anchor: ARPlaneAnchor) -> Bool {
        let area = anchor.extent.x * anchor.extent.z
        
        if groundPlaneAnchorId == anchor.identifier {
            groundPlaneArea = area
            return true
        }
        
        guard groundPlaneAnchorId == nil || area > groundPlaneArea * 1.2 else { return false }
        
        // Mặt sàn mới rộng hơn: bỏ lưới của mặt cũ trước khi chuyển sang. Phải
        // xoá đồng bộ ngay trên render thread, vì bản bất đồng bộ có thể chạy
        // sau khi lưới mới đã được thêm và xoá luôn cả lưới mới.
        removePlaneGridNodes()
        groundPlaneAnchorId = anchor.identifier
        groundPlaneArea = area
        return true
    }

    /// Xoá toàn bộ lưới sàn đang có trong scene.
    ///
    /// Cần gọi khi session được chạy lại với `.removeExistingAnchors` (mở màn
    /// calibration): các plane anchor cũ không còn nhưng node lưới của chúng vẫn
    /// nằm lại trong scene ở vị trí đã đóng băng. Lưới sẽ được dựng lại từ các
    /// callback `didAdd`/`didUpdate` của những anchor mới.
    func removePlaneGrids() {
        groundPlaneAnchorId = nil
        groundPlaneArea = 0
        groundPlaneWorldY = nil
        pushGroundPlaneFade()
        DispatchQueue.main.async { [weak self] in
            self?.removePlaneGridNodes()
        }
    }

    private func removePlaneGridNodes() {
        arSceneView?.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name == PlaneGridNode.nodeName {
                node.removeFromParentNode()
            }
        }
    }

    // MARK: - Helpers
    private func applyOcclusionSettings(to node: SCNNode) {
        // Đảm bảo vật thể luôn ẩn và được vẽ trước các vật thể ảo khác
        node.renderingOrder = -10
        node.castsShadow = false
        node.isHidden = false

        if node.geometry?.firstMaterial != sharedOcclusionMaterial {
            node.geometry?.materials = [sharedOcclusionMaterial]
        }
    }

}

// MARK: - Manual Calibration

extension ViewARContext {

    /// Model dùng cho panel P1/P2 và cho bản clone preview của màn calibration.
    func makeCalibrationModelNode() -> SCNNode {
        let node = arNode.clone()
        node.childNodes
            .filter { $0.name != nameUSDZNode }
            .forEach { $0.removeFromParentNode() }
        // arNode carries the live AR placement (position/rotation/addtionalScale).
        // The panel picker and the calibration math both assume the canonical,
        // untransformed model frame — without this reset, P1 is picked in a
        // shifted/scaled frame that no longer lines up with CP1.
        node.transform = SCNMatrix4Identity
        return node
    }

}

// MARK: - Plane Placement
extension ViewARContext {

    /// Returns a snapped position on the given horizontal plane.
    /// - If current X,Z is within the plane's bounding rectangle, only Y is adjusted.
    /// - Otherwise the full X,Z,Y is moved to the plane's world-space center.
    /// `ARPlaneAnchor.center` is in LOCAL anchor space; callers must convert to world space before passing.
    static func snapPositionToPlane(
        currentPosition: SIMD3<Float>,
        planeWorldY: Float,
        planeCenterWorld: SIMD3<Float>,
        planeHalfExtentX: Float,
        planeHalfExtentZ: Float
    ) -> SIMD3<Float> {
        let withinX = abs(currentPosition.x - planeCenterWorld.x) <= planeHalfExtentX
        let withinZ = abs(currentPosition.z - planeCenterWorld.z) <= planeHalfExtentZ
        if withinX && withinZ {
            return SIMD3<Float>(currentPosition.x, planeWorldY, currentPosition.z)
        } else {
            return SIMD3<Float>(planeCenterWorld.x, planeWorldY, planeCenterWorld.z)
        }
    }

    /// Returns the largest horizontal plane anchor from the given array, or nil if none exist.
    static func bestHorizontalPlane(from anchors: [ARAnchor]) -> ARPlaneAnchor? {
        return anchors
            .compactMap { $0 as? ARPlaneAnchor }
            .filter { $0.alignment == .horizontal }
            .max(by: { $0.extent.x * $0.extent.z < $1.extent.x * $1.extent.z })
    }

    /// Places `arNode` on the best detected horizontal plane.
    /// Y is offset so the bounding-box bottom (not the node origin) sits on the plane surface.
    /// No-op if no horizontal plane has been detected yet (BR-2).
    private func placeArNodeOnHorizontalPlane() {
        // Lưới sàn cũng bật plane detection, nhưng chỉ những chế độ vốn đã dùng
        // plane từ trước mới được phép dịch chuyển model
        guard isEnablePlaneDetection || isPlaneOcclusionEnabled else { return }
        guard let anchors = arSceneView?.session.currentFrame?.anchors else { return }
        guard let plane = ViewARContext.bestHorizontalPlane(from: Array(anchors)) else { return }
        // plane.center is in local anchor space; multiply by transform to get world space
        let localCenter = simd_float4(plane.center.x, plane.center.y, plane.center.z, 1)
        let worldCenter = plane.transform * localCenter
        let planeCenterWorld = SIMD3<Float>(worldCenter.x, worldCenter.y, worldCenter.z)
        let planeWorldY = worldCenter.y

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Offset node origin so bounding-box bottom rests on the plane surface.
            // boundingBox is in local space; multiply by world scale to get world-space offset.
            let (bbMin, _) = self.arNode.boundingBox
            let bottomOffset = bbMin.y * self.arNode.simdScale.y
            let targetY = planeWorldY - bottomOffset

            let newPosition = ViewARContext.snapPositionToPlane(
                currentPosition: SIMD3<Float>(self.arNode.simdPosition.x, targetY, self.arNode.simdPosition.z),
                planeWorldY: targetY,
                planeCenterWorld: planeCenterWorld,
                planeHalfExtentX: plane.extent.x / 2,
                planeHalfExtentZ: plane.extent.z / 2
            )
            self.arNode.simdPosition = newPosition
//            self.highlightPlane(plane)
        }
    }

    /// Highlights the selected plane with a semi-transparent cyan overlay, then fades it out after 3 s.
    private func highlightPlane(_ anchor: ARPlaneAnchor) {
        guard let anchorNode = arSceneView?.node(for: anchor) else { return }

        anchorNode.childNode(withName: "PlaneHighlightNode", recursively: false)?.removeFromParentNode()

        let geometry = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.cyan.withAlphaComponent(0.35)
        material.isDoubleSided = true
        material.lightingModel = .constant
        geometry.materials = [material]

        let highlightNode = SCNNode(geometry: geometry)
        highlightNode.name = "PlaneHighlightNode"
        highlightNode.eulerAngles.x = -.pi / 2
        highlightNode.simdPosition = anchor.center
        anchorNode.addChildNode(highlightNode)

//        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak anchorNode] in
//            anchorNode?.childNode(withName: "PlaneHighlightNode", recursively: false)?.removeFromParentNode()
//        }
    }
}
