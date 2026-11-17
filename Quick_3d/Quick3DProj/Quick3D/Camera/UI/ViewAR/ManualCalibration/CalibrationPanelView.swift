//
//  CalibrationPanelView.swift
//  Quick3D
//

import SwiftUI
import SceneKit

struct CalibrationPanelView: View {

    @EnvironmentObject private var userManager: UserManager

    @Binding var context: ManualCalibrationContext

    let selection: CalibrationSelection

    let model: SCNNode

    /// Hướng dẫn của bước hiện tại, do màn hình cha quyết định nội dung.
    let instructionText: String

    /// Đổi giá trị này để viewport trả camera về góc nhìn ban đầu (không dựng lại SCNView).
    @State private var cameraResetToken = UUID()

    var body: some View {
        if selection.step.panelMode == .expanded {
            expandedBody
        } else {
            collapsedBody
        }
    }

    // MARK: - Expanded mode (P1/P2 selection screen)

    private var expandedBody: some View {
        ZStack(alignment: .bottom) {
            modelViewport
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom, spacing: 12) {
                    resetButton
                    Spacer()
                    expandedButtonColumn
                }
                expandedInstructionOverlay
            }
            .padding(.horizontal, 12)
            .padding(.bottom, Self.expandedOverlayBottomInset)
        }
    }

    private var expandedButtonColumn: some View {
        let lang = userManager.userLanguage
        return VStack(spacing: 12) {
            actionButton(
                title: "CALIBRATION_REFERENCE_POINT".localized(lang),
                isEnabled: true,
                isActive: selection.step == .selectingModelPoint1,
                action: { context.perform(ManualCalibrationSelectStepEvent(.selectingModelPoint1)) }
            )
            actionButton(
                title: "CALIBRATION_DIRECTION_POINT".localized(lang),
                isEnabled: selection.isDirPointEnabled,
                isActive: selection.step == .selectingModelPoint2,
                action: { context.perform(ManualCalibrationSelectStepEvent(.selectingModelPoint2)) }
            )
            actionButton(
                title: "NEXT".localized(lang),
                isEnabled: selection.isNextEnabled,
                action: { context.perform(ManualCalibrationConfirmModelEvent()) }
            )
        }
        .frame(width: Self.expandedButtonColumnWidth)
    }

    private var resetButton: some View {
        Button(action: {
            cameraResetToken = UUID()
            context.perform(ManualCalibrationResetEvent())
        }) {
            Image(systemName: "arrow.counterclockwise")
                .foregroundColor(.white)
                .padding(8)
                .background(imperialBlue.opacity(0.7))
                .clipShape(Circle())
        }
    }

    // MARK: - Collapsed mode (reference viewport while picking CP1/CP2)

    private var collapsedBody: some View {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        return GeometryReader { geo in
            HStack(spacing: 0) {
                modelViewport
                    .frame(width: geo.size.width * 0.8)

                collapsedButtonStack
                    .frame(width: geo.size.width * 0.2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Self.panelBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .frame(
            width: isIPad ? Self.iPadPanelWidth : nil,
            height: panelHeight
        )
    }

    // MARK: - Sub-views

    private var modelViewport: some View {
        SCNCalibrationModelPicker(context: $context, node: model, selection: selection,
                                  cameraResetToken: cameraResetToken)
    }

    /// Ở bước chọn điểm trên model, viewport đen chiếm trọn màn hình nên hướng dẫn
    /// phải nằm bên trong nó, ở dải đáy dưới hàng nút.
    private var expandedInstructionOverlay: some View {
        calibrationInstructionText(instructionText)
            .calibrationInstructionStyle()
    }

    private var collapsedButtonStack: some View {
        let lang = userManager.userLanguage
        // QUICK-1049: thao tác đi từ trên xuống, nên Quay lại đứng đầu và Hoàn tất đứng cuối.
        return VStack(spacing: 12) {
            actionButton(
                title: "CALIBRATION_BACK".localized(lang),
                isEnabled: true,
                action: { context.perform(ManualCalibrationBackEvent()) }
            )
            actionButton(
                title: "CALIBRATION_REFERENCE_POINT".localized(lang),
                isEnabled: true,
                isActive: selection.step == .selectingCameraPoint1,
                action: { context.perform(ManualCalibrationSelectStepEvent(.selectingCameraPoint1)) }
            )
            actionButton(
                title: "CALIBRATION_DIRECTION_POINT".localized(lang),
                isEnabled: selection.isCameraDirEnabled,
                isActive: selection.step == .selectingCameraPoint2,
                action: { context.perform(ManualCalibrationSelectStepEvent(.selectingCameraPoint2)) }
            )
            actionButton(
                title: "CALIBRATION_PREVIEW".localized(lang),
                isEnabled: selection.isPreviewEnabled,
                isActive: selection.isPreviewVisible,
                action: { context.perform(ManualCalibrationTogglePreviewEvent()) }
            )
            actionButton(
                title: "CALIBRATION_COMPLETE".localized(lang),
                isEnabled: selection.isCameraNextEnabled,
                action: { context.perform(ManualCalibrationConfirmEvent()) }
            )
        }
        .padding(.leading, 8)
    }

    private func actionButton(
        title: String,
        isEnabled: Bool,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Self.activeButtonColor : Self.inactiveButtonColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white, lineWidth: 1)
                )
        }
        .disabled(!isEnabled)
    }

    // MARK: - Colors

    // QUICK-1049: thống nhất với màu trạng thái được chọn của RTK/GPS.
    private static var activeButtonColor: Color { electricBlue }
    private static var inactiveButtonColor: Color { Color(UIColor(red: 32/255, green: 51/255, blue: 102/255, alpha: 117/255)) }
    private static var panelBackgroundColor: Color { Color(UIColor(red: 32/255, green: 51/255, blue: 102/255, alpha: 117/255)) }

    // MARK: - Layout

    static var iPadPanelWidth: CGFloat { 500 }
    static var expandedButtonColumnWidth: CGFloat { 140 }
    /// Viewport ở expanded mode ignoresSafeArea nên lớp overlay phải tự chừa home
    /// indicator; 16 là lề đáy dùng chung với collapsed mode.
    static var expandedOverlayBottomInset: CGFloat { 16 + UIScreen.bottomSafeArea }

    private var panelHeight: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone
            ? UIScreen.main.bounds.height * 0.30
            : 280
    }
}

