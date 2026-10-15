//
//  ModelLoader.swift
//  Quick3DDemo
//
//  Thay point cloud bằng model cụ thể. SceneKit đọc thẳng được:
//    .usdz / .usd / .usda / .usdc / .scn   → SCNScene(url:)
//    .obj (+ .mtl cùng thư mục)            → ModelIO (MDLAsset) → SCNScene
//  .glb/.gltf/.fbx/.dae KHÔNG đọc được lúc chạy trên iOS → đổi sang USDZ trước
//  (Reality Converter trên Mac, hoặc Blender: File → Export → USD).
//
//  Model được dời để ĐÁY-GIỮA nằm ở gốc arNode (đứng lên mặt phẳng), mặt trước = +Z.
//

import SceneKit
import ModelIO
import SceneKit.ModelIO

/// Nguồn model cho LoadModelEvent.
enum ModelSource {
    case none                   // bỏ model, quay lại point cloud
    case sample(SampleModel)    // model dựng bằng code, để thử không cần file
    case url(URL)               // file:// (đã copy vào tmp) hoặc http(s)://
}

/// Model mẫu dựng bằng hình cơ bản của SceneKit. Kích thước thật (m), đáy ở y = 0, mặt trước +Z.
enum SampleModel: String, CaseIterable, Identifiable {
    case house = "Nhà"
    case tree = "Cây"
    case car = "Xe"
    case table = "Bàn ghế"
    case marker = "Cột mốc"
    case tower = "Cột điện"
    case building = "Toà nhà"
    case bridge = "Cầu"
    case excavator = "Máy xúc"
    case truck = "Xe tải"
    case container = "Container"
    case sign = "Biển báo"
    case lamp = "Đèn đường"
    case fence = "Hàng rào"
    var id: String { rawValue }
}

enum ModelLoader {

    enum LoadError: LocalizedError {
        case unsupported(String)
        case empty
        case http(Int)

        var errorDescription: String? {
            switch self {
            case .unsupported(let ext): return "Không đọc được .\(ext) — đổi sang .usdz"
            case .empty: return "Model rỗng (bounding box = 0)"
            case .http(let code): return "HTTP \(code)"
            }
        }
    }

    /// Kết quả: node gốc của model + kích thước gốc (m) để tính tỉ lệ.
    struct Loaded {
        let node: SCNNode
        let extent: SIMD3<Float>
    }

    static func load(_ source: ModelSource) async throws -> Loaded? {
        switch source {
        case .none: return nil
        case .sample(let kind): return sample(kind)
        case .url(let url): return try await load(url)
        }
    }

    static func load(_ url: URL) async throws -> Loaded {
        let local = url.isFileURL ? url : try await download(url)
        let ext = local.pathExtension.lowercased()
        let scene: SCNScene
        switch ext {
        case "usdz", "usd", "usda", "usdc", "scn":
            scene = try SCNScene(url: local, options: nil)
        case "obj":
            let asset = MDLAsset(url: local)
            asset.loadTextures()
            scene = SCNScene(mdlAsset: asset)
        default:
            throw LoadError.unsupported(ext)
        }

        let content = SCNNode()
        for child in scene.rootNode.childNodes where child.camera == nil {
            content.addChildNode(child)
        }
        return try centered(content)
    }

    /// Copy file chọn từ Files sang tmp (URL từ fileImporter chỉ đọc được trong security scope).
    static func copyPicked(_ url: URL) throws -> URL {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(url.pathExtension)
        try FileManager.default.copyItem(at: url, to: dest)
        return dest
    }

    private static func download(_ url: URL) async throws -> URL {
        let (tmp, response) = try await URLSession.shared.download(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw LoadError.http(http.statusCode)
        }
        // Giữ đuôi file để còn biết dùng loader nào
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(url.pathExtension)
        try FileManager.default.moveItem(at: tmp, to: dest)
        return dest
    }

