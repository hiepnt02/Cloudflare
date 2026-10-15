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
    case none           // bỏ model, quay lại point cloud
    case sample         // nhà mẫu dựng bằng code, để thử không cần file
    case url(URL)       // file:// (đã copy vào tmp) hoặc http(s)://
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
        case .sample: return sampleHouse()
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

    /// Nhà 1×0.8×1 m: thân hộp + mái chóp + cửa ở mặt trước (+Z) để nhìn ra hướng.
    static func sampleHouse() -> Loaded {
        func material(_ color: UIColor) -> SCNMaterial {
            let m = SCNMaterial()
            m.diffuse.contents = color
            m.lightingModel = .physicallyBased
            m.roughness.contents = 0.8
            return m
        }
        let content = SCNNode()

        let body = SCNNode(geometry: SCNBox(width: 1, height: 0.6, length: 1, chamferRadius: 0))
        body.geometry?.materials = [material(.systemTeal)]
        body.position = SCNVector3(0, 0.3, 0)
        content.addChildNode(body)

        let roof = SCNNode(geometry: SCNPyramid(width: 1.1, height: 0.4, length: 1.1))
        roof.geometry?.materials = [material(.systemRed)]
        roof.position = SCNVector3(0, 0.6, 0)
        content.addChildNode(roof)

        let door = SCNNode(geometry: SCNBox(width: 0.25, height: 0.4, length: 0.02, chamferRadius: 0))
        door.geometry?.materials = [material(.brown)]
        door.position = SCNVector3(0, 0.2, 0.505)
        content.addChildNode(door)

        // centered() không thể lỗi với hình dựng sẵn
        return (try? centered(content)) ?? Loaded(node: content, extent: SIMD3(1, 1, 1))
    }
}