// MARK: - Viewport camera framing

/// QUICK-832: the expanded viewport must show the whole model on screen — SceneKit's
/// implicit default camera does not guarantee this for wide models on portrait phones.
enum CalibrationViewportCamera {

    static let verticalFovDegrees: Float = 60
    /// Breathing room around the model so it does not touch the screen edges.
    private static let margin: Float = 1.15

    /// Camera distance from the model's bounding-sphere center so the WHOLE sphere
    /// fits inside the view — constrained by the narrower of the two fov axes
    /// (horizontal on a portrait phone, hence "model wider than the screen" without this).
    static func distance(toFit radius: Float, verticalFovDegrees: Float, aspect: Float) -> Float {
        let safeRadius = max(radius, 0.001)
        let safeAspect = max(aspect, 0.1)
        let halfVertical = verticalFovDegrees * .pi / 360
        let halfHorizontal = atan(tan(halfVertical) * safeAspect)
        let halfNarrowest = min(halfVertical, halfHorizontal)
        return safeRadius / sin(halfNarrowest) * margin
    }
}

// MARK: - SCNView wrapper

/// Viewport 3D của panel: hiển thị model và nhận tap chọn P1/P2.
struct SCNCalibrationModelPicker: UIViewRepresentable {

    @Binding var context: ManualCalibrationContext

    let node: SCNNode

    let selection: CalibrationSelection

    let cameraResetToken: UUID

    private var onTap: (SCNVector3) -> Void {
        { [context] position in
            context.perform(ManualCalibrationTapModelEvent(SIMD3<Float>(position)))
        }
    }

    /// Collapsed mode: tap ở đâu cũng mở lại panel (AC-13), không hit-test model.
    private var onPlainTap: (() -> Void)? {
        guard selection.step.panelMode == .collapsed else { return nil }
        return { [context] in context.perform(ManualCalibrationReopenEvent()) }
    }

    private var p1Pos: SCNVector3? { selection.p1.map(SCNVector3.init) }
    private var p1Color: UIColor { selection.p1DotColor }
    private var p2Pos: SCNVector3? { selection.p2.map(SCNVector3.init) }
    private var p2Color: UIColor { selection.p2DotColor }
    private var vectorOrigin: SCNVector3? { p1Pos }
    private var vectorThrough: SCNVector3? { p2Pos }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .black
        scnView.antialiasingMode = .multisampling2X
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true

        // An SCNNode can only live in ONE scene. The expanded and collapsed viewports
        // are separate SCNViews, and SwiftUI's create/teardown order while switching
        // modes is unpredictable — sharing the original node lets the outgoing view
        // detach it from the incoming one. Each viewport therefore renders its own
        // clone (shares geometry/materials, so it is cheap).
        let displayNode = node.clone()
        displayNode.simdPosition = .zero
        displayNode.simdEulerAngles = .zero
        // P1/P2 are reported in the canonical unscaled model frame. The
        // calibration preview applies `scale` explicitly in the AR world —
        // without this reset, taps here would be in whatever scale the live
        // AR model currently has, mismatching CP1/CP2 (raycast points are
        // always real-world/unscaled).
        displayNode.simdScale = SIMD3<Float>(repeating: 1)

