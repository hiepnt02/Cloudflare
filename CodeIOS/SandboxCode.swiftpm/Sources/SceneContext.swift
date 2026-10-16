//
//  SceneContext.swift
//  Quick3DDemo
//
//  Tầng ④ — "Viewer.ts" của iOS: giữ scene graph, nhận event, báo delegate.
//  Trong project thật: Camera/UI/ViewAR/SCNViewARContext.swift (+ CameraContextTemplate)
//
//  Cây node (giống project):
//    rootNode
//    ├─ cameraNode (chỉ bản 3D; bản AR camera là ARKit)
//    ├─ lightNode
//    └─ arNode               ← gốc của model, dời cả cụm
//        ├─ pointCloudNode   ← SCNNode(geometry từ MTLBuffer)
//        └─ modelRoot        ← model cụ thể (USDZ/SCN/OBJ) + đèn riêng cho nó
//

import SceneKit
import ARKit

/// Kênh 3D → UI. Trong project thật: ViewARDelegate (~15 hàm).
protocol DemoDelegate: AnyObject {
    func demo(didLoad pointCount: Int)
    func demo(didPlaceAt position: SIMD3<Float>)
    func demo(status: String)
}

// MARK: - Phần dùng chung cho cả 3D lẫn AR

class DemoSceneContext: NSObject, DemoEventContext {

    weak var delegate: DemoDelegate?

    let arNode = SCNNode()
    private(set) var pointCloudNode: SCNNode?
    let program = PointProgram()
    private(set) var pointCloud: MetalPointCloud?

    let modelRoot = SCNNode()
    private var model: ModelLoader.Loaded?
    private var modelSize: Float? = 1           // cạnh dài nhất (m); nil = kích thước gốc
    private var modelRequest = 0

    // Lọc trùng event — giống CameraContextTemplate.handle()
    private let queue = DispatchQueue(label: "demo.context.events")
    private var lastEventId = -1

    func perform(_ event: DemoEvent) {
        queue.async { [weak self] in
            guard let self, event.id != self.lastEventId else { return }
            self.lastEventId = event.id
            // Mọi thứ đụng SCNNode phải ở main thread
            Task { @MainActor in event.call(self) }
        }
    }

    /// Gắn cây node vào scene và bắt đầu "tải" dữ liệu.
    func attach(to scene: SCNScene) {
        arNode.name = "arNode"
        scene.rootNode.addChildNode(arNode)
        modelRoot.name = "modelRoot"
        arNode.addChildNode(modelRoot)
        addModelLights()
        loadPointCloud(.none)
    }

    /// Point cloud tự tô màu trong shader, còn model PBR cần đèn.
    private func addModelLights() {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 400
        modelRoot.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 1000
        sun.simdEulerAngles = SIMD3(-.pi / 3, .pi / 4, 0)
        modelRoot.addChildNode(sun)
    }

    private struct CloudError: LocalizedError {
        let errorDescription: String?
        init(_ text: String) { errorDescription = text }
    }
    private var pointCloudRequest = 0
    private var pointCloudExtent: SIMD3<Float>?     // chỉ có khi nạp từ PLY
    private var pointCloudSize: Float?              // nil = giữ toạ độ gốc

    func setPointCloudSize(_ meters: Float?) {
        pointCloudSize = meters
        applyPointCloudSize()
    }

    /// Point size trong shader tính theo pixel màn hình nên scale node không làm điểm to/nhỏ.
    private func applyPointCloudSize() {
        guard let node = pointCloudNode else { return }
        var scale: Float = 1
        if let size = pointCloudSize, let e = pointCloudExtent, e.max() > 0 { scale = size / e.max() }
        node.simdScale = SIMD3(repeating: scale)
    }

