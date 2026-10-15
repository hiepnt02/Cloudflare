//
//  BridgeAR.swift
//  Quick3DDemo
//
//  AR 6 bậc tự do không cần iPhone: app Android "ARBridge" (thư mục AndroidARBridge/) chạy ARCore,
//  mỗi frame gửi qua WebSocket  ws://<ip-android>:8090  MỘT message nhị phân:
//
//    [4 byte big-endian: độ dài header N][N byte JSON header][ảnh JPEG]
//    header = {"t": ns, "tracking": "TRACKING", "pose": [16 float, column-major],
//              "fx","fy","cx","cy","w","h", "hit": [x,y,z] | null, "planes": n}
//
//  pose = camera → world của ARCore = đúng thứ ARKit đưa trong frame.camera.transform:
//  world Y lên theo trọng lực, mét, camera nhìn theo −Z — trùng quy ước SceneKit, gán thẳng.
//  Ảnh và pose đi chung một message nên không bị lệch trễ như IP Webcam + Sensor Server.
//

import SwiftUI
import SceneKit
import simd

struct BridgeFrame {
    let image: UIImage
    let cameraTransform: simd_float4x4
    let fy: Float
    let width: Float
    let height: Float
    let tracking: String                  // TRACKING | PAUSED | STOPPED
    let hit: SIMD3<Float>?                // tia giữa màn hình chạm mặt phẳng ngang ARCore
    let planes: Int

    var isTracking: Bool { tracking == "TRACKING" }
    var aspect: CGFloat { CGFloat(width / height) }
    /// FOV dọc của camera Android — SCNCamera phải khớp thì model mới đứng yên trên ảnh.
    var verticalFOV: CGFloat { CGFloat(2 * atan(height / 2 / fy) * 180 / .pi) }
}

// MARK: - Stream

@MainActor
final class ARBridgeStream: ObservableObject {

    @Published private(set) var frame: BridgeFrame?
    @Published private(set) var status = "Chưa kết nối"
    @Published private(set) var fps: Double = 0

    private var task: Task<Void, Never>?
    private let session = URLSession(configuration: .ephemeral)