    /// Dời `content` để đáy-giữa bounding box về gốc, bọc trong một node để scale.
    private static func centered(_ content: SCNNode) throws -> Loaded {
        let (mn, mx) = content.boundingBox
        let lo = SIMD3<Float>(mn), hi = SIMD3<Float>(mx)
        let extent = hi - lo
        guard extent.max() > 0 else { throw LoadError.empty }
        content.simdPosition = SIMD3(-(lo.x + hi.x) / 2, -lo.y, -(lo.z + hi.z) / 2)

        let root = SCNNode()
        root.name = "model"
        root.addChildNode(content)
        return Loaded(node: root, extent: extent)
    }

    // MARK: - Model mẫu

    static func sample(_ kind: SampleModel) -> Loaded {
        let content = SCNNode()
        switch kind {
        case .house: buildHouse(into: content)
        case .tree: buildTree(into: content)
        case .car: buildCar(into: content)
        case .table: buildTable(into: content)
        case .marker: buildMarker(into: content)
        case .tower: buildTower(into: content)
        case .building: buildBuilding(into: content)
        case .bridge: buildBridge(into: content)
        case .excavator: buildExcavator(into: content)
        case .truck: buildTruck(into: content)
        case .container: buildContainer(into: content)
        case .sign: buildSign(into: content)
        case .lamp: buildLamp(into: content)
        case .fence: buildFence(into: content)
        }
        // centered() không thể lỗi với hình dựng sẵn
        return (try? centered(content)) ?? Loaded(node: content, extent: SIMD3(1, 1, 1))
    }