    /// Giả lập SfmProject + BVHReader: đọc/sinh dữ liệu ở thread nền, về main tạo node.
    /// `.none`/`.sample` = địa hình sinh bằng code; `.url` = file .ply (thường hoặc Gaussian splatting).
    func loadPointCloud(_ source: ModelSource) {
        pointCloudNode?.removeFromParentNode()
        pointCloudNode = nil
        pointCloud = nil
        pointCloudRequest += 1
        let request = pointCloudRequest
        delegate?.demo(status: "Đang tạo point cloud…")

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                guard let device = MTLCreateSystemDefaultDevice() else { throw CloudError("Không có Metal device") }
                let cloud: MetalPointCloud?
                var info = "Địa hình mẫu"
                var extent: SIMD3<Float>?
                switch source {
                case .none, .sample:
                    cloud = MetalPointCloud.makeTerrain(device: device)
                case .url(let url):
                    let local = url.isFileURL ? url : try await ModelLoader.download(url)
                    let ply = try PLYReader.load(url: local)
                    cloud = MetalPointCloud(device: device, positions: ply.positions, colors: ply.colors)
                    extent = ply.extent
                    let e = ply.extent
                    info = String(format: "%@ %d/%d điểm · %.1f × %.1f × %.1f m",
                                  ply.isGaussianSplat ? "3DGS" : "PLY",
                                  ply.positions.count, ply.totalVertices, e.x, e.y, e.z)
                }
                guard let cloud else { throw CloudError("Không tạo được MTLBuffer") }
                await MainActor.run {
                    // Bỏ kết quả cũ nếu trong lúc đọc đã có lệnh khác
                    guard let self, request == self.pointCloudRequest else { return }
                    // = SCNViewARContext.downloadDidFinish(... pointcloud:)
                    let node = SCNBuilder.createNode(cloud, program: self.program)
                    self.program.pointCount = Int32(cloud.count)
                    self.arNode.addChildNode(node)
                    self.pointCloudNode = node
                    self.pointCloud = cloud
                    self.pointCloudExtent = extent
                    self.applyPointCloudSize()
                    self.delegate?.demo(didLoad: cloud.count)
                    self.delegate?.demo(status: info)
                }
            } catch {
                await MainActor.run { self?.delegate?.demo(status: "Lỗi PLY: \(error.localizedDescription)") }
            }
        }
    }

    func clear() {
        delegate = nil
        DispatchQueue.main.async {
            self.arNode.enumerateChildNodes { node, _ in node.removeFromParentNode() }
            self.arNode.removeFromParentNode()
        }
    }

    // MARK: DemoEventContext — mỗi event cuối cùng chỉ là sửa property node/program

    func setPointSize(_ size: Float) {
        program.pointSize = size
    }

    func setPointCloudVisible(_ visible: Bool) {
        pointCloudNode?.isHidden = !visible
    }

    func setOpacity(_ opacity: Float) {
        program.opacity = opacity
        pointCloudNode?.isHidden = opacity == 0
        modelRoot.opacity = CGFloat(opacity)
    }

    func loadModel(_ source: ModelSource) {
        model?.node.removeFromParentNode()
        model = nil
        modelRequest += 1
        let request = modelRequest
        if case .none = source {
            delegate?.demo(status: "Đã bỏ model")
            return
        }
        delegate?.demo(status: "Đang tải model…")
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                guard let loaded = try await ModelLoader.load(source) else { return }
                await MainActor.run {
                    // Bỏ kết quả cũ nếu trong lúc tải đã có lệnh model khác
                    guard let self, request == self.modelRequest else { return }
                    self.modelRoot.addChildNode(loaded.node)
                    self.model = loaded
                    self.applyModelSize()
                    let e = loaded.extent
                    self.delegate?.demo(status: String(format: "Model gốc %.2f × %.2f × %.2f m", e.x, e.y, e.z))
                }
            } catch {
                await MainActor.run { self?.delegate?.demo(status: "Lỗi model: \(error.localizedDescription)") }
            }
        }
    }

    func setModelSize(_ meters: Float?) {
        modelSize = meters
        applyModelSize()
    }

    private func applyModelSize() {
        guard let model else { return }
        let scale = modelSize.map { $0 / model.extent.max() } ?? 1
        model.node.simdScale = SIMD3(repeating: scale)
    }

    func recenter() { /* chỉ bản AR override */ }

    func setDistance(_ meters: Float) { /* chỉ Fake AR override */ }
}

// MARK: - Bản 3D: SCNView, camera của SceneKit, xoay bằng tay

final class Demo3DContext: DemoSceneContext {

    func setup(_ view: SCNView) {
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = .black
        view.allowsCameraControl = true          // = OrbitControls
        view.autoenablesDefaultLighting = false
        view.showsStatistics = true              // FPS góc dưới

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = 100
        cameraNode.position = SCNVector3(0, 1.3, 2.6)
        cameraNode.look(at: SCNVector3(0, 0.2, 0))
        scene.rootNode.addChildNode(cameraNode)
        view.pointOfView = cameraNode

        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .ambient
        scene.rootNode.addChildNode(light)

        attach(to: scene)
    }
}

// MARK: - Bản AR: ARSCNView, camera là camera thật, ta dời arNode

final class DemoARContext: DemoSceneContext, ARSessionDelegate {

    private weak var arView: ARSCNView?
    private var placed = false

    func setup(_ view: ARSCNView) {
        arView = view
        view.session.delegate = self             // nhận ARFrame mỗi frame
        view.automaticallyUpdatesLighting = false
        view.autoenablesDefaultLighting = false
        attach(to: view.scene)
        arNode.isHidden = true                   // hiện khi tracking ổn và đã đặt
    }

    /// = CameraContextTemplate.start() + SCNViewARContext.configuration()
    func start() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity  // trục Y luôn thẳng đứng
        configuration.environmentTexturing = .none
        arView?.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        delegate?.demo(status: "Đang khởi động tracking… di chuyển máy chậm")
    }

    func pause() {
        arView?.session.pause()
    }

    override func clear() {
        arView?.session.delegate = nil
        super.clear()
    }

    override func recenter() {
        placed = false
    }

    // "Render loop" của AR = callback này. Trong project: SCNViewARContext.session(_:didUpdate:)
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard case .normal = frame.camera.trackingState else {
            Task { @MainActor in self.delegate?.demo(status: "Tracking: \(frame.camera.trackingState)") }
            return
        }
        guard !placed else { return }
        placed = true
        place(using: frame)
    }

    /// Project dùng RTK để tính offset; demo đặt model 1.5 m trước mặt, thấp hơn mắt 0.8 m.
    private func place(using frame: ARFrame) {
        let t = frame.camera.transform                  // camera → world
        let cameraPos = t.columns.3.xyz
        let forward = -t.columns.2.xyz                  // trục -Z của camera là hướng nhìn
        var p = cameraPos + simd_normalize(SIMD3(forward.x, 0, forward.z)) * 1.5
        p.y = cameraPos.y - 0.8
        Task { @MainActor in
            self.arNode.simdPosition = p                // = calculateARPosition() gán arNode
            self.arNode.isHidden = false
            self.delegate?.demo(didPlaceAt: p)
        }
    }
}
