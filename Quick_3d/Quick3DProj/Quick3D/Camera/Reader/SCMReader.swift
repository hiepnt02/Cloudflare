//
//  SCMReader.swift
//  Quick3D
//
//  SCM binary format reader — converts SCM to SceneKit nodes.
//
//  Preserves the SCM scene graph for both rendering and the layer tree:
//  - every entity keeps its parent and local TRS, including grouping entities
//  - one shared geometry per meshId (web: one InstancedMesh per mesh)
//  - normals / UVs / vertex colors / textures from the streams
//  - entity colour only when the mesh has no vertex colours; blank or white
//    entity colour → 0.7 grey (same rule as web)
//  - Lambert, double sided
//  - geometry stays centered near zero; file-level georeferencing is kept in
//    Double precision outside SceneKit's vertex buffers
//  - Y-up SCM coordinates are already SceneKit coordinates; Z-up SCM uses
//    (x, y, z) -> (x, z, -y), including the metadata origin
//

import Foundation
import simd
import SceneKit
import UIKit
import Alamofire

// MARK: - SCM Types

private let SCM_HEADER_SIZE = 32
private let SCM_BLOCK_ENTRY_SIZE = 18
private let SCM_GEOMETRY_DESC_SIZE = 52
private let SCM_MATERIAL_DESC_SIZE = 16
private let SCM_TEXTURE_DESC_SIZE = 24
private let SCM_NO_OFFSET: UInt32 = 0xFFFF_FFFF

private enum SCMBlockType: UInt16 {
    case parent         = 0x0001
    case meshId         = 0x0002
    case materialId     = 0x0003
    case color          = 0x0004
    case position       = 0x0005
    case rotation       = 0x0006
    case scale          = 0x0007
    case category       = 0x0008
    case flags          = 0x0009
    case name           = 0x000A
    case geometryTable  = 0x0100
    case materialTable  = 0x0101
    case textureTable   = 0x0102
    case positionsStream = 0x0200
    case normalsStream  = 0x0201
    case uvsStream      = 0x0202
    case indicesStream  = 0x0203
    case vertexColorsStream = 0x0204
    case textureDataPool = 0x0205
    case stringTable    = 0x0206
    case metadata       = 0x0300
}

private struct SCMBlockEntry {
    let blockType: UInt16
    let offset: Int
    let size: Int
}

private struct SCMGeometry {
    let vertexCount: Int
    let indexCount: Int
    let vertexOffset: UInt32
    let normalOffset: UInt32
    let uvOffset: UInt32
    let indexOffset: UInt32
    let vertexColorOffset: UInt32
    let bboxMin: SIMD3<Float>
    let bboxMax: SIMD3<Float>
}

private struct SCMMaterial {
    let textureId: Int32
    let opacity: UInt8
    let flags: UInt8
}

private struct SCMTexture {
    let width: Int
    let height: Int
    let compression: UInt8 // 0 = raw RGBA, 1 = png, 2 = jpeg
    let dataOffset: Int
    let dataSize: Int
}

private struct SCMGeoreference {
    let origin: SIMD3<Double>
    let rotation: Double
    let scale: Double

}

// MARK: - Binary Reader Helper

/// Little-endian reader over the whole file. Reads straight from the buffer
/// (no per-value `subdata` copies), so large models parse quickly.
private struct BinaryReader {
    let bytes: UnsafeRawBufferPointer

    func u8(_ o: Int) -> UInt8 { bytes[o] }
    func u16(_ o: Int) -> UInt16 { UInt16(littleEndian: bytes.loadUnaligned(fromByteOffset: o, as: UInt16.self)) }
    func u32(_ o: Int) -> UInt32 { UInt32(littleEndian: bytes.loadUnaligned(fromByteOffset: o, as: UInt32.self)) }
    func i32(_ o: Int) -> Int32 { Int32(bitPattern: u32(o)) }
    func f32(_ o: Int) -> Float { Float(bitPattern: u32(o)) }
    func f64(_ o: Int) -> Double {
        Double(bitPattern: UInt64(littleEndian: bytes.loadUnaligned(fromByteOffset: o, as: UInt64.self)))
    }
    func f32x3(_ o: Int) -> SIMD3<Float> { SIMD3(f32(o), f32(o + 4), f32(o + 8)) }

    var count: Int { bytes.count }
}

private enum SCMError: LocalizedError {
    case invalidMagic
    case truncated(String)
    case missingStreams
    case invalidMetadata
    case invalidCoordinateSystem

