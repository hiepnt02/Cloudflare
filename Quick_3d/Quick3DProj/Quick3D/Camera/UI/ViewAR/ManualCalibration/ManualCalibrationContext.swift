//
//  ManualCalibrationContext.swift
//  Quick3D
//

import Foundation
import ARKit
import SceneKit
import simd

/// Context của màn manual calibration. Kế thừa ViewARContext để dùng lại camera
/// layer của ViewAR (mesh wireframe, raycast, arNode) và sở hữu thêm state riêng
/// của luồng chọn điểm cùng các node marker/preview.
///
/// `delegate` (ViewARDelegate) thuộc lớp cha nên callback của luồng calibration
/// đi qua `calibrationDelegate`.
class ManualCalibrationContext: ViewARContext, @unchecked Sendable {

    var calibrationDelegate: ManualCalibrationDelegate?

    private(set) var selection = CalibrationSelection()

    /// Context của ViewAR đang chạy phía dưới — cho dùng chung ARSession để giữ
    /// world tracking, và khôi phục lại config khi màn calibration đóng.
    private weak var parentContext: ViewARContext?

    /// Model của panel P1/P2. Preview trong AR clone lại đúng node này — panel và
    /// preview phải chung một local frame.
    private var previewSource: SCNNode?

    private var modelScale: Float = 1

    private var dot1Node: SCNNode?
    private var dot2Node: SCNNode?
    private var previewNode: SCNNode?

    override func perform(_ event: any Event) {
        guard event is ManualCalibrationEvent else {
            super.perform(event)
            return
        }
        handle(event) { [weak self] in
            guard let self = self, let e = event as? ManualCalibrationEvent else { return }
            Task { @MainActor in
                e.call(self)
            }
        }
    }

    // MARK: - Lifecycle