    private static func material(_ color: UIColor, metal: Bool = false) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.lightingModel = .physicallyBased
        m.roughness.contents = metal ? 0.35 : 0.8
        m.metalness.contents = metal ? 0.9 : 0
        return m
    }

    /// Gắn `geometry` tô `color` vào `parent` tại (x, y, z); trả node để xoay thêm nếu cần.
    @discardableResult
    private static func add(_ geometry: SCNGeometry, _ color: UIColor, metal: Bool = false,
                            to parent: SCNNode, x: Float = 0, y: Float = 0, z: Float = 0) -> SCNNode {
        geometry.materials = [material(color, metal: metal)]
        let node = SCNNode(geometry: geometry)
        node.simdPosition = SIMD3(x, y, z)
        parent.addChildNode(node)
        return node
    }

    /// Nhà 1×1×1 m: thân hộp + mái chóp + cửa ở mặt trước (+Z) để nhìn ra hướng.
    private static func buildHouse(into root: SCNNode) {
        add(SCNBox(width: 1, height: 0.6, length: 1, chamferRadius: 0), .systemTeal, to: root, y: 0.3)
        add(SCNPyramid(width: 1.1, height: 0.4, length: 1.1), .systemRed, to: root, y: 0.6)
        add(SCNBox(width: 0.25, height: 0.4, length: 0.02, chamferRadius: 0), .brown, to: root, y: 0.2, z: 0.505)
    }

    /// Cây 2 m: thân trụ + 3 tầng nón lá.
    private static func buildTree(into root: SCNNode) {
        add(SCNCylinder(radius: 0.08, height: 0.6), .brown, to: root, y: 0.3)
        add(SCNCone(topRadius: 0, bottomRadius: 0.6, height: 0.7), .systemGreen, to: root, y: 0.85)
        add(SCNCone(topRadius: 0, bottomRadius: 0.45, height: 0.6), .systemGreen, to: root, y: 1.3)
        add(SCNCone(topRadius: 0, bottomRadius: 0.3, height: 0.5), .systemGreen, to: root, y: 1.75)
    }

    /// Xe 1.8 m dài (theo trục Z), đầu xe hướng +Z.
    private static func buildCar(into root: SCNNode) {
        add(SCNBox(width: 0.8, height: 0.35, length: 1.8, chamferRadius: 0.05), .systemBlue, to: root, y: 0.3)
        add(SCNBox(width: 0.7, height: 0.3, length: 0.9, chamferRadius: 0.08), .systemIndigo, to: root, y: 0.62, z: -0.1)
        for (x, z) in [(-0.4, 0.55), (0.4, 0.55), (-0.4, -0.55), (0.4, -0.55)] {
            let wheel = add(SCNCylinder(radius: 0.15, height: 0.1), .darkGray, to: root,
                            x: Float(x), y: 0.15, z: Float(z))
            wheel.simdEulerAngles = SIMD3(0, 0, .pi / 2)      // trục bánh xe nằm ngang
        }
        add(SCNBox(width: 0.12, height: 0.08, length: 0.02, chamferRadius: 0), .yellow, to: root, x: -0.28, y: 0.35, z: 0.905)
        add(SCNBox(width: 0.12, height: 0.08, length: 0.02, chamferRadius: 0), .yellow, to: root, x: 0.28, y: 0.35, z: 0.905)
    }

    /// Bàn 1.2×0.75 m + 2 ghế hai bên.
    private static func buildTable(into root: SCNNode) {
        add(SCNBox(width: 1.2, height: 0.04, length: 0.7, chamferRadius: 0.01), .brown, to: root, y: 0.73)
        for (x, z) in [(-0.55, 0.3), (0.55, 0.3), (-0.55, -0.3), (0.55, -0.3)] {
            add(SCNCylinder(radius: 0.025, height: 0.71), .darkGray, metal: true, to: root, x: Float(x), y: 0.355, z: Float(z))
        }
        for x: Float in [-0.9, 0.9] {
            add(SCNBox(width: 0.4, height: 0.04, length: 0.4, chamferRadius: 0.01), .systemOrange, to: root, x: x, y: 0.45)
            add(SCNBox(width: 0.04, height: 0.45, length: 0.4, chamferRadius: 0.01), .systemOrange, to: root,
                x: x + (x < 0 ? -0.18 : 0.18), y: 0.69)
            for (dx, dz) in [(-0.17, 0.17), (0.17, 0.17), (-0.17, -0.17), (0.17, -0.17)] {
                add(SCNCylinder(radius: 0.015, height: 0.43), .darkGray, metal: true, to: root,
                    x: x + Float(dx), y: 0.215, z: Float(dz))
            }
        }
    }

    /// Cột mốc khảo sát 1.5 m: đế bê tông + cọc đỏ-trắng + cờ.
    private static func buildMarker(into root: SCNNode) {
        add(SCNCylinder(radius: 0.2, height: 0.1), .lightGray, to: root, y: 0.05)
        for i in 0 ..< 6 {
            add(SCNCylinder(radius: 0.03, height: 0.2), i % 2 == 0 ? .systemRed : .white, to: root, y: 0.2 + Float(i) * 0.2)
        }
        add(SCNBox(width: 0.3, height: 0.2, length: 0.005, chamferRadius: 0), .systemYellow, to: root, x: 0.16, y: 1.4, z: 0)
        add(SCNSphere(radius: 0.04), .systemRed, to: root, y: 1.52)
    }

    /// Cột điện 6 m: trụ bê tông + xà ngang + 3 sứ cách điện.
    private static func buildTower(into root: SCNNode) {
        add(SCNCone(topRadius: 0.09, bottomRadius: 0.14, height: 6), .lightGray, to: root, y: 3)
        add(SCNBox(width: 1.6, height: 0.08, length: 0.08, chamferRadius: 0), .darkGray, metal: true, to: root, y: 5.6)
        for x: Float in [-0.7, 0, 0.7] {
            add(SCNCylinder(radius: 0.05, height: 0.15), .white, to: root, x: x, y: 5.72)
        }
    }

    /// Toà nhà 5 tầng 8×15 m: thân + lưới cửa sổ 4 mặt + mái.
    private static func buildBuilding(into root: SCNNode) {
        let w: Float = 8, d: Float = 8, floors = 5, floorH: Float = 3
        let h = Float(floors) * floorH
        add(SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(d), chamferRadius: 0), .systemGray, to: root, y: h / 2)
        add(SCNBox(width: CGFloat(w) + 0.4, height: 0.3, length: CGFloat(d) + 0.4, chamferRadius: 0), .darkGray, to: root, y: h + 0.15)
        let glass = material(.systemBlue)
        glass.roughness.contents = 0.2
        glass.metalness.contents = 0.6
        for f in 0 ..< floors {
            let y = Float(f) * floorH + floorH / 2
            for i in 0 ..< 3 {
                let x = Float(i - 1) * 2.4
                for z: Float in [d / 2 + 0.01, -d / 2 - 0.01] {
                    let win = SCNBox(width: 1.2, height: 1.4, length: 0.02, chamferRadius: 0)
                    win.materials = [glass]
                    let n = SCNNode(geometry: win); n.simdPosition = SIMD3(x, y, z); root.addChildNode(n)
                }
                for x2: Float in [w / 2 + 0.01, -w / 2 - 0.01] {
                    let win = SCNBox(width: 0.02, height: 1.4, length: 1.2, chamferRadius: 0)
                    win.materials = [glass]
                    let n = SCNNode(geometry: win); n.simdPosition = SIMD3(x2, y, x); root.addChildNode(n)
                }
            }
        }
        add(SCNBox(width: 2, height: 2.4, length: 0.05, chamferRadius: 0), .brown, to: root, y: 1.2, z: d / 2 + 0.03)
    }

    /// Cầu dầm 20 m (theo X): mặt cầu + 3 trụ + lan can.
    private static func buildBridge(into root: SCNNode) {
        let length: Float = 20, deckY: Float = 5
        add(SCNBox(width: CGFloat(length), height: 0.6, length: 6, chamferRadius: 0), .lightGray, to: root, y: deckY)
        for x: Float in [-8, 0, 8] {
            add(SCNBox(width: 1.2, height: CGFloat(deckY), length: 4, chamferRadius: 0), .systemGray, to: root, x: x, y: deckY / 2 - 0.3)
        }
        for z: Float in [2.9, -2.9] {
            add(SCNBox(width: CGFloat(length), height: 0.05, length: 0.05, chamferRadius: 0), .darkGray, metal: true, to: root, y: deckY + 1.3, z: z)
            for i in 0 ... 10 {
                add(SCNBox(width: 0.05, height: 1, length: 0.05, chamferRadius: 0), .darkGray, metal: true, to: root,
                    x: Float(i) * 2 - 10, y: deckY + 0.8, z: z)
            }
        }
        add(SCNBox(width: CGFloat(length), height: 0.01, length: 0.15, chamferRadius: 0), .white, to: root, y: deckY + 0.31)
    }

    /// Máy xúc 6 m: xích + thân xoay + cần + gầu, gầu hướng +Z.
    private static func buildExcavator(into root: SCNNode) {
        for x: Float in [-1.2, 1.2] {
            add(SCNBox(width: 0.6, height: 0.8, length: 4, chamferRadius: 0.2), .darkGray, to: root, x: x, y: 0.4)
        }
        add(SCNBox(width: 2.6, height: 1.4, length: 2.8, chamferRadius: 0.1), .systemYellow, to: root, y: 1.5, z: -0.6)
        add(SCNBox(width: 1.1, height: 1.2, length: 1.3, chamferRadius: 0.1), .systemIndigo, to: root, x: -0.7, y: 2.8, z: 0)
        let boom = add(SCNBox(width: 0.5, height: 0.5, length: 3.5, chamferRadius: 0.05), .systemYellow, to: root, x: 0.5, y: 2.8, z: 1.4)
        boom.simdEulerAngles = SIMD3(-.pi / 6, 0, 0)
        let stick = add(SCNBox(width: 0.4, height: 0.4, length: 2.5, chamferRadius: 0.05), .systemYellow, to: root, x: 0.5, y: 2.6, z: 3.6)
        stick.simdEulerAngles = SIMD3(.pi / 3, 0, 0)
        add(SCNBox(width: 1, height: 0.8, length: 0.9, chamferRadius: 0.05), .darkGray, metal: true, to: root, x: 0.5, y: 0.5, z: 4.6)
    }

    /// Xe tải ben 7 m, đầu xe hướng +Z.
    private static func buildTruck(into root: SCNNode) {
        add(SCNBox(width: 2.4, height: 0.4, length: 7, chamferRadius: 0), .darkGray, to: root, y: 0.7)
        add(SCNBox(width: 2.4, height: 2, length: 2, chamferRadius: 0.1), .systemRed, to: root, y: 1.9, z: 2.3)
        add(SCNBox(width: 2.2, height: 0.9, length: 0.05, chamferRadius: 0), .systemBlue, to: root, y: 2.3, z: 3.31)
        add(SCNBox(width: 2.4, height: 1.3, length: 4.4, chamferRadius: 0), .systemOrange, to: root, y: 1.55, z: -1.1)
        for (x, z) in [(-1.1, 2.3), (1.1, 2.3), (-1.1, -0.6), (1.1, -0.6), (-1.1, -2.1), (1.1, -2.1)] {
            let wheel = add(SCNCylinder(radius: 0.5, height: 0.35), .black, to: root, x: Float(x), y: 0.5, z: Float(z))
            wheel.simdEulerAngles = SIMD3(0, 0, .pi / 2)
        }
    }

    /// Container 20 ft (6.06 × 2.44 × 2.59 m), gân dọc hai bên.
    private static func buildContainer(into root: SCNNode) {
        add(SCNBox(width: 6.06, height: 2.59, length: 2.44, chamferRadius: 0.02), .systemTeal, to: root, y: 1.295)
        for i in 0 ..< 12 {
            let x = Float(i) * 0.5 - 2.75
            for z: Float in [1.23, -1.23] {
                add(SCNBox(width: 0.08, height: 2.4, length: 0.04, chamferRadius: 0), .systemTeal, to: root, x: x, y: 1.295, z: z)
            }
        }
        for z: Float in [0.6, -0.6] {
            add(SCNCylinder(radius: 0.03, height: 2.3), .darkGray, metal: true, to: root, x: 3.05, y: 1.295, z: z)
        }
    }

    /// Biển báo tròn 2.5 m, mặt hướng +Z.
    private static func buildSign(into root: SCNNode) {
        add(SCNCylinder(radius: 0.04, height: 2.2), .lightGray, metal: true, to: root, y: 1.1)
        let disc = add(SCNCylinder(radius: 0.35, height: 0.02), .systemRed, to: root, y: 2.1)
        disc.simdEulerAngles = SIMD3(.pi / 2, 0, 0)
        let inner = add(SCNCylinder(radius: 0.27, height: 0.025), .white, to: root, y: 2.1, z: 0.002)
        inner.simdEulerAngles = SIMD3(.pi / 2, 0, 0)
        add(SCNBox(width: 0.4, height: 0.08, length: 0.03, chamferRadius: 0), .systemRed, to: root, y: 2.1, z: 0.02)
    }

    /// Đèn đường 8 m: trụ + cần cong + chao đèn.
    private static func buildLamp(into root: SCNNode) {
        add(SCNCylinder(radius: 0.12, height: 0.4), .darkGray, to: root, y: 0.2)
        add(SCNCone(topRadius: 0.06, bottomRadius: 0.1, height: 7.6), .lightGray, metal: true, to: root, y: 4.2)
        let arm = add(SCNCylinder(radius: 0.05, height: 2), .lightGray, metal: true, to: root, x: 0.9, y: 7.9)
        arm.simdEulerAngles = SIMD3(0, 0, .pi / 2 - 0.2)
        add(SCNBox(width: 0.7, height: 0.15, length: 0.3, chamferRadius: 0.05), .darkGray, to: root, x: 1.9, y: 8)
        add(SCNBox(width: 0.6, height: 0.02, length: 0.25, chamferRadius: 0), .systemYellow, to: root, x: 1.9, y: 7.92)
    }

    /// Hàng rào công trường 10 m (theo X): tấm tôn xanh + cột.
    private static func buildFence(into root: SCNNode) {
        for i in 0 ..< 5 {
            let x = Float(i) * 2 - 4
            add(SCNBox(width: 1.95, height: 2, length: 0.03, chamferRadius: 0), .systemBlue, to: root, x: x, y: 1.05)
            add(SCNBox(width: 1.95, height: 0.15, length: 0.035, chamferRadius: 0), .white, to: root, x: x, y: 1.9)
        }
        for i in 0 ... 5 {
            add(SCNBox(width: 0.08, height: 2.3, length: 0.08, chamferRadius: 0), .darkGray, metal: true, to: root, x: Float(i) * 2 - 5, y: 1.15)
        }
    }
}