        let scene = SCNScene()
        scene.rootNode.addChildNode(displayNode)
        scnView.scene = scene

        // Frame after the first layout pass — the view has no bounds (aspect) yet here.
        let coordinator = context.coordinator
        coordinator.cameraResetToken = cameraResetToken
        DispatchQueue.main.async {
            frameCamera(in: scnView, around: displayNode, coordinator: coordinator)
        }

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tap)
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onPlainTap = onPlainTap
        restoreCameraIfNeeded(in: uiView, coordinator: context.coordinator)
        updateDot(in: uiView, named: CalibrationNames.panelDotP1, at: p1Pos, color: p1Color)
        updateDot(in: uiView, named: CalibrationNames.panelDotP2, at: p2Pos, color: p2Color)
        updateVector(in: uiView)
    }

    /// Places an explicit camera far enough back that the whole model fits on screen.
    /// `allowsCameraControl` starts orbiting from this pose. Runs async after the first
    /// layout pass so the view's real aspect ratio is known.
    private func frameCamera(in scnView: SCNView, around displayNode: SCNNode, coordinator: Coordinator) {
        guard let scene = scnView.scene else { return }
        let (center, radius) = displayNode.boundingSphere

        let camera = SCNCamera()
        camera.fieldOfView = CGFloat(CalibrationViewportCamera.verticalFovDegrees)
        camera.projectionDirection = .vertical
        camera.zNear = Double(max(radius, 0.001)) * 0.01
        camera.zFar = Double(max(radius, 0.001)) * 100

        let aspect = scnView.bounds.height > 0
            ? Float(scnView.bounds.width / scnView.bounds.height)
            : 1
        let distance = CalibrationViewportCamera.distance(
            toFit: Float(radius),
            verticalFovDegrees: CalibrationViewportCamera.verticalFovDegrees,
            aspect: aspect
        )

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(center.x, center.y, center.z + distance)
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.look(at: center)
        scnView.pointOfView = cameraNode
        coordinator.initialCameraTransform = cameraNode.transform
    }

    /// Reset chỉ đưa camera về pose lúc frame xong. Dựng lại cả SCNView (đổi `.id`) làm
    /// viewport đen và camera chưa được đặt trong vài khung hình đầu — chính là cái nháy.
    private func restoreCameraIfNeeded(in scnView: SCNView, coordinator: Coordinator) {
        guard coordinator.cameraResetToken != cameraResetToken else { return }
        coordinator.cameraResetToken = cameraResetToken
        guard let initial = coordinator.initialCameraTransform else { return }
        scnView.defaultCameraController.stopInertia()
        scnView.pointOfView?.transform = initial
    }

    private func updateVector(in scnView: SCNView) {
        guard let rootNode = scnView.scene?.rootNode else { return }
        guard let origin = vectorOrigin else {
            CalibrationVectorArrow.update(in: rootNode, from: SCNVector3Zero, through: nil, boundingRadius: 1)
            return
        }
        // BR-9: extension length scales with the MODEL's size — measure the model node
        // itself, not the scene root, whose bounding sphere also contains the dots and
        // the previously drawn arrow (feeding the arrow's own length back into itself).
        let (_, modelRadius) = node.boundingSphere
        CalibrationVectorArrow.update(in: rootNode, from: origin, through: vectorThrough, boundingRadius: Float(modelRadius))
    }

    private func updateDot(in scnView: SCNView, named name: String, at pos: SCNVector3?, color: UIColor) {
        scnView.scene?.rootNode.childNode(withName: name, recursively: false)?.removeFromParentNode()
        guard let pos = pos else { return }
        let (_, sceneRadius) = scnView.scene?.rootNode.boundingSphere ?? (SCNVector3Zero, 1.0)
        let dotRadius = CGFloat(max(0.02, Float(sceneRadius) * 0.025))
        let sphere = SCNSphere(radius: dotRadius)
        sphere.materials = [CalibrationVectorArrow.alwaysVisibleMaterial(color: color)]
        let dotNode = SCNNode(geometry: sphere)
        dotNode.name = name
        dotNode.position = pos
        dotNode.renderingOrder = CalibrationVectorArrow.dotRenderingOrder
        dotNode.constraints = [Self.constantScreenSizeConstraint(in: scnView, sceneRadius: Float(sceneRadius))]
        scnView.scene?.rootNode.addChildNode(dotNode)
    }

    /// Scales the dot with camera distance and field of view so its on-screen size
    /// does not grow while zooming (pinch may dolly the camera or narrow the fov).
    private static func constantScreenSizeConstraint(in scnView: SCNView, sceneRadius: Float) -> SCNConstraint {
        let referenceDistance = max(sceneRadius * 2.0, 0.001)
        let referenceFovFactor = tanf(30.0 * .pi / 180.0)
        return SCNTransformConstraint(inWorldSpace: true) { [weak scnView] _, transform in
            guard let pov = scnView?.pointOfView else { return transform }
            let dotPosition = simd_float3(transform.m41, transform.m42, transform.m43)
            let distance = simd_distance(pov.simdWorldPosition, dotPosition)
            let fovDegrees = Float(pov.camera?.fieldOfView ?? 60.0)
            let fovFactor = tanf(fovDegrees * .pi / 360.0) / referenceFovFactor
            let scale = min(max(distance / referenceDistance * fovFactor, 0.01), 1.0)
            var scaled = SCNMatrix4MakeScale(scale, scale, scale)
            scaled.m41 = transform.m41
            scaled.m42 = transform.m42
            scaled.m43 = transform.m43
            return scaled
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onPlainTap: onPlainTap)
    }

    final class Coordinator: NSObject {
        var onTap: (SCNVector3) -> Void
        var onPlainTap: (() -> Void)?
        var cameraResetToken = UUID()
        var initialCameraTransform: SCNMatrix4?
        init(onTap: @escaping (SCNVector3) -> Void, onPlainTap: (() -> Void)?) {
            self.onTap = onTap
            self.onPlainTap = onPlainTap
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            // Collapsed mode: any tap re-expands the panel — no hit-test needed.
            if let onPlainTap = onPlainTap {
                onPlainTap()
                return
            }
            guard let scnView = gesture.view as? SCNView else { return }
            let point = gesture.location(in: scnView)
            let hits = scnView.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
            if let hit = hits.first(where: { !Self.isOverlayNode($0.node) }) {
                onTap(hit.worldCoordinates)
            }
        }

        /// Dots and the direction arrow float over the model — taps must fall through
        /// them onto the model surface itself.
        private static func isOverlayNode(_ node: SCNNode) -> Bool {
            var current: SCNNode? = node
            while let candidate = current {
                if candidate.name?.hasPrefix("dot_") == true || candidate.name == CalibrationVectorArrow.nodeName {
                    return true
                }
                current = candidate.parent
            }
            return false
        }
    }
}