    var errorDescription: String? {
        switch self {
        case .invalidMagic: return "Invalid SCM magic"
        case .truncated(let what): return "SCM file truncated (\(what))"
        case .missingStreams: return "SCM missing position/index streams"
        case .invalidMetadata: return "SCM has invalid georeferencing metadata"
        case .invalidCoordinateSystem: return "SCM has an unsupported coordinate system"
        }
    }
}

// MARK: - SCMReader

class SCMReader: ARProjectHelper {

    private let url: URL
    private var fileUrl: URL?
    var layers: [LayerNode] = []
    var node: SCNNode?
    private var coordinateSystem: UInt8 = 0
    private var georeference: SCMGeoreference?

    override init(projectId: String) {
        self.url = URL(string: Constant.baseUrl + "api/v1/project/\(projectId)/ARdownload/SCM")!
        super.init(projectId: projectId)
    }

    override func update(min: SIMD3<Float>, max: SIMD3<Float>) {
        super.update(min: min, max: max)
        let localCenter = sceneKitPosition(SIMD3<Double>(self.center))
        let angle = (georeference?.rotation ?? 0).truncatingRemainder(dividingBy: 2 * .pi)
        let scale = georeference?.scale ?? 1
        let c = cos(angle), s = sin(angle)
        let mappedCenter = SIMD3<Double>(
            c * localCenter.x + s * localCenter.z,
            localCenter.y,
            -s * localCenter.x + c * localCenter.z
        ) * scale
        let origin = sceneKitPosition(georeference?.origin ?? .zero)
        self.update(offset: origin + mappedCenter)
    }

    private func sceneKitPosition(_ value: SIMD3<Double>) -> SIMD3<Double> {
        coordinateSystem == 1 ? SIMD3(value.x, value.z, -value.y) : value
    }

    func fetch() async {
        do {
            print("[SCMReader] Fetching presign URL from \(url)")
            let presignUrl = try await getPresignUrl(url)
            self.fileUrl = try await downloadFile(presignUrl, fileName: "model.scm")

            guard let fileUrl = self.fileUrl else {
                throw NSError(domain: "SCMReader", code: 1, userInfo: [NSLocalizedDescriptionKey: "No file downloaded"])
            }

            let data = try Data(contentsOf: fileUrl, options: .mappedIfSafe)
            print("[SCMReader] File size: \(data.count) bytes, parsing...")
            let parsed = try parseSCM(data)
            print("[SCMReader] Parsed OK, \(parsed.entities.count) entities, \(parsed.drawGeometries) geometries")

            guard (0..<3).allSatisfy({
                parsed.bboxMin[$0].isFinite && parsed.bboxMax[$0].isFinite
                    && parsed.bboxMin[$0] <= parsed.bboxMax[$0]
            }) else {
                throw NSError(domain: "SCMReader", code: 3, userInfo: [NSLocalizedDescriptionKey: "SCM has no renderable geometry"])
            }

            coordinateSystem = parsed.coordinateSystem
            georeference = parsed.georeference
            update(min: parsed.bboxMin, max: parsed.bboxMax)

            let rootNode = SCNNode()
            rootNode.name = "SCM_Root"
            rootNode.castsShadow = false
            let axisRotation = simd_quatf(angle: coordinateSystem == 1 ? -.pi / 2 : 0,
                                         axis: SIMD3<Float>(1, 0, 0))
            let angle = (georeference?.rotation ?? 0).truncatingRemainder(dividingBy: 2 * .pi)
            let mapRotation = simd_quatf(angle: Float(angle), axis: SIMD3<Float>(0, 1, 0))
            rootNode.simdOrientation = mapRotation * axisRotation
            let mapScale = Float(georeference?.scale ?? 1)
            rootNode.simdScale = SIMD3<Float>(repeating: mapScale)
            // Center the complete source hierarchy once, without changing any
            // entity's local transform or removing its inherited transform.
            let centeredNode = SCNNode()
            centeredNode.name = "SCM_CenteredContent"
            centeredNode.simdPosition = -self.center
            parsed.roots.forEach { centeredNode.addChildNode($0) }
            rootNode.addChildNode(centeredNode)
            self.node = rootNode
            delegate?.onCreateNode(rootNode)

            layers = buildLayers(parsed.roots, displayNames: parsed.displayNames)

            delegate?.onComplete()

        } catch {
            print("[SCMReader] ❌ ERROR: \(error)")
            setError(error)
        }
    }