    func begin(parent: ViewARContext, model: SCNNode) {
        parentContext = parent
        previewSource = model
        modelScale = parent.addtionalScale
        addtionalScale = parent.addtionalScale
        isAROcclusion = false
        isShowMeshWireframe = true
        // Màn calibration đã có mesh wireframe, thêm lưới sàn chỉ gây rối
        isShowPlaneGrid = false
        // Session bên dưới sắp chạy lại với .removeExistingAnchors nên
        // lưới của các anchor cũ phải xoá, tránh sót lại ở vị trí cũ
        parent.removePlaneGrids()

        if let session = parent.arSceneView?.session,
           let config = session.configuration as? ARWorldTrackingConfiguration {
            arSceneView?.session = session
            // Màn calibration không dùng occlusion: phải bỏ person
            // segmentation/sceneDepth kế thừa từ ViewAR — hai ARSCNView cùng
            // render một session có matting sẽ crash khi isAROcclusion đang bật.
            // end() sẽ khôi phục occlusion khi đóng màn này.
            config.frameSemantics = []
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                config.sceneReconstruction = .mesh
            }
            config.planeDetection = [.horizontal, .vertical]
            session.run(config, options: [.removeExistingAnchors])
        } else {
            start()
        }
        // QUICK-1049: điểm đặc trưng gây rối khung hình ở màn hiệu chỉnh, ẩn đi.
        arSceneView?.debugOptions = []
    }

    func end() {
        clearDots()
        removePreview()
        // Detach session dùng chung trước clear() — ARSCNView khi bị dismantle sẽ
        // pause session của nó, không được pause session đang chạy của parent.
        arSceneView?.session = ARSession()
        clear()
        // Session config đã bị đổi (tắt occlusion, bật wireframe) trong lúc màn
        // calibration mở — khôi phục theo setting của ViewAR.
        parentContext?.reconfigureWithoutReset()
        parentContext = nil
        previewSource = nil
    }

    // MARK: - Flow

    func select(_ step: CalibrationStep) {
        switch step {
        case .selectingModelPoint1:
            selection.selectModelRefPoint()
        case .selectingModelPoint2:
            selection.selectModelDirPoint()
        case .selectingCameraPoint1:
            selection.selectCameraRefPoint()
        case .selectingCameraPoint2:
            selection.selectCameraDirPoint()
        }
        if step.isCameraTapActive {
            refreshDots()
        }
        notify()
    }

    func tapModel(at position: SIMD3<Float>) {
        selection.tapModel(at: position)
        notify()
    }

    /// Tap không trúng mesh đã scan thì bỏ qua (raycast trả nil).
    func tapCamera(at screenPoint: CGPoint) {
        guard selection.step.isCameraTapActive else { return }
        guard let worldPosition = raycast(from: screenPoint) else { return }
        selection.tapCamera(at: worldPosition)
        refreshDots()
        refreshPreview()
        notify()
    }

    func confirmModelPoints() {
        guard selection.isNextEnabled else { return }
        selection.confirmNext()
        clearDots()
        removePreview()
        notify()
    }

    /// Mở lại panel là bắt đầu lại toàn bộ việc chọn điểm — dot và preview trong
    /// AR thuộc về các điểm vừa bị bỏ nên cũng xoá theo.
    func reopenModelSelection() {
        selection.reopenModelSelection()
        clearDots()
        removePreview()
        notify()
    }

    /// Quay lại bước chọn điểm trên model, giữ P1/P2 và bỏ CP1/CP2 (QUICK-1024 AC-6).
    /// CP1/CP2 bị bỏ nên dot và preview trong AR — vốn thuộc về hai điểm đó — cũng
    /// phải dọn theo, nếu không sẽ còn marker mồ côi lơ lửng trong scene.
    func returnToModelSelection() {
        selection.returnToModelSelection()
        clearDots()
        removePreview()
        notify()
    }

    func reset() {
        selection = CalibrationSelection()
        clearDots()
        removePreview()
        notify()
    }

    func togglePreview() {
        selection.togglePreview()
        refreshPreview()
        notify()
    }

    func confirm() {
        guard let pairs = selection.calibrationPointPairs else { return }
        do {
            let result = try CalibrationCalculator.calculate(
                point1: pairs.point1, point2: pairs.point2, modelScale: modelScale)
            clearDots()
            removePreview()
            calibrationDelegate?.calibration(didComplete: result)
        } catch {
            calibrationDelegate?.calibration(didFail: error)
        }
    }

    private func notify() {
        calibrationDelegate?.calibration(didUpdate: selection)
    }

    // MARK: - Scene

    private func refreshDots() {
        updateDots(point1: selection.cp1, color1: selection.cp1DotColor,
                   point2: selection.cp2, color2: selection.cp2DotColor)
    }

    private func updateDots(point1: SIMD3<Float>?, color1: UIColor,
                            point2: SIMD3<Float>?, color2: UIColor) {
        var dotRadius: CGFloat = 0.01
        if let p1 = point1, let p2 = point2 {
            dotRadius = CGFloat(CalibrationVectorArrow.dotRadius(boundingRadius: simd_distance(p1, p2)))
        }
        dot1Node?.removeFromParentNode()
        dot1Node = point1.map { placeDot(at: $0, color: color1, radius: dotRadius) }
        dot2Node?.removeFromParentNode()
        dot2Node = point2.map { placeDot(at: $0, color: color2, radius: dotRadius) }
        updateArrow(point1: point1, point2: point2)
    }

    private func clearDots() {
        removeDots()
        dot1Node = nil
        dot2Node = nil
        updateArrow(point1: nil, point2: nil)
    }

    /// Đủ hai điểm thì vẽ mũi tên chỉ hướng point1 → point2 trong scene AR. Tỉ lệ
    /// mũi tên theo khoảng cách hai điểm (tham chiếu kích thước duy nhất có ý
    /// nghĩa trong world space). Truyền nil là xoá mũi tên.
    private func updateArrow(point1: SIMD3<Float>?, point2: SIMD3<Float>?) {
        guard let rootNode = arSceneView?.scene.rootNode else { return }
        guard let p1 = point1, let p2 = point2 else {
            CalibrationVectorArrow.update(in: rootNode, from: SCNVector3Zero, through: nil, boundingRadius: 1)
            return
        }
        CalibrationVectorArrow.update(
            in: rootNode,
            from: SCNVector3(p1),
            through: SCNVector3(p2),
            boundingRadius: simd_distance(p1, p2)
        )
    }

    /// Preview theo trạng thái nút toggle và chỉ được đặt lại vị trí khi có tap
    /// camera mới (không đổi khi chỉ chọn lại điểm).
    private func refreshPreview() {
        guard selection.isPreviewVisible, let p1 = selection.p1, let cp1 = selection.cp1 else {
            removePreview()
            return
        }
        let point1 = CalibrationPoint(modelPosition: p1, worldPosition: cp1)
        var point2: CalibrationPoint? = nil
        if let p2 = selection.p2, let cp2 = selection.cp2 {
            point2 = CalibrationPoint(modelPosition: p2, worldPosition: cp2)
        }
        showPreview(point1: point1, point2: point2)
    }

    private func showPreview(point1: CalibrationPoint, point2: CalibrationPoint?) {
        removePreview()
        guard let source = previewSource,
              let rootNode = arSceneView?.scene.rootNode else { return }
        let preview = source.clone()
        preview.simdScale = SIMD3<Float>(modelScale, modelScale, modelScale)

        if let point2 = point2,
           let result = try? CalibrationCalculator.calculate(
            point1: point1, point2: point2, modelScale: modelScale) {
            preview.simdPosition = result.position
            preview.simdEulerAngles = result.eulerAngles
        } else {
            preview.simdPosition = point1.worldPosition - point1.modelPosition * modelScale
            preview.simdEulerAngles = .zero
        }

        rootNode.addChildNode(preview)
        previewNode = preview
    }

    private func removePreview() {
        previewNode?.removeFromParentNode()
        previewNode = nil
    }

    // MARK: - Scene helpers

    /// Đặt một sphere marker trong scene AR tại world position, trả về node để
    /// caller giữ và xoá sau.
    @discardableResult
    private func placeDot(at worldPosition: SIMD3<Float>, color: UIColor, radius: CGFloat = 0.01) -> SCNNode {
        let sphere = SCNSphere(radius: radius)
        sphere.materials = [CalibrationVectorArrow.alwaysVisibleMaterial(color: color)]

        let dotNode = SCNNode(geometry: sphere)
        dotNode.name = CalibrationNames.cameraDot
        dotNode.simdPosition = worldPosition
        dotNode.renderingOrder = CalibrationVectorArrow.dotRenderingOrder

        DispatchQueue.main.async { [weak self] in
            self?.arSceneView?.scene.rootNode.addChildNode(dotNode)
        }
        return dotNode
    }

    private func removeDots() {
        DispatchQueue.main.async { [weak self] in
            self?.arSceneView?.scene.rootNode.enumerateChildNodes { (node, _) in
                if node.name == CalibrationNames.cameraDot {
                    node.removeFromParentNode()
                }
            }
        }
    }

    /// Raycast từ điểm trên màn hình, trả về world position trúng đầu tiên hoặc nil.
    /// Ưu tiên existingPlaneGeometry (chính xác) rồi hạ dần xuống estimatedPlane để
    /// tap vẫn ăn khi plane chưa được detect đầy đủ.
    private func raycast(from point: CGPoint) -> SIMD3<Float>? {
        guard let sceneView = arSceneView else { return nil }
        let targets: [(ARRaycastQuery.Target, ARRaycastQuery.TargetAlignment)] = [
            (.existingPlaneGeometry, .any),
            (.existingPlaneInfinite, .horizontal),
            (.existingPlaneInfinite, .vertical),
            (.estimatedPlane, .horizontal),
            (.estimatedPlane, .any)
        ]
        for (target, alignment) in targets {
            guard let query = sceneView.raycastQuery(from: point,
                                                     allowing: target,
                                                     alignment: alignment) else { continue }
            if let hit = sceneView.session.raycast(query).first {
                return SIMD3<Float>(hit.worldTransform.columns.3.x,
                                    hit.worldTransform.columns.3.y,
                                    hit.worldTransform.columns.3.z)
            }
        }
        return nil
    }

}