    /// `baseURL` dạng "ws://192.168.0.106:8090" (chấp nhận "http://…" hoặc chỉ "ip:port").
    func start(baseURL: String) {
        stop()
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var comps = URLComponents(string: trimmed.contains("://") ? trimmed : "ws://" + trimmed),
              comps.host != nil
        else { status = "URL không hợp lệ: \(trimmed)"; return }
        comps.scheme = comps.scheme == "https" || comps.scheme == "wss" ? "wss" : "ws"
        guard let url = comps.url else { status = "URL không hợp lệ"; return }

        let session = self.session
        task = Task { [weak self] in
            while !Task.isCancelled {
                let ws = session.webSocketTask(with: url)
                ws.maximumMessageSize = 16 << 20          // mặc định 1 MB, JPEG lớn sẽ bị cắt
                self?.status = "Đang kết nối \(url.host ?? ""):\(url.port ?? 0)…"
                ws.resume()

                var frames = 0
                var window = Date()
                do {
                    while !Task.isCancelled, self != nil {
                        let message = try await ws.receive()
                        guard case .data(let data) = message else { continue }
                        // Giải JPEG ngoài main thread
                        let parsed = await Task.detached(priority: .userInitiated) { Self.parse(data) }.value
                        guard let parsed else { self?.status = "Message sai định dạng"; continue }
                        self?.frame = parsed
                        frames += 1
                        let dt = Date().timeIntervalSince(window)
                        if dt >= 1 {
                            self?.fps = Double(frames) / dt
                            self?.status = "\(Int(parsed.width))×\(Int(parsed.height)) · \(parsed.tracking)"
                            frames = 0
                            window = Date()
                        }
                    }
                } catch {
                    if Task.isCancelled { break }
                    self?.status = "Mất kết nối (\(error.localizedDescription)) — thử lại…"
                    self?.fps = 0
                }
                ws.cancel(with: .goingAway, reason: nil)
                if Task.isCancelled || self == nil { break }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        fps = 0
        status = "Đã dừng"
    }

    nonisolated static func parse(_ data: Data) -> BridgeFrame? {
        let bytes = [UInt8](data)
        guard bytes.count > 4 else { return nil }
        let n = Int(bytes[0]) << 24 | Int(bytes[1]) << 16 | Int(bytes[2]) << 8 | Int(bytes[3])
        guard n > 0, bytes.count > 4 + n,
              let json = try? JSONSerialization.jsonObject(with: Data(bytes[4 ..< 4 + n])) as? [String: Any],
              let pose = json["pose"] as? [Double], pose.count == 16,
              let image = UIImage(data: Data(bytes[(4 + n)...]))?.preparingForDisplay()
        else { return nil }

        let m = pose.map { Float($0) }
        let transform = simd_float4x4(columns: (
            SIMD4(m[0], m[1], m[2], m[3]),
            SIMD4(m[4], m[5], m[6], m[7]),
            SIMD4(m[8], m[9], m[10], m[11]),
            SIMD4(m[12], m[13], m[14], m[15])
        ))
        func number(_ key: String) -> Float { Float(json[key] as? Double ?? 0) }
        let hit = (json["hit"] as? [Double]).flatMap { $0.count == 3 ? SIMD3(Float($0[0]), Float($0[1]), Float($0[2])) : nil }

        let fy = number("fy"), w = number("w"), h = number("h")
        guard fy > 0, w > 0, h > 0 else { return nil }
        return BridgeFrame(image: image, cameraTransform: transform, fy: fy, width: w, height: h,
                           tracking: json["tracking"] as? String ?? "?",
                           hit: hit, planes: json["planes"] as? Int ?? 0)
    }
}

// MARK: - Context: = DemoARContext, chỉ khác nguồn pose (ARCore qua mạng thay vì ARKit)

final class BridgeARContext: DemoSceneContext {

    private weak var scnView: SCNView?
    private let cameraNode = SCNNode()
    private var needsPlacement = true

    func setup(_ view: SCNView) {
        scnView = view
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = .black
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.showsStatistics = true

        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = 200
        cameraNode.camera?.projectionDirection = .vertical
        scene.rootNode.addChildNode(cameraNode)
        view.pointOfView = cameraNode

        attach(to: scene)
        arNode.isHidden = true                      // hiện khi tracking ổn và đã đặt
    }

    /// = ARSCNView mỗi frame: ảnh làm nền + camera SceneKit theo pose của frame đó.
    func apply(_ frame: BridgeFrame?) {
        guard let frame, let scene = scnView?.scene else { return }
        scene.background.contents = frame.image
        cameraNode.camera?.fieldOfView = frame.verticalFOV
        guard frame.isTracking else { return }      // mất tracking: giữ pose cũ
        cameraNode.simdTransform = frame.cameraTransform
        if needsPlacement {
            needsPlacement = false
            place(using: frame)
        }
    }

    /// Có mặt phẳng ARCore ở giữa màn → đặt lên đó; chưa có → tạm 1.5 m trước mặt, thấp hơn 1.2 m.
    private func place(using frame: BridgeFrame) {
        let t = frame.cameraTransform
        let cameraPos = t.columns.3.xyz
        let forward = -t.columns.2.xyz
        var flat = SIMD3(forward.x, 0, forward.z)
        flat = simd_length(flat) < 0.01 ? SIMD3(0, 0, -1) : simd_normalize(flat)

        let fallback: SIMD3<Float> = cameraPos + flat * 1.5 + SIMD3<Float>(0, -1.2, 0)
        let p = frame.hit ?? fallback
        arNode.simdPosition = p
        // Mặt trước model (+Z) quay về phía người xem
        arNode.simdOrientation = simd_quatf(angle: atan2(-flat.x, -flat.z), axis: SIMD3(0, 1, 0))
        arNode.isHidden = false
        delegate?.demo(didPlaceAt: p)
        delegate?.demo(status: frame.hit != nil
                       ? "Đã đặt lên mặt phẳng ARCore"
                       : "Chưa thấy mặt phẳng — đặt tạm; quét sàn/bàn rồi bấm Đặt lại")
    }

    override func recenter() { needsPlacement = true }
}

// MARK: - Cầu SwiftUI → UIKit

struct BridgeARView: UIViewRepresentable {
    let context: BridgeARContext
    @ObservedObject var stream: ARBridgeStream       // frame mới → updateUIView

    func makeCoordinator() -> BridgeARContext { context }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        context.coordinator.setup(view)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.apply(stream.frame)
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: BridgeARContext) {
        coordinator.clear()
        uiView.scene = nil
    }
}

// MARK: - Màn hình

struct BridgeARScreen: View {
    @AppStorage("bridge.url") private var url = "ws://192.168.0.106:8090"

    @State private var context = BridgeARContext()
    @StateObject private var model = DemoStatus()
    @StateObject private var stream = ARBridgeStream()
    @State private var showPanel = false

    var body: some View {
        ZStack {
            // View phải cùng tỉ lệ với ảnh Android, nếu không nền bị kéo giãn và lệch với model
            BridgeARView(context: context, stream: stream)
                .aspectRatio(stream.frame?.aspect ?? 4.0 / 3.0, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .ignoresSafeArea()

            ControlPanel(perform: { context.perform($0) }, showRecenter: true, model: model, isPresented: $showPanel) {
                VStack(spacing: 6) {
                    HStack {
                        TextField("ws://ip:8090", text: $url)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Kết nối") { stream.start(baseURL: url) }
                            .buttonStyle(.borderedProminent)
                        Button("Dừng") { stream.stop() }
                            .buttonStyle(.bordered)
                    }
                    Text("ARBridge: \(stream.status) · \(Int(stream.fps)) fps · mặt phẳng: \(stream.frame?.planes ?? 0)"
                         + (stream.frame?.hit != nil ? " · tâm màn đang trúng mặt phẳng" : ""))
                        .font(.caption2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .overlay(alignment: .topTrailing) { PanelToggleButton(isPresented: $showPanel) }
        .navigationTitle("AR 6DoF (ARCore)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            context.delegate = model
            stream.start(baseURL: url)
        }
        .onDisappear { stream.stop() }
    }
}
