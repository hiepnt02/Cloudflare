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
    private var lastCloudSource: ModelSource = .none

    // Gaussian splatting: node riêng, SplatRenderer vẽ bằng Metal thuần (quad instanced như web),
    // sắp xếp độ sâu trong SplatCloud
    private(set) var splatCloud: SplatCloud?
    private var splatRenderer: SplatRenderer?
    private var splatMode = true
    private var pointSizeValue: Float = 14

    /// Kết quả đọc ở thread nền, về main mới tạo node
    private enum BuiltCloud {
        case points(MetalPointCloud)
        case splats(SplatCloud)
        var count: Int {
            switch self {
            case .points(let c): return c.count
            case .splats(let c): return c.count
            }
        }
    }

    func setSplatMode(_ on: Bool) {
        splatMode = on
        if case .url = lastCloudSource { loadPointCloud(lastCloudSource) }
    }

    // Đường .gsx: PLY → GSXEncoder (= Lambda gsplat-converter) → cache Caches → GSX.decodeAll → SplatCloud.
    // Không LOD: giải mã cả file rồi lấy mẫu về maxPoints như đường PLY.
    private var gsxMode = true

    func setGSXMode(_ on: Bool) {
        gsxMode = on
        if case .url = lastCloudSource { loadPointCloud(lastCloudSource) }
    }

    /// Hệ gốc GÁN cho PLY raw (chỉ đường .gsx). nil = raw, không đổi. Hệ hiển thị cố định = CRS.displaySystem.
    private var crsCode: String?
    /// Tâm (hệ SceneKit, đã lật) của lần nạp GỐC theo từng file → khi đổi hệ vẫn trừ tâm này,
    /// nên model dịch đúng bằng chênh lệch giữa hai hệ thay vì bị kéo về gốc.
    private var baseCenters: [String: SIMD3<Double>] = [:]

    func setCRS(_ code: String?) {
        crsCode = code
        if case .url = lastCloudSource, gsxMode, splatMode { loadPointCloud(lastCloudSource) }
    }

    /// Caches/<tên>.<size>[.from-to].gsx — lần mở sau không convert lại (xoá app là mất).
    private static func gsxCacheURL(for ply: URL, crs: (from: String, to: String)?) throws -> URL {
        let size = (try? FileManager.default.attributesOfItem(atPath: ply.path)[.size] as? Int) ?? 0
        let caches = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let tag = crs.map { ".\($0.from)-\($0.to)".replacingOccurrences(of: ":", with: "") } ?? ""
        return caches.appendingPathComponent("\(ply.deletingPathExtension().lastPathComponent).\(size)\(tag).gsx")
    }

    /// Lấy .gsx đã cache hoặc convert mới từ PLY (trong RAM, rồi ghi cache). `stats` nil khi dùng cache.
    private static func gsxFromPLY(_ local: URL, crs: (from: String, to: String)?,
                                   status: @escaping (String) -> Void) throws -> (Data, GSXEncoder.Stats?) {
        let cache = try gsxCacheURL(for: local, crs: crs)
        if let cached = try? Data(contentsOf: cache, options: [.alwaysMapped]),
           let m = try? GSX.readMeta(cached), m.header.splatCount > 0 {
            status("Dùng .gsx đã convert trong Caches")
            return (cached, nil)
        }
        status("Đọc PLY…")
        let raw = try PLYReader.loadRaw(url: local)
        status("PLY → GSX: \(raw.count) splat…")
        var params = GSXEncoder.Params()
        params.crs = crs
        let (data, stats) = try GSXEncoder.encode(raw, params: params) { status("PLY → GSX · " + $0) }
        if stats.kept > 0 { try? data.write(to: cache) } else { try? FileManager.default.removeItem(at: cache) }
        return (data, stats)
    }

    /// Đường nét đứt (primitive .line, 120 vạch) từ gốc tới `end` + quả cầu ở hai đầu, màu vàng, vẽ đè
    /// (không đọc/ghi depth) để luôn thấy dù model ở xa hay bị che.
    private static func makeGuideLine(to end: SIMD3<Float>, dashes: Int = 60) -> SCNNode {
        // SceneKit vẽ primitive .line chỉ 1 px → dùng hình trụ cho từng vạch để có độ dày, màu magenta phát sáng
        let color = UIColor(red: 1, green: 0, blue: 0.85, alpha: 1)
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = color
        material.emission.contents = color
        material.readsFromDepthBuffer = false
        material.writesToDepthBuffer = false

        let root = SCNNode()
        root.name = "crsGuide"
        root.renderingOrder = 30
        let len = simd_length(end)
        let dir = end / len
        let radius = CGFloat(max(len * 0.003, 0.01))              // độ dày theo độ dài để ở xa vẫn thấy
        let dashLen = len / Float(dashes) * 0.55                  // vạch ~55 % đoạn, còn lại là khoảng trống
        let dash = SCNCylinder(radius: radius, height: CGFloat(dashLen))
        dash.radialSegmentCount = 6
        dash.materials = [material]
        // trục cylinder là Y → xoay theo hướng đường; ngược hẳn Y thì from:to: ra NaN → quay 180° quanh X
        let orient = dir.y < -0.9999 ? simd_quatf(angle: .pi, axis: SIMD3(1, 0, 0)) : simd_quatf(from: SIMD3<Float>(0, 1, 0), to: dir)
        for i in 0 ..< dashes {
            let t = (Float(i) + 0.5) / Float(dashes)
            let n = SCNNode(geometry: dash)
            n.simdPosition = end * t
            n.simdOrientation = orient
            n.renderingOrder = 30
            root.addChildNode(n)
        }
        // đánh dấu hai đầu: cầu nhỏ tại điểm đặt và cầu to hơn tại tâm model
        for (p, r) in [(SIMD3<Float>(repeating: 0), len * 0.008), (end, len * 0.015)] {
            let sphere = SCNSphere(radius: CGFloat(max(r, 0.02)))
            sphere.materials = [material]
            let n = SCNNode(geometry: sphere)
            n.simdPosition = p
            n.renderingOrder = 30
            root.addChildNode(n)
        }
        return root
    }

    /// Dữ liệu .gsx giải mã → dạng SplatCloud cần: cộng lại origin (header), lật Y/Z (COLMAP → SceneKit),
    /// trừ tâm. `center` nil = tự lấy theo phân vị như PLYReader.load; có = dùng tâm cho sẵn (để thấy model dịch).
    /// Làm bằng Double vì toạ độ UTM ~10⁵–10⁶ m. KHÔNG lấy mẫu: vẽ đủ splat như viewer web.
    private static func prepareSplats(_ b: GSX.Block, origin: SIMD3<Double>, center fixed: SIMD3<Double>?)
        -> (positions: [SIMD3<Float>], colors: [SIMD4<Float>], cov0: [SIMD3<Float>], cov1: [SIMD3<Float>],
            extent: SIMD3<Float>, center: SIMD3<Double>) {
        var world = [SIMD3<Double>](); world.reserveCapacity(b.count)
        var colors: [SIMD4<Float>] = [], cov0: [SIMD3<Float>] = [], cov1: [SIMD3<Float>] = []
        colors.reserveCapacity(b.count); cov0.reserveCapacity(b.count); cov1.reserveCapacity(b.count)
        for i in 0 ..< b.count {
            let p = origin + SIMD3<Double>(b.positions[i])
            world.append(SIMD3(p.x, -p.y, -p.z))
            colors.append(b.colors[i])
            // Σ' = F·Σ·F với F = diag(1,−1,−1): Σxy, Σxz đổi dấu; Σxx, Σyy, Σyz, Σzz giữ nguyên
            let a = b.cov0[i]
            cov0.append(SIMD3(a.x, -a.y, -a.z))
            cov1.append(b.cov1[i])
        }
        // phân vị trên mẫu ≤ 50k (float đủ vì chỉ để lấy tâm/extent tương đối)
        let step = max(1, world.count / 50_000)
        var sample: [SIMD3<Float>] = []; sample.reserveCapacity(world.count / step + 1)
        let anchor = world.first ?? .zero
        for i in stride(from: 0, to: world.count, by: step) { sample.append(SIMD3<Float>(world[i] - anchor)) }
        let (lo, mid, hi) = sample.isEmpty ? (SIMD3<Float>(), SIMD3<Float>(), SIMD3<Float>()) : PLYReader.percentiles(of: sample)
        let own = anchor + SIMD3<Double>(SIMD3(mid.x, lo.y, mid.z))
        let center = fixed ?? own
        var positions = [SIMD3<Float>](); positions.reserveCapacity(world.count)
        for w in world { positions.append(SIMD3<Float>(w - center)) }
        return (positions, colors, cov0, cov1, hi - lo, own)
    }

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
    /// Renderer cũ giữ thêm một lúc: SCNNode.rendererDelegate là `assign` (không giữ, không tự về nil),
    /// thread render có thể đang giữa frame còn gọi renderNode → thả ngay là objc_msgSend vào object đã chết.
    private var retiredRenderers: [SplatRenderer] = []

    private func retireSplatNode() {
        if let node = pointCloudNode {
            node.rendererDelegate = nil
            node.enumerateChildNodes { child, _ in child.rendererDelegate = nil }
            node.removeFromParentNode()
        }
        if let r = splatRenderer {
            retiredRenderers.append(r)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.retiredRenderers.removeAll { $0 === r }
            }
        }
        pointCloudNode = nil
        splatRenderer = nil
    }

    func loadPointCloud(_ source: ModelSource) {
        retireSplatNode()
        pointCloud = nil
        splatCloud = nil
        pointCloudRequest += 1
        let request = pointCloudRequest
        lastCloudSource = source
        let wantSplats = splatMode
        let wantGSX = gsxMode
        let crs = crsCode.map { (from: $0, to: CRS.displaySystem) }       // hệ gốc đã gán → hệ hiển thị
        var fileKey = ""
        if case .url(let u) = source { fileKey = u.absoluteString }
        let baseCenter = crs == nil ? nil : baseCenters[fileKey]
        delegate?.demo(status: "Đang tạo point cloud…")

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                guard let device = MTLCreateSystemDefaultDevice() else { throw CloudError("Không có Metal device") }
                let built: BuiltCloud
                var info = "Địa hình mẫu"
                var extent: SIMD3<Float>?
                var shift: SIMD3<Float>?                 // tâm model mới − điểm đặt (hệ local node) khi đổi hệ toạ độ
                switch source {
                case .none, .sample:
                    guard let c = MetalPointCloud.makeTerrain(device: device) else { throw CloudError("Không tạo được MTLBuffer") }
                    built = .points(c)
                case .url(let url) where wantSplats && wantGSX:
                    // ── Đường .gsx: PLY → .gsx trong app (cache) → giải mã cả file → SplatCloud ──
                    var local = url.isFileURL ? url : try await ModelLoader.download(url)
                    local = try PLYReader.assembleIfSplit(local)
                    let status: (String) -> Void = { s in Task { @MainActor in self?.delegate?.demo(status: s) } }
                    let (gsx, stats) = try Self.gsxFromPLY(local, crs: crs, status: status)
                    status("Giải mã .gsx…")
                    let (meta, all) = try GSX.decodeAll(gsx) { i, n in status("Giải mã .gsx: \(i)/\(n) block") }
                    let s = Self.prepareSplats(all, origin: meta.header.origin, center: baseCenter)
                    extent = s.extent
                    guard let c = SplatCloud(device: device, positions: s.positions, colors: s.colors, cov0: s.cov0, cov1: s.cov1)
                    else { throw CloudError("Không tạo được MTLBuffer") }
                    built = .splats(c)
                    if crs == nil { await MainActor.run { self?.baseCenters[fileKey] = s.center } }
                    info = String(format: "3DGS qua .gsx %d splat · %d block · %.1f MB · %.1f × %.1f × %.1f",
                                  s.positions.count, meta.header.blockCount,
                                  Double(gsx.count) / 1048576, s.extent.x, s.extent.y, s.extent.z)
                    if let crs {
                        info += " · gốc \(crs.from) → hiển thị \(crs.to)"
                        if let base = baseCenter {
                            let d = s.center - base          // hệ SceneKit: x Đông, z = −Bắc
                            shift = SIMD3<Float>(d)
                            info += String(format: " · dịch Δ Đông %.1f m, Bắc %.1f m (%.1f km)", d.x, -d.z, simd_length(SIMD2(d.x, d.z)) / 1000)
                        } else {
                            info += " · (chưa có tâm gốc: nạp 'Gốc PLY' trước để thấy dịch chuyển)"
                        }
                        if let i = stats?.crs, !i.identity {
                            info += String(format: " · xoay %.3f° · scale %.6f", i.yawDeg, i.scale)
                        }
                    }
                case .url(let url):
                    var local = url.isFileURL ? url : try await ModelLoader.download(url)
                    local = try PLYReader.assembleIfSplit(local)       // file cắt mảnh trong bundle → ghép lại
                    let ply = try PLYReader.load(url: local, mode: wantSplats ? .splats : .points)
                    extent = ply.extent
                    if ply.hasSplats {
                        var rgba: [SIMD4<Float>] = []
                        rgba.reserveCapacity(ply.colors.count)
                        for i in ply.colors.indices {
                            rgba.append(SIMD4(ply.colors[i], ply.opacities[i]))
                        }
                        guard let c = SplatCloud(device: device, positions: ply.positions, colors: rgba,
                                                 cov0: ply.cov0, cov1: ply.cov1)
                        else { throw CloudError("Không tạo được MTLBuffer") }
                        built = .splats(c)
                    } else {
                        guard let c = MetalPointCloud(device: device, positions: ply.positions, colors: ply.colors)
                        else { throw CloudError("Không tạo được MTLBuffer") }
                        built = .points(c)
                    }
                    let e = ply.extent
                    info = String(format: "%@ %d/%d · %.1f × %.1f × %.1f",
                                  ply.hasSplats ? "3DGS splat" : (ply.isGaussianSplat ? "3DGS điểm" : "PLY"),
                                  ply.positions.count, ply.totalVertices, e.x, e.y, e.z)
                }
                await MainActor.run {
                    // Bỏ kết quả cũ nếu trong lúc đọc đã có lệnh khác
                    guard let self, request == self.pointCloudRequest else { return }
                    // = SCNViewARContext.downloadDidFinish(... pointcloud:)
                    let node: SCNNode
                    switch built {
                    case .points(let cloud):
                        node = SCNBuilder.createNode(cloud, program: self.program)
                        self.program.pointCount = Int32(cloud.count)
                        self.pointCloud = cloud
                    case .splats(let cloud):
                        // Node có rendererDelegate: SceneKit KHÔNG vẽ geometry mà gọi SplatRenderer.renderNode
                        // mỗi frame (= renderer.renderFrame của web). Geometry chỉ để SceneKit có boundingBox mà cull.
                        let renderer = SplatRenderer(cloud: cloud, device: device)
                        renderer.splatScale = self.pointSizeValue / 14
                        renderer.opacity = self.program.opacity
                        let size = cloud.max - cloud.min
                        node = SCNNode(geometry: SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: 0))
                        node.boundingBox = (SCNVector3(cloud.min.x, cloud.min.y, cloud.min.z), SCNVector3(cloud.max.x, cloud.max.y, cloud.max.z))
                        node.rendererDelegate = renderer
                        node.renderingOrder = 20                // vẽ sau model/point cloud để blend lên trên
                        self.splatCloud = cloud
                        self.splatRenderer = renderer
                    }
                    self.arNode.addChildNode(node)
                    self.pointCloudNode = node
                    self.pointCloudExtent = extent
                    self.applyPointCloudSize()
                    if let shift, simd_length(shift) > 0.01 {
                        // Đường nét đứt từ điểm đặt (gốc node = chỗ model đứng khi Raw) tới tâm model ở hệ mới.
                        // Là con của node cloud nên ăn theo scale "Cỡ cloud" và theo arNode khi đặt trong AR.
                        node.addChildNode(Self.makeGuideLine(to: shift))
                    }
                    self.delegate?.demo(didLoad: built.count)
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
            self.retireSplatNode()
            self.arNode.enumerateChildNodes { node, _ in node.removeFromParentNode() }
            self.arNode.removeFromParentNode()
        }
    }

    // MARK: DemoEventContext — mỗi event cuối cùng chỉ là sửa property node/program

    func setPointSize(_ size: Float) {
        pointSizeValue = size
        program.pointSize = size
        splatRenderer?.splatScale = size / 14       // 14 = mặc định slider → splat đúng cỡ file
    }

    func setPointCloudVisible(_ visible: Bool) {
        pointCloudNode?.isHidden = !visible
    }

    func setOpacity(_ opacity: Float) {
        program.opacity = opacity
        splatRenderer?.opacity = opacity
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

    func setDistance(_ meters: Float) { /* màn con cần thì override */ }
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
