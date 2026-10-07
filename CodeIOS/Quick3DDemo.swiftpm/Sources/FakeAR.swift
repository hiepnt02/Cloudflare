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

final class FakeARContext: DemoSceneContext {

    private weak var scnView: SCNView?

    func setup(_ view: SCNView) {
        scnView = view
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = .black
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.showsStatistics = true

        // Camera đặt như người cầm máy: cao 0.9 m, nhìn xuống model cách 1.8 m
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = 100
        cameraNode.camera?.fieldOfView = 60
        cameraNode.position = SCNVector3(0, 0.9, 1.8)
        cameraNode.look(at: SCNVector3(0, 0.1, 0))
        scene.rootNode.addChildNode(cameraNode)
        view.pointOfView = cameraNode

        attach(to: scene)
    }

    /// = ARSCNView tự làm mỗi frame với ảnh camera. SceneKit scale ảnh phủ kín nền.
    func updateBackground(_ image: UIImage?) {
        guard let scene = scnView?.scene else { return }
        scene.background.contents = image
    }
}

// MARK: - Cầu SwiftUI → UIKit, đẩy ảnh mới mỗi khi stream phát

struct FakeARView: UIViewRepresentable {
    let context: FakeARContext
    @ObservedObject var stream: IPCameraStream   // đổi image → SwiftUI gọi updateUIView

    func makeCoordinator() -> FakeARContext { context }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        context.coordinator.setup(view)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.updateBackground(stream.image)
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: FakeARContext) {
        coordinator.clear()
        uiView.scene = nil
    }
}

// MARK: - Màn hình

struct FakeARScreen: View {
    @AppStorage("ipcam.baseURL") private var baseURL = "http://192.168.0.106:8080"

    @State private var context = FakeARContext()
    @StateObject private var model = DemoStatus()
    @StateObject private var stream = IPCameraStream()

    var body: some View {
        ZStack(alignment: .bottom) {
            FakeARView(context: context, stream: stream)
                .ignoresSafeArea()

            VStack(spacing: 6) {
                HStack {
                    TextField("http://ip:8080", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Kết nối") { stream.start(baseURL: baseURL) }
                        .buttonStyle(.borderedProminent)
                    Button("Dừng") { stream.stop() }
                        .buttonStyle(.bordered)
                }
                Text("\(stream.status) · \(Int(stream.fps)) fps")
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Model không bám cảnh khi xoay điện thoại Android — không có tracking. Xoay model bằng ngón tay.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)
            .padding(.bottom, 150)   // chừa chỗ cho ControlPanel bên dưới

            ControlPanel(perform: { context.perform($0) }, showRecenter: false, model: model)
        }
        .navigationTitle("Fake AR (IP Webcam)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            context.delegate = model
            stream.start(baseURL: baseURL)
        }
        .onDisappear { stream.stop() }
    }
}
