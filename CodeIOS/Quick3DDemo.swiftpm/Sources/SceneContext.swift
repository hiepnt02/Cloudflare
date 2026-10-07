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
//        └─ pointCloudNode   ← SCNNode(geometry từ MTLBuffer)
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
        loadPointCloud()
    }

    /// Giả lập SfmProject + BVHReader: sinh dữ liệu ở thread nền, về main tạo node.
    private func loadPointCloud() {
        delegate?.demo(status: "Đang tạo point cloud…")
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let device = MTLCreateSystemDefaultDevice(),
                  let cloud = MetalPointCloud.makeTerrain(device: device) else {
                await MainActor.run { self?.delegate?.demo(status: "Không tạo được Metal device / buffer") }
                return
            }
            await MainActor.run {
                guard let self else { return }
                // = SCNViewARContext.downloadDidFinish(... pointcloud:)
                let node = SCNBuilder.createNode(cloud, program: self.program)
                self.program.pointCount = Int32(cloud.count)
                self.arNode.addChildNode(node)
                self.pointCloudNode = node
                self.pointCloud = cloud
                self.delegate?.demo(didLoad: cloud.count)
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
    }

    func recenter() { /* chỉ bản AR override */ }
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
