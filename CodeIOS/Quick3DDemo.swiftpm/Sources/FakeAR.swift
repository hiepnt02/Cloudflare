//
//  FakeAR.swift
//  Quick3DDemo
//
//  "AR giả" chạy được trên Simulator: ARSCNView thật = (frame camera làm background)
//  + (SceneKit vẽ node lên trên) + (ARKit tính pose camera). Ở đây giữ 2 phần đầu:
//    background  ← ảnh từ IP Webcam Android (CameraStream)
//    node        ← cùng DemoSceneContext/SCNBuilder/Shaders như màn AR thật
//  và BỎ phần pose: camera xoay bằng tay (allowsCameraControl), không bám cảnh thật.
//

import SwiftUI
import SceneKit

// MARK: - Context: giống Demo3DContext, thêm background từ stream

/// Điện thoại Android đang cầm theo chiều nào (ảnh stream được IP Webcam xoay theo).
enum PhoneHolding: String, CaseIterable, Identifiable {
    case portrait = "Dọc"
    case landscapeLeft = "Ngang ←"     // đỉnh máy quay sang trái
    case landscapeRight = "Ngang →"    // đỉnh máy quay sang phải
    var id: String { rawValue }

    /// Hệ camera SceneKit (X phải, Y lên, nhìn theo −Z) → hệ thiết bị Android (X phải, Y lên khi dọc, Z ra khỏi màn hình)
    var cameraToDevice: simd_quatf {
        switch self {
        case .portrait:       return simd_quatf(angle: 0,        axis: SIMD3(0, 0, 1))
        case .landscapeLeft:  return simd_quatf(angle: -.pi / 2, axis: SIMD3(0, 0, 1))
        case .landscapeRight: return simd_quatf(angle:  .pi / 2, axis: SIMD3(0, 0, 1))
        }
    }
}

final class FakeARContext: DemoSceneContext {

    private weak var scnView: SCNView?
    private let cameraNode = SCNNode()

    /// Hệ thế giới Android ENU (X Đông, Y Bắc, Z lên) → hệ thế giới SceneKit (X Đông, Y lên, Z Nam):
    /// (x, y, z) → (x, z, −y)  = xoay −90° quanh trục X.
    private let androidWorldToScene = simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0))

    var holding: PhoneHolding = .landscapeLeft
    private(set) var trackingEnabled = false
    private var needsPlacement = true

    /// Hướng ngang (XZ) từ mắt tới model, chốt lúc "Đặt lại trước mặt"; khoảng cách đổi được.
    private var placementDirection = SIMD3<Float>(0, 0, -1)
    private(set) var distance: Float = 1.5
    private let eyeHeight: Float = 0.9
    private var pinchStartDistance: Float = 1.5

    /// Gọi từ UI khi khoảng cách đổi (slider/pinch) để đồng bộ hiển thị.
    var onDistanceChanged: ((Float) -> Void)?

    func setup(_ view: SCNView) {
        scnView = view
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = .black
        view.autoenablesDefaultLighting = false
        view.showsStatistics = true

        // Pinch = tiến/lùi (thay cho tracking dịch chuyển). Chỉ có tác dụng khi đang bám gyro.
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)

        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = 100
        cameraNode.camera?.fieldOfView = 60
        scene.rootNode.addChildNode(cameraNode)
        view.pointOfView = cameraNode

        attach(to: scene)
        setTracking(false)
    }

    /// = ARSCNView tự làm mỗi frame với ảnh camera. SceneKit scale ảnh phủ kín nền.
    func updateBackground(_ image: UIImage?) {
        guard let scene = scnView?.scene else { return }
        scene.background.contents = image
    }

    /// Bật: camera đứng yên tại gốc, chỉ xoay theo cảm biến; tắt: xoay bằng tay như màn 3D.
    func setTracking(_ enabled: Bool) {
        trackingEnabled = enabled
        guard let view = scnView else { return }
        if enabled {
            view.allowsCameraControl = false
            cameraNode.simdPosition = SIMD3(0, 0, 0)        // mắt người = gốc thế giới
            cameraNode.simdOrientation = simd_quatf(angle: 0, axis: SIMD3(0, 1, 0))
            view.pointOfView = cameraNode
            needsPlacement = true
        } else {
            view.allowsCameraControl = true
            cameraNode.position = SCNVector3(0, 0.9, 1.8)
            cameraNode.look(at: SCNVector3(0, 0.1, 0))
            arNode.simdPosition = .zero
        }
    }

    /// Mỗi mẫu cảm biến: q_scene = M · q_android · D⁻¹
    /// (device→ENU từ Android, đổi sang hệ SceneKit, rồi bù chiều cầm máy).
    func updateOrientation(_ deviceToAndroidWorld: simd_quatf) {
        guard trackingEnabled else { return }
        let q = androidWorldToScene * deviceToAndroidWorld * holding.cameraToDevice
        cameraNode.simdOrientation = simd_normalize(q)
        if needsPlacement {
            needsPlacement = false
            placeInFront()
        }
    }

    /// Chốt hướng nhìn hiện tại rồi đặt model cách `distance` m, thấp hơn mắt 0.9 m (≈ mặt bàn/đất).
    /// Giống DemoARContext.place(using:) — chỉ khác nguồn pose.
    private func placeInFront() {
        let forward = cameraNode.simdWorldFront                   // −Z của camera trong world
        var flat = SIMD3(forward.x, 0, forward.z)
        if simd_length(flat) < 0.01 { flat = SIMD3(0, 0, -1) }
        placementDirection = simd_normalize(flat)
        applyPlacement()
    }

    /// Vị trí model = mắt + hướng đã chốt × khoảng cách − chiều cao mắt.
    private func applyPlacement() {
        let p = cameraNode.simdPosition + placementDirection * distance + SIMD3(0, -eyeHeight, 0)
        arNode.simdPosition = p
        delegate?.demo(didPlaceAt: p)
    }

    override func recenter() {
        if trackingEnabled { placeInFront() } else { arNode.simdPosition = .zero }
    }

    override func setDistance(_ meters: Float) {
        distance = min(max(meters, 0.3), 8)
        if trackingEnabled { applyPlacement() }
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        guard trackingEnabled else { return }     // chưa bám gyro thì SceneKit tự xử lý pinch
        switch g.state {
        case .began:
            pinchStartDistance = distance
        case .changed:
            // Kéo hai ngón ra (scale > 1) = tiến lại gần → khoảng cách giảm
            setDistance(pinchStartDistance / Float(g.scale))
            onDistanceChanged?(distance)
        default:
            break
        }
    }
}