    // MARK: - SCM Parser

    private struct ParsedSCM {
        var entities: [SCNNode]
        var roots: [SCNNode]
        var displayNames: [String: String]
        var drawGeometries: Int
        var bboxMin: SIMD3<Float>
        var bboxMax: SIMD3<Float>
        var coordinateSystem: UInt8
        var georeference: SCMGeoreference?
    }

    private func parseSCM(_ data: Data) throws -> ParsedSCM {
        return try data.withUnsafeBytes { raw -> ParsedSCM in
            let r = BinaryReader(bytes: raw)
            guard r.count >= SCM_HEADER_SIZE else { throw SCMError.truncated("header") }

            // Magic "SCM\0"
            guard r.u8(0) == 0x53, r.u8(1) == 0x43, r.u8(2) == 0x4D, (r.u8(3) == 0x00 || r.u8(3) == 0x5A) else {
                throw SCMError.invalidMagic
            }

            // Header (same offsets as the web worker)
            let entityCount = Int(r.u32(6))
            let blockCount = Int(r.u16(10))
            let geoCount = Int(r.u32(12))
            let matCount = Int(r.u32(16))
            let texCount = Int(r.u32(20))
            let coordinateSystem = r.u8(24)
            guard coordinateSystem == 0 || coordinateSystem == 1 else {
                throw SCMError.invalidCoordinateSystem
            }

            guard r.count >= SCM_HEADER_SIZE + blockCount * SCM_BLOCK_ENTRY_SIZE else {
                throw SCMError.truncated("block directory")
            }

            // Block directory
            var blocks: [UInt16: SCMBlockEntry] = [:]
            for i in 0..<blockCount {
                let o = SCM_HEADER_SIZE + i * SCM_BLOCK_ENTRY_SIZE
                let type = r.u16(o)
                let entry = SCMBlockEntry(blockType: type, offset: Int(r.u32(o + 6)), size: Int(r.u32(o + 10)))
                guard entry.offset + entry.size <= r.count else { throw SCMError.truncated("block 0x\(String(type, radix: 16))") }
                if blocks[type] == nil { blocks[type] = entry }
            }
            func block(_ t: SCMBlockType) -> SCMBlockEntry? { blocks[t.rawValue] }

            // 0x0300: origin xyz, rotation and scale as 5 little-endian f64s,
            // then two UInt16-length-prefixed UTF-8 CRS names.
            var georeference: SCMGeoreference?
            if let metadata = block(.metadata) {
                guard metadata.size >= 44 else { throw SCMError.truncated("metadata") }
                let start = metadata.offset
                let end = start + metadata.size
                let origin = SIMD3<Double>(r.f64(start), r.f64(start + 8), r.f64(start + 16))
                let rotation = r.f64(start + 24)
                let scale = r.f64(start + 32)
                guard origin.x.isFinite, origin.y.isFinite, origin.z.isFinite,
                      rotation.isFinite, scale.isFinite, scale > 0,
                      Float(scale).isFinite, Float(scale) > 0 else {
                    throw SCMError.invalidMetadata
                }
                let horizontalStart = start + 42
                let horizontalLength = Int(r.u16(start + 40))
                let verticalLengthOffset = horizontalStart + horizontalLength
                guard verticalLengthOffset + 2 <= end else { throw SCMError.truncated("horizontal CRS") }
                let verticalStart = verticalLengthOffset + 2
                let verticalLength = Int(r.u16(verticalLengthOffset))
                guard verticalStart + verticalLength <= end else { throw SCMError.truncated("vertical CRS") }
                guard String(bytes: raw[horizontalStart..<verticalLengthOffset], encoding: .utf8) != nil,
                      String(bytes: raw[verticalStart..<(verticalStart + verticalLength)], encoding: .utf8) != nil else {
                    throw SCMError.invalidMetadata
                }
                georeference = SCMGeoreference(origin: origin, rotation: rotation, scale: scale)
            }

            let N = entityCount

            // Masked components: mask[N] then the non-default values packed
            func masked<T>(_ t: SCMBlockType, stride: Int, def: T, read: (Int) -> T) -> [T] {
                var out = [T](repeating: def, count: N)
                guard let b = block(t), b.size >= N else { return out }
                var p = b.offset + N
                for i in 0..<N where r.u8(b.offset + i) != 0 {
                    guard p + stride <= b.offset + b.size else { break }
                    out[i] = read(p)
                    p += stride
                }
                return out
            }

            let parents = masked(.parent, stride: 4, def: Int32(-1)) { r.i32($0) }
            let meshIds = masked(.meshId, stride: 4, def: Int32(-1)) { r.i32($0) }
            let materialIds = masked(.materialId, stride: 4, def: Int32(-1)) { r.i32($0) }
            let colors = masked(.color, stride: 4, def: SIMD4<UInt8>(0, 0, 0, 0)) {
                SIMD4(r.u8($0), r.u8($0 + 1), r.u8($0 + 2), r.u8($0 + 3))
            }
            let positions = masked(.position, stride: 12, def: SIMD3<Float>.zero) { r.f32x3($0) }
            let rotations = masked(.rotation, stride: 16, def: SIMD4<Float>(0, 0, 0, 1)) {
                SIMD4(r.f32($0), r.f32($0 + 4), r.f32($0 + 8), r.f32($0 + 12))
            }
            let scales = masked(.scale, stride: 12, def: SIMD3<Float>(1, 1, 1)) { r.f32x3($0) }
            let flags = masked(.flags, stride: 1, def: UInt8(0x03)) { r.u8($0) }
            let nameOffsets = masked(.name, stride: 4, def: UInt32.max) { r.u32($0) }

            // Names: uint32 BYTE offset into the NUL-separated UTF-8 string table
            var names = [String?](repeating: nil, count: N)
            if let st = block(.stringTable) {
                for i in 0..<N {
                    let off = nameOffsets[i]
                    guard off != UInt32.max, Int(off) < st.size else { continue }
                    let start = st.offset + Int(off)
                    var end = start
                    let limit = st.offset + st.size
                    while end < limit && r.u8(end) != 0 { end += 1 }
                    if end > start {
                        names[i] = String(decoding: UnsafeRawBufferPointer(rebasing: raw[start..<end]), as: UTF8.self)
                    }
                }
            }

            // Geometry table
            var geometries: [SCMGeometry] = []
            if let gb = block(.geometryTable) {
                let count = Swift.min(geoCount, gb.size / SCM_GEOMETRY_DESC_SIZE)
                geometries.reserveCapacity(count)
                for i in 0..<count {
                    let o = gb.offset + i * SCM_GEOMETRY_DESC_SIZE
                    geometries.append(SCMGeometry(
                        vertexCount: Int(r.u32(o)),
                        indexCount: Int(r.u32(o + 4)),
                        vertexOffset: r.u32(o + 8),
                        normalOffset: r.u32(o + 12),
                        uvOffset: r.u32(o + 16),
                        indexOffset: r.u32(o + 20),
                        vertexColorOffset: r.u32(o + 24),
                        bboxMin: r.f32x3(o + 28),
                        bboxMax: r.f32x3(o + 40)
                    ))
                }
            }

            // Material table
            var materials: [SCMMaterial] = []
            if let mb = block(.materialTable) {
                let count = Swift.min(matCount, mb.size / SCM_MATERIAL_DESC_SIZE)
                for i in 0..<count {
                    let o = mb.offset + i * SCM_MATERIAL_DESC_SIZE
                    materials.append(SCMMaterial(textureId: r.i32(o), opacity: r.u8(o + 8), flags: r.u8(o + 9)))
                }
            }

            // Texture table + pool
            var textures: [SCMTexture] = []
            if let tb = block(.textureTable) {
                let count = Swift.min(texCount, tb.size / SCM_TEXTURE_DESC_SIZE)
                for i in 0..<count {
                    let o = tb.offset + i * SCM_TEXTURE_DESC_SIZE
                    textures.append(SCMTexture(
                        width: Int(r.u16(o)),
                        height: Int(r.u16(o + 2)),
                        compression: r.u8(o + 4),
                        dataOffset: Int(r.u32(o + 6)),
                        dataSize: Int(r.u32(o + 10))
                    ))
                }
            }
            let images = decodeTextures(textures, pool: block(.textureDataPool), raw: raw)

            // Streams
            guard let posBlock = block(.positionsStream), let idxBlock = block(.indicesStream) else {
                throw SCMError.missingStreams
            }
            let streams = Streams(
                positions: posBlock,
                normals: block(.normalsStream),
                uvs: block(.uvsStream),
                indices: idxBlock,
                vertexColors: block(.vertexColorsStream)
            )

            // One geometry per meshId, shared by every entity using it
            var geoCache: [Int: SCNGeometry] = [:]
            var hasVertexColors: [Int: Bool] = [:]
            for (i, g) in geometries.enumerated() where g.vertexCount > 0 && g.indexCount > 0 {
                if let geom = buildGeometry(g, streams: streams, r: r) {
                    geoCache[i] = geom
                    hasVertexColors[i] = streams.vertexColors != nil && g.vertexColorOffset != SCM_NO_OFFSET
                }
            }

            // Materials cached by (texture, colour) so equal looks share one SCNMaterial
            var materialCache: [String: SCNMaterial] = [:]
            func material(texId: Int32, color: UIColor, colorKey: String) -> SCNMaterial {
                let key = "\(texId)_\(colorKey)"
                if let m = materialCache[key] { return m }
                let m = SCNMaterial()
                m.lightingModel = .lambert
                m.isDoubleSided = true
                m.writesToDepthBuffer = true
                m.readsFromDepthBuffer = true
                if texId >= 0, let img = images[Int(texId)] {
                    m.diffuse.contents = img
                    m.diffuse.wrapS = .repeat
                    m.diffuse.wrapT = .repeat
                    m.multiply.contents = color
                } else {
                    m.diffuse.contents = color
                }
                materialCache[key] = m
                return m
            }

            let grey = UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1)
            var entities: [SCNNode] = []
            var displayNames: [String: String] = [:]
            entities.reserveCapacity(N)

            for ei in 0..<N {
                // Keep non-mesh nodes too: their transforms and names belong to
                // the source hierarchy, even when they only group other nodes.
                let node = SCNNode()
                let nodeName = "SCM_Entity_\(ei)"
                node.name = nodeName
                displayNames[nodeName] = names[ei] ?? "Entity_\(ei)"
                node.castsShadow = false
                node.isHidden = flags[ei] & 0x01 == 0
                let q = rotations[ei]
                let lengthSquared = simd_length_squared(q)
                if lengthSquared.isFinite && lengthSquared > 0 {
                    node.simdOrientation = simd_quatf(vector: q / sqrt(lengthSquared))
                }
                node.simdPosition = positions[ei]
                node.simdScale = scales[ei]
                entities.append(node)

                let mid = Int(meshIds[ei])
                guard mid >= 0, mid < geometries.count, let shared = geoCache[mid] else { continue }

                // Entity colour only when the mesh has no vertex colours (web rule)
                let color: UIColor
                let colorKey: String
                if hasVertexColors[mid] == true {
                    color = .white
                    colorKey = "vc"
                } else {
                    let c = colors[ei]
                    let isBlank = c == SIMD4<UInt8>(0, 0, 0, 0)
                    let isWhite = c.x >= 254 && c.y >= 254 && c.z >= 254
                    if isBlank || isWhite {
                        color = grey
                        colorKey = "grey"
                    } else {
                        color = UIColor(red: CGFloat(c.x) / 255, green: CGFloat(c.y) / 255, blue: CGFloat(c.z) / 255, alpha: 1)
                        colorKey = "\(c.x)_\(c.y)_\(c.z)"
                    }
                }
                let matId = Int(materialIds[ei])
                let texId: Int32 = (matId >= 0 && matId < materials.count) ? materials[matId].textureId : -1

                // Shallow copy shares the vertex buffers; only the material differs
                let geom = shared.copy() as! SCNGeometry
                geom.materials = [material(texId: texId, color: color, colorKey: colorKey)]

                node.geometry = geom
            }

            // Invalid/self parents become roots. Break cyclic parent links
            // before attaching nodes, so SceneKit and layer traversal stay acyclic.
            var parentIndices = parents.enumerated().map { index, parent -> Int in
                let candidate = Int(parent)
                return candidate >= 0 && candidate < N && candidate != index ? candidate : -1
            }
            var states = [UInt8](repeating: 0, count: N)
            for start in 0..<N where states[start] == 0 {
                var path: [Int] = []
                var current = start
                while current >= 0 && states[current] == 0 {
                    states[current] = 1
                    path.append(current)
                    current = parentIndices[current]
                }
                if current >= 0 && states[current] == 1 {
                    parentIndices[current] = -1
                }
                for index in path { states[index] = 2 }
            }

            var children = [[Int]](repeating: [], count: N)
            var rootIndices: [Int] = []
            for ei in 0..<N {
                let parent = parentIndices[ei]
                if parent >= 0 {
                    children[parent].append(ei)
                    entities[parent].addChildNode(entities[ei])
                } else {
                    rootIndices.append(ei)
                }
            }

            // Bounds in the SCM source frame, using the complete parent TRS.
            // Group-only nodes do not enlarge the geometry bounds. Axis/map
            // rotation and scale are applied later by the root and offset.
            var bmin = SIMD3<Float>(repeating: .infinity)
            var bmax = SIMD3<Float>(repeating: -.infinity)
            var pending = rootIndices.reversed().map { ($0, matrix_identity_float4x4) }
            while let (ei, parentTransform) = pending.popLast() {
                let transform = parentTransform * entities[ei].simdTransform
                for child in children[ei].reversed() {
                    pending.append((child, transform))
                }
                let mid = Int(meshIds[ei])
                guard mid >= 0, mid < geometries.count, geoCache[mid] != nil else { continue }
                let g = geometries[mid]
                for cx in [g.bboxMin.x, g.bboxMax.x] {
                    for cy in [g.bboxMin.y, g.bboxMax.y] {
                        for cz in [g.bboxMin.z, g.bboxMax.z] {
                            let p = transform * SIMD4<Float>(cx, cy, cz, 1)
                            let v = SIMD3<Float>(p.x, p.y, p.z)
                            bmin = simd_min(bmin, v)
                            bmax = simd_max(bmax, v)
                        }
                    }
                }
            }

            return ParsedSCM(entities: entities, roots: rootIndices.map { entities[$0] },
                             displayNames: displayNames, drawGeometries: geoCache.count,
                             bboxMin: bmin, bboxMax: bmax,
                             coordinateSystem: coordinateSystem, georeference: georeference)
        }
    }

    // MARK: - Geometry

    private struct Streams {
        let positions: SCMBlockEntry
        let normals: SCMBlockEntry?
        let uvs: SCMBlockEntry?
        let indices: SCMBlockEntry
        let vertexColors: SCMBlockEntry?
    }

    private func buildGeometry(_ g: SCMGeometry, streams s: Streams, r: BinaryReader) -> SCNGeometry? {
        let vc = g.vertexCount
        let ic = g.indexCount

        // Positions: float32x3, offset in bytes
        let pStart = s.positions.offset + Int(g.vertexOffset)
        guard pStart + vc * 12 <= s.positions.offset + s.positions.size else { return nil }
        let posData = Data(bytes: r.bytes.baseAddress! + pStart, count: vc * 12)

        // Indices: uint32, offset in bytes
        let iStart = s.indices.offset + Int(g.indexOffset)
        guard iStart + ic * 4 <= s.indices.offset + s.indices.size else { return nil }
        var indices = [UInt32](repeating: 0, count: ic)
        for k in 0..<ic {
            let v = r.u32(iStart + k * 4)
            indices[k] = v < UInt32(vc) ? v : 0
        }

        var sources: [SCNGeometrySource] = [
            SCNGeometrySource(data: posData, semantic: .vertex, vectorCount: vc,
                              usesFloatComponents: true, componentsPerVector: 3,
                              bytesPerComponent: 4, dataOffset: 0, dataStride: 12)
        ]

        // Normals: float32x3 from the stream, else computed (web: computeVertexNormals)
        if let nb = s.normals, g.normalOffset != SCM_NO_OFFSET,
           nb.offset + Int(g.normalOffset) + vc * 12 <= nb.offset + nb.size {
            let nData = Data(bytes: r.bytes.baseAddress! + nb.offset + Int(g.normalOffset), count: vc * 12)
            sources.append(SCNGeometrySource(data: nData, semantic: .normal, vectorCount: vc,
                                             usesFloatComponents: true, componentsPerVector: 3,
                                             bytesPerComponent: 4, dataOffset: 0, dataStride: 12))
        } else {
            sources.append(computeNormals(r: r, posStart: pStart, vertexCount: vc, indices: indices))
        }

        // UVs: float32x2
        if let ub = s.uvs, g.uvOffset != SCM_NO_OFFSET,
           ub.offset + Int(g.uvOffset) + vc * 8 <= ub.offset + ub.size {
            let uData = Data(bytes: r.bytes.baseAddress! + ub.offset + Int(g.uvOffset), count: vc * 8)
            sources.append(SCNGeometrySource(data: uData, semantic: .texcoord, vectorCount: vc,
                                             usesFloatComponents: true, componentsPerVector: 2,
                                             bytesPerComponent: 4, dataOffset: 0, dataStride: 8))
        }

        // Vertex colours: uint8 RGB, offset in bytes → float RGB
        if let cb = s.vertexColors, g.vertexColorOffset != SCM_NO_OFFSET,
           cb.offset + Int(g.vertexColorOffset) + vc * 3 <= cb.offset + cb.size {
            let cStart = cb.offset + Int(g.vertexColorOffset)
            var cols = [Float](repeating: 0, count: vc * 3)
            for k in 0..<(vc * 3) { cols[k] = Float(r.u8(cStart + k)) / 255 }
            let cData = cols.withUnsafeBytes { Data($0) }
            sources.append(SCNGeometrySource(data: cData, semantic: .color, vectorCount: vc,
                                             usesFloatComponents: true, componentsPerVector: 3,
                                             bytesPerComponent: 4, dataOffset: 0, dataStride: 12))
        }

        let indexData = indices.withUnsafeBytes { Data($0) }
        let element = SCNGeometryElement(data: indexData, primitiveType: .triangles,
                                         primitiveCount: ic / 3, bytesPerIndex: 4)
        return SCNGeometry(sources: sources, elements: [element])
    }

    /// Smooth per-vertex normals (area weighted), for meshes without a normal stream.
    private func computeNormals(r: BinaryReader, posStart: Int, vertexCount vc: Int, indices: [UInt32]) -> SCNGeometrySource {
        var acc = [SIMD3<Float>](repeating: .zero, count: vc)
        func p(_ i: Int) -> SIMD3<Float> { r.f32x3(posStart + i * 12) }
        var t = 0
        while t + 2 < indices.count {
            let a = Int(indices[t]), b = Int(indices[t + 1]), c = Int(indices[t + 2])
            let n = simd_cross(p(b) - p(a), p(c) - p(a))
            acc[a] += n; acc[b] += n; acc[c] += n
            t += 3
        }
        let normals = acc.map { simd_length($0) > 0 ? simd_normalize($0) : SIMD3<Float>(0, 1, 0) }
        return SCNGeometrySource(normals: normals.map { SCNVector3($0.x, $0.y, $0.z) })
    }

    // MARK: - Textures

    private func decodeTextures(_ textures: [SCMTexture], pool: SCMBlockEntry?, raw: UnsafeRawBufferPointer) -> [Int: UIImage] {
        guard let pool = pool, !textures.isEmpty else { return [:] }
        var out: [Int: UIImage] = [:]
        for (i, t) in textures.enumerated() {
            guard t.dataOffset < pool.size else { continue }
            let size = Swift.min(t.dataSize, pool.size - t.dataOffset)
            let data = Data(bytes: raw.baseAddress! + pool.offset + t.dataOffset, count: size)
            if t.compression == 1 || t.compression == 2 {
                if let img = UIImage(data: data) { out[i] = img }
            } else if t.width > 0, t.height > 0, size >= t.width * t.height * 4,
                      let provider = CGDataProvider(data: data as CFData),
                      let cg = CGImage(width: t.width, height: t.height, bitsPerComponent: 8, bitsPerPixel: 32,
                                       bytesPerRow: t.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) {
                out[i] = UIImage(cgImage: cg)
            }
        }
        return out
    }

    // MARK: - Layer list

    /// The actual source tree, with stable lookup names independent of labels.
    private func buildLayers(_ roots: [SCNNode], displayNames: [String: String]) -> [LayerNode] {
        var ordered = roots.map { ($0, 0) }
        var cursor = 0
        while cursor < ordered.count {
            let (node, depth) = ordered[cursor]
            ordered.append(contentsOf: node.childNodes.map { ($0, depth + 1) })
            cursor += 1
        }

        var layersByName: [String: LayerNode] = [:]
        for (node, depth) in ordered.reversed() {
            guard let name = node.name else { continue }
            let children = node.childNodes.compactMap { child in
                child.name.flatMap { layersByName[$0] }
            }
            layersByName[name] = LayerNode(
                id: name,
                name: name,
                displayName: displayNames[name] ?? name,
                type: node.geometry == nil ? "Group" : "Geometry",
                depth: depth,
                children: children,
                isVisible: !node.isHidden,
                isExpanded: true
            )
        }
        return roots.compactMap { node in node.name.flatMap { layersByName[$0] } }
    }
}
