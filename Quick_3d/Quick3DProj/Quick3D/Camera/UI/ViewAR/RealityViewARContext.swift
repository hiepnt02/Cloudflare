//
//  RealityViewARContext.swift
//  Quick3D
//
//  Created by HaNST on 14/7/26.
//

import Foundation
import SwiftUI
import simd
import Alamofire
import Combine

import RealityKit
import ARKit
import VigramSDK

@available(iOS 18.0, *)
class RealityViewARContext: CameraContextTemplate<ARView>, CameraContext, ViewAREventContext, @unchecked Sendable {
    
    
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
    
    private var downloadLasTask: Task<Void, Never>?
    
    @AppStorage("isLightOn")
    private var isLightOn: Bool = true
    
    weak var previewContext: ViewARPreviewContext?
    
    let arNode = AnchorEntity(world: matrix_identity_float4x4)
    var axisNode: ModelEntity?
    var lightNode: ModelEntity?
    var ambientNode: ModelEntity?
    var pointCloudNode: ModelEntity?
    var ifcNode: ModelEntity?
    
    var isAROcclusion: Bool = false
    
    required override init() { super.init() }

    var delegate: ViewARDelegate?

    func perform(_ event: ViewAREvent) {
        handle(event) { [weak self] in
            guard let self = self else { return }
            // Đảm bảo event call luôn chạy trên Main Actor nếu nó tác động UI
            Task { @MainActor in
                event.call(self)
            }
        }
    }

    func error(_ error: Error) {
        Task { @MainActor in
            self.delegate?.ar(nil, error: error)
        }
    }
    
    override func setup(_ view: ARView) {
        super.setup(view)
        view.session.delegate = self

        view.scene.addAnchor(arNode)
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
    
    private func configureOcclusionEnabled(_ config: ARWorldTrackingConfiguration) {
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        } else {
            config.planeDetection = [.horizontal, .vertical]
        }
        
//        updateNodesRenderingOrder(to: 100)
    }
    
    private func configureOcclusionDisabled(_ config: ARWorldTrackingConfiguration) {
        config.frameSemantics = []
        config.sceneReconstruction = []
        config.planeDetection = []
//        updateNodesRenderingOrder(to: 0)
    }
    
    override func clear() {
        super.clear()
        downloadLasTask?.cancel()
        downloadLasTask = nil
        
        DispatchQueue.main.async {
            // TODO: clear entity
        }
    }
    
    private func calculateARPosition(position: SIMD3<Float>, location: LocationModel) async {
        guard !isCalculating, let sfmProject = project else { return }
        isCalculating = true
        
        await MainActor.run { delegate?.ar(sfmProject, willCalculate: sfmProject.offset) }
        
        do {
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
                
                self.arPosition = newPos
                self.arEulerAngles = newEuler
                self.arNode.transform.translation = self.arPosition + self.addtionalPosition
                self.arNode.transform.rotation = quaternion(from: self.arEulerAngles + self.addtionalEulerAngles)
                
//                let virtualOrder = 100
//                self.arNode.renderingOrder = virtualOrder
//                self.arNode.enumerateChildNodes { (node, _) in
//                    node.renderingOrder = virtualOrder
//                }
                
                let currentScale = self.addtionalScale
                self.arNode.transform.scale = SIMD3<Float>(currentScale, currentScale, currentScale)
                
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
    
    private func updateARPosition() {
        // TODO: update entity position
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
        
        self.calculateAccuracy = ImageCalculator.calculateAccuracy(matrix: self.arNode.transform.matrix,
                                          offset: sfmProject.offset,
                                          source: filterdHistory.map{$0.coord},
                                          target: filterdHistory.map{$0.offset!})
    }
    
    func cancel() {
        clear()
        project?.cancel()
    }
    
    func updatePointCloudSize(to newSize: CGFloat) {
        project?.program.pointSize = Float(newSize)
    }
    
    func downloadARProject(projectId: String, isAR: Bool) {
        project = SfmProject(projectId: projectId, isAR: isAR)
        isPositionHisttory = true
        var isUpdatedBefore = false

        downloadLasTask = Task(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            await MainActor.run { self.delegate?.ar(self.project, willDownload: projectId) }
            
            self.project?.render(arNode: SCNNode()) { [weak self] pcNode, ifcNode in
                // TODO:
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
                self?.delegate?.ar(self?.project, didDownload: self?.project?.offset ?? .zero )
            } onLasComplete: { [weak self] in
//                self?.pointCloudNode?.renderingOrder = 100
                self?.delegate?.ar(self?.project, didDownloadPointCloud: self?.project?.offset ?? .zero )
            } onLasProgressChanged: { [weak self] progress in
                self?.delegate?.ar(self?.project, onPointCloudProgressChanged: progress)
            } onIfcComplete: { [weak self] layers in
                self?.delegate?.ar(self?.project, didDownloadIFC: layers)
            }
        }
    }
    
    func setOpacity(for node: LayerNode?, opacity: Double) {
        // TODO: implement event
    }
    
    func setVisible(for node: LayerNode?, visible: Bool) {
        // TODO: implement event
    }
    
    func updateARPosition(position: SIMD3<Float>, eulerAngles: SIMD3<Float>, scale: Float) {
        self.addtionalPosition = position
        self.addtionalEulerAngles = eulerAngles
        self.addtionalScale = scale
        // TODO: implement event
    }
    
    func setLightNodeVisible(_ visible: Bool) {
        // TODO: implement event
    }
    
    func toggleOcclusion(isEnabled: Bool) {
        // TODO: implement event
    }
    
    func setPointCloudOpacity(_ opacity: CGFloat) {
        // TODO: implement event
    }
    
    func setPointCloudVisible(_ visible: Bool) {
        // TODO: implement event
    }
    
    func setAxisVisible(_ visible: Bool) {
        // TODO: implement event
    }
    
    func ready() {
        guard !isReady else { return }
        isReady = true
        Task { @MainActor in
            delegate?.ar(project, didStart: isReady)
        }
    }
    
    
    private func quaternion(from euler: SIMD3<Float>) -> simd_quatf {
        let qx = simd_quatf(angle: euler.x, axis: [1, 0, 0])
        let qy = simd_quatf(angle: euler.y, axis: [0, 1, 0])
        let qz = simd_quatf(angle: euler.z, axis: [0, 0, 1])

        return qz * qy * qx
    }
    
    func updateAxisPosition() {
//        previewContext?.updateNode(arNode)
    }
}

@available(iOS 18.0, *)
extension RealityViewARContext: ARSessionDelegate {
    
    func scaleAxis(for camera: ARCamera) {
        if let axis = self.axisNode {
            let axisPos = axis.transform.translation
            let cameraPos = camera.transform.columns.3.xyz
            
            let distance = simd_length(axisPos - cameraPos)
            
            let scaleFactor = max(1, distance * 2)
            
            axis.transform.scale = [scaleFactor, scaleFactor, scaleFactor]
        }
        

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
}