// MARK: - Cầu SwiftUI → UIKit, đẩy ảnh mới mỗi khi stream phát

struct FakeARView: UIViewRepresentable {
    let context: FakeARContext
    @ObservedObject var stream: IPCameraStream           // đổi image → SwiftUI gọi updateUIView
    @ObservedObject var sensors: PhoneOrientationStream  // đổi orientation → cũng gọi updateUIView

    func makeCoordinator() -> FakeARContext { context }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        context.coordinator.setup(view)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.updateBackground(stream.image)
        context.coordinator.updateOrientation(sensors.orientation)
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: FakeARContext) {
        coordinator.clear()
        uiView.scene = nil
    }
}

// MARK: - Màn hình

struct FakeARScreen: View {
    @AppStorage("ipcam.baseURL") private var baseURL = "http://192.168.0.106:8080"

    @AppStorage("ipcam.holding") private var holdingRaw = PhoneHolding.landscapeLeft.rawValue
    // Sensor Server: WebSocket port (đổi trong Settings của nó thành 8082 để không trùng IP Webcam 8080).
    // 8081 là trang HTTP của Sensor Server, KHÔNG phải port ws.
    @AppStorage("sensor.baseURL") private var sensorURL = "ws://192.168.0.106:8082"

    @State private var context = FakeARContext()
    @StateObject private var model = DemoStatus()
    @StateObject private var stream = IPCameraStream()
    @StateObject private var sensors = PhoneOrientationStream()
    @State private var tracking = false
    @State private var distance: Double = 1.5

    private var holding: Binding<PhoneHolding> {
        Binding(
            get: { PhoneHolding(rawValue: holdingRaw) ?? .landscapeLeft },
            set: { holdingRaw = $0.rawValue; context.holding = $0 }
        )
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            FakeARView(context: context, stream: stream, sensors: sensors)
                .ignoresSafeArea()

            // Một panel duy nhất, thu/mở bằng nút ⌄ ở góc; phần riêng của màn này ở "extra"
            ControlPanel(perform: { context.perform($0) }, showRecenter: true, model: model) {
                VStack(spacing: 6) {
                    HStack {
                        TextField("http://ip:8080", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Kết nối") { connect() }
                            .buttonStyle(.borderedProminent)
                        Button("Dừng") { stream.stop(); sensors.stop() }
                            .buttonStyle(.bordered)
                    }
                    Text("Ảnh: \(stream.status) · \(Int(stream.fps)) fps")
                        .font(.caption2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Text("Sensor").font(.caption).frame(width: 48, alignment: .leading)
                        TextField("ws://ip:8081", text: $sensorURL)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    HStack {
                        Toggle("Bám theo gyro điện thoại", isOn: $tracking)
                            .onChange(of: tracking) { on in
                                context.setTracking(on)
                                if on { sensors.start(baseURL: sensorURL) } else { sensors.stop() }
                            }
                        Picker("Cầm máy", selection: holding) {
                            ForEach(PhoneHolding.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 220)
                    }
                    Text(tracking
                         ? "Cảm biến: \(sensors.status) · \(Int(sensors.rate)) Hz — xoay máy: model đứng yên; đi lại: chưa bám (không có dịch chuyển)"
                         : "Chưa bám: xoay model bằng ngón tay. Bật toggle để nhận rotation_vector từ app Sensor Server.")
                        .font(.caption2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if tracking {
                        HStack {
                            Text("Khoảng cách").frame(width: 90, alignment: .leading)
                            Slider(value: $distance, in: 0.3...8)
                                .onChange(of: distance) { v in context.perform(ChangeDistanceEvent(Float(v))) }
                            Text(String(format: "%.1f m", distance)).frame(width: 48)
                        }
                        Text("Giả đi tới/lùi: kéo slider hoặc pinch 2 ngón trên hình (Simulator: giữ ⌥ + kéo chuột).")
                            .font(.caption2).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .navigationTitle("Fake AR (IP Webcam)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            context.delegate = model
            context.holding = holding.wrappedValue
            let distanceBinding = $distance                              // pinch → cập nhật slider
            context.onDistanceChanged = { d in distanceBinding.wrappedValue = Double(d) }
            connect()
        }
        .onDisappear { stream.stop(); sensors.stop() }
    }

    private func connect() {
        stream.start(baseURL: baseURL)
        if tracking { sensors.start(baseURL: sensorURL) }
    }
}