// MARK: - Instruction style

/// Cụm phân biệt ngữ cảnh ở đầu câu hướng dẫn phải in đậm: tiếng Nhật bọc trong
/// 【】, các ngôn ngữ còn lại là tiền tố trước dấu `:`.
///
/// Không dùng markdown: CommonMark không in đậm được `**【モデル上】**で…` vì dấu đóng
/// nằm giữa punctuation và chữ, nên `**` sẽ lộ nguyên ra màn hình.
/// Chuỗi chưa cập nhật (không có 【】 lẫn dấu `:` ở đầu) hiển thị nguyên văn, không in đậm.
func calibrationInstructionText(_ raw: String) -> Text {
    guard let emphasisEnd = calibrationEmphasisEnd(in: raw) else {
        return Text(raw)
    }
    var emphasized = AttributedString(String(raw[raw.startIndex..<emphasisEnd]))
    emphasized.inlinePresentationIntent = .stronglyEmphasized
    return Text(emphasized + AttributedString(String(raw[emphasisEnd...])))
}

/// Dấu `:` chỉ được coi là hết cụm nhấn khi nằm gần đầu câu — tránh in đậm nửa câu
/// nếu một bản dịch chưa cập nhật có dấu `:` ở giữa.
private let calibrationEmphasisMaxOffset = 40

private func calibrationEmphasisEnd(in raw: String) -> String.Index? {
    if raw.hasPrefix("【"), let close = raw.firstIndex(of: "】") {
        return raw.index(after: close)
    }
    if let colon = raw.firstIndex(of: ":"),
       raw.distance(from: raw.startIndex, to: colon) < calibrationEmphasisMaxOffset {
        return raw.index(after: colon)
    }
    return nil
}

extension View {

    func calibrationInstructionStyle() -> some View {
        self
            .font(.system(size: 14))
            .foregroundColor(.white)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .glassBackground()
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
            .frame(
                width: UIDevice.current.userInterfaceIdiom == .pad
                    ? CalibrationPanelView.iPadPanelWidth
                    : nil,
                alignment: .leading
            )
    }
}
