//
//  GSXFormat.swift
//  Quick3DDemo
//
//  Format .gsx v3 — port 1:1 từ client/.../gaussian-splatting/format/{format,quantize,decoder,codec}.ts (web)
//  và lambda/gsplat-converter/cpp/converter.cpp (hằng số, layout). File ghi ra ở đây đọc được bằng viewer web.
//
//  Layout:  [header 96 B][block index × 48 B][octree node × 72 B][block gzip nối liền]
//  Block:   u32 splatCount, u8 numStreams, rồi 5 stream: u8 id, u8 bits, u8 mode=0(raw), u32 n, u32 rawLen, u32×n LE
//

import Foundation
import Compression
import simd

enum GSX {

    static let magic: UInt32 = 0x3158_5347          // "GSX1"
    static let version: UInt16 = 3
    static let headerSize = 96
    static let indexEntrySize = 48
    static let nodeSize = 72
    static let flagGzip: UInt16 = 1 << 1
    static let noBlock: UInt32 = 0xffff_ffff
    static let noNode: Int32 = -1
    static let numStreams: UInt8 = 5

    // Hằng số quantize (quantize.ts / converter.cpp)
    static let shDcRange: Float = 4
    static let scaleMin: Float = -10
    static let scaleMax: Float = 5
    static let sqrtHalf: Float = 0.7071067811865476
    static let shC0: Float = 0.28209479177387814

    struct Header {
        var flags: UInt16 = flagGzip
        var splatCount = 0
        var blockCount = 0
        var blockSize = 0
        var nodeCount = 0
        var rootNodeId: Int32 = 0
        var aabbMin = SIMD3<Float>(repeating: 0)
        var aabbMax = SIMD3<Float>(repeating: 0)
        var posBits = 12, shBits = 8, scaleBits = 8, rotBits = 8, opaBits = 8
    }

    struct BlockEntry {
        var offset = 0
        var sizeCompressed = 0
        var sizeUncompressed = 0
        var aabbMin = SIMD3<Float>(repeating: 0)
        var aabbMax = SIMD3<Float>(repeating: 0)
    }

    struct Node {
        var blockId: UInt32 = noBlock
        var parentId: Int32 = noNode
        var childIds: [Int32] = Array(repeating: noNode, count: 8)
        var aabbMin = SIMD3<Float>(repeating: 0)
        var aabbMax = SIMD3<Float>(repeating: 0)
        var level = 0
    }

    struct Meta {
        let header: Header
        let blocks: [BlockEntry]
        let nodes: [Node]
    }

    /// Một block đã giải mã: toạ độ gốc của file (chưa lật trục), Σ 3D tách 2 nửa, màu + alpha (đã sigmoid).
    struct Block {
        let count: Int
        let positions: [SIMD3<Float>]
        let colors: [SIMD4<Float>]
        let cov0: [SIMD3<Float>]        // Σxx Σxy Σxz
        let cov1: [SIMD3<Float>]        // Σyy Σyz Σzz
    }

    enum FormatError: LocalizedError {
        case badMagic, badVersion(Int), truncated(String), badStream, gzip(String)
        var errorDescription: String? {
            switch self {
            case .badMagic: return "Không phải file .gsx (magic sai)"
            case .badVersion(let v): return ".gsx version \(v) không hỗ trợ (cần 3)"
            case .truncated(let w): return ".gsx thiếu dữ liệu: \(w)"
            case .badStream: return ".gsx block thiếu stream"
            case .gzip(let w): return "gunzip lỗi: \(w)"
            }
        }
    }

    // MARK: - Đọc meta

    static func readMeta(_ data: Data) throws -> Meta {
        guard data.count >= headerSize else { throw FormatError.truncated("header") }
        let header = try data.withUnsafeBytes { raw -> Header in
            guard raw.loadUnaligned(fromByteOffset: 0, as: UInt32.self) == magic else { throw FormatError.badMagic }
            let v = Int(raw.loadUnaligned(fromByteOffset: 4, as: UInt16.self))
            guard v == Int(version) else { throw FormatError.badVersion(v) }
            var h = Header()
            h.flags = raw.loadUnaligned(fromByteOffset: 6, as: UInt16.self)
            h.splatCount = Int(raw.loadUnaligned(fromByteOffset: 8, as: UInt32.self))
            h.blockCount = Int(raw.loadUnaligned(fromByteOffset: 12, as: UInt32.self))
            h.blockSize = Int(raw.loadUnaligned(fromByteOffset: 16, as: UInt32.self))
            h.aabbMin = SIMD3(raw.loadUnaligned(fromByteOffset: 20, as: Float.self), raw.loadUnaligned(fromByteOffset: 24, as: Float.self), raw.loadUnaligned(fromByteOffset: 28, as: Float.self))
            h.aabbMax = SIMD3(raw.loadUnaligned(fromByteOffset: 32, as: Float.self), raw.loadUnaligned(fromByteOffset: 36, as: Float.self), raw.loadUnaligned(fromByteOffset: 40, as: Float.self))
            h.posBits = Int(raw[44]); h.shBits = Int(raw[45]); h.scaleBits = Int(raw[46]); h.rotBits = Int(raw[47]); h.opaBits = Int(raw[48])
            h.nodeCount = Int(raw.loadUnaligned(fromByteOffset: 52, as: UInt32.self))
            h.rootNodeId = raw.loadUnaligned(fromByteOffset: 56, as: Int32.self)
            return h
        }
        let need = headerSize + header.blockCount * indexEntrySize + header.nodeCount * nodeSize
        guard data.count >= need else { throw FormatError.truncated("index/octree table") }

        var blocks: [BlockEntry] = []
        var nodes: [Node] = []
        blocks.reserveCapacity(header.blockCount)
        nodes.reserveCapacity(header.nodeCount)
        data.withUnsafeBytes { raw in
            for i in 0 ..< header.blockCount {
                let o = headerSize + i * indexEntrySize
                var e = BlockEntry()
                e.offset = Int(raw.loadUnaligned(fromByteOffset: o, as: Double.self))
                e.sizeCompressed = Int(raw.loadUnaligned(fromByteOffset: o + 8, as: UInt32.self))
                e.sizeUncompressed = Int(raw.loadUnaligned(fromByteOffset: o + 12, as: UInt32.self))
                e.aabbMin = SIMD3(raw.loadUnaligned(fromByteOffset: o + 16, as: Float.self), raw.loadUnaligned(fromByteOffset: o + 20, as: Float.self), raw.loadUnaligned(fromByteOffset: o + 24, as: Float.self))
                e.aabbMax = SIMD3(raw.loadUnaligned(fromByteOffset: o + 28, as: Float.self), raw.loadUnaligned(fromByteOffset: o + 32, as: Float.self), raw.loadUnaligned(fromByteOffset: o + 36, as: Float.self))
                blocks.append(e)
            }
            let base = headerSize + header.blockCount * indexEntrySize
            for i in 0 ..< header.nodeCount {
                let o = base + i * nodeSize
                var n = Node()
                n.blockId = raw.loadUnaligned(fromByteOffset: o, as: UInt32.self)
                n.parentId = raw.loadUnaligned(fromByteOffset: o + 4, as: Int32.self)
                for j in 0 ..< 8 { n.childIds[j] = raw.loadUnaligned(fromByteOffset: o + 8 + j * 4, as: Int32.self) }
                n.aabbMin = SIMD3(raw.loadUnaligned(fromByteOffset: o + 40, as: Float.self), raw.loadUnaligned(fromByteOffset: o + 44, as: Float.self), raw.loadUnaligned(fromByteOffset: o + 48, as: Float.self))
                n.aabbMax = SIMD3(raw.loadUnaligned(fromByteOffset: o + 52, as: Float.self), raw.loadUnaligned(fromByteOffset: o + 56, as: Float.self), raw.loadUnaligned(fromByteOffset: o + 60, as: Float.self))
                n.level = Int(raw.loadUnaligned(fromByteOffset: o + 64, as: UInt32.self))
                nodes.append(n)
            }
        }
        return Meta(header: header, blocks: blocks, nodes: nodes)
    }

    // MARK: - Giải mã block

    /// `bytes` = đúng `entry.sizeCompressed` byte của block.
    static func decodeBlock(_ bytes: Data, header: Header, entry: BlockEntry) throws -> Block {
        let payload = (header.flags & flagGzip) != 0 ? try gunzip(bytes, expected: entry.sizeUncompressed) : bytes
        return try payload.withUnsafeBytes { raw -> Block in
            var p = 0
            func u8() -> Int { defer { p += 1 }; return Int(raw[p]) }
            func u32() -> Int { defer { p += 4 }; return Int(raw.loadUnaligned(fromByteOffset: p, as: UInt32.self)) }
            let count = u32()
            let streams = u8()
            var values: [Int: (bits: Int, start: Int, n: Int)] = [:]
            for _ in 0 ..< streams {
                let id = u8(), bits = u8(), mode = u8(), n = u32()
                guard mode == 0 else { throw FormatError.badStream }        // huffman không dùng trong pipeline
                let rawLen = u32()
                values[id] = (bits, p, n)
                p += rawLen
            }
            guard let sPos = values[0], let sSh = values[1], let sSc = values[2], let sRot = values[3], let sOpa = values[4] else { throw FormatError.badStream }
            func q(_ s: (bits: Int, start: Int, n: Int), _ i: Int) -> Float {
                Float(raw.loadUnaligned(fromByteOffset: s.start + i * 4, as: Int32.self))
            }

            var positions = [SIMD3<Float>](); positions.reserveCapacity(count)
            var colors = [SIMD4<Float>](); colors.reserveCapacity(count)
            var cov0 = [SIMD3<Float>](); cov0.reserveCapacity(count)
            var cov1 = [SIMD3<Float>](); cov1.reserveCapacity(count)

            let pMax = Float((1 << sPos.bits) - 1), shMax = Float((1 << sSh.bits) - 1), scMax = Float((1 << sSc.bits) - 1)
            let rotMax = Float((1 << sRot.bits) - 1), opMax = Float((1 << sOpa.bits) - 1)
            let ext = entry.aabbMax - entry.aabbMin
            let scaleRange = scaleMax - scaleMin

            for i in 0 ..< count {
                // position: lượng tử theo AABB của block
                let pos = entry.aabbMin + SIMD3(q(sPos, i * 3), q(sPos, i * 3 + 1), q(sPos, i * 3 + 2)) / pMax * ext
                // màu SH bậc 0
                let dc = SIMD3(q(sSh, i * 3), q(sSh, i * 3 + 1), q(sSh, i * 3 + 2)) / shMax * (2 * shDcRange) - shDcRange
                let rgb = simd_clamp(dc * shC0 + 0.5, SIMD3(repeating: 0), SIMD3(repeating: 1))
                let alpha = q(sOpa, i) / opMax
                // scale (log) → exp
                let s = SIMD3(exp(scaleMin + q(sSc, i * 3) / scMax * scaleRange),
                              exp(scaleMin + q(sSc, i * 3 + 1) / scMax * scaleRange),
                              exp(scaleMin + q(sSc, i * 3 + 2) / scMax * scaleRange))
                // rotation: smallest-three (bits < 16) hoặc 4 thành phần
                var qv = SIMD4<Float>(repeating: 0)      // rot_0..3 = (w, x, y, z)
                if sRot.bits >= 16 {
                    qv = SIMD4(q(sRot, i * 4), q(sRot, i * 4 + 1), q(sRot, i * 4 + 2), q(sRot, i * 4 + 3)) / rotMax * 2 - 1
                } else {
                    let maxIdx = Int(q(sRot, i * 4)) & 3
                    var others: [Float] = [], sumSq: Float = 0
                    for k in 1 ... 3 { let v = q(sRot, i * 4 + k) / rotMax * (2 * sqrtHalf) - sqrtHalf; others.append(v); sumSq += v * v }
                    let largest = sqrt(max(0, 1 - sumSq))
                    var o = 0
                    for j in 0 ..< 4 { if j == maxIdx { qv[j] = largest } else { qv[j] = others[o]; o += 1 } }
                }
                var quat = simd_quatf(ix: qv[1], iy: qv[2], iz: qv[3], r: qv[0])
                if simd_length(quat.vector) < 1e-6 { quat = simd_quatf(angle: 0, axis: SIMD3(0, 1, 0)) }
                quat = simd_normalize(quat)
                let m = simd_float3x3(quat) * simd_float3x3(diagonal: s)
                let sigma = m * m.transpose

                positions.append(pos)
                colors.append(SIMD4(rgb, alpha))
                cov0.append(SIMD3(sigma.columns.0.x, sigma.columns.1.x, sigma.columns.2.x))
                cov1.append(SIMD3(sigma.columns.1.y, sigma.columns.2.y, sigma.columns.2.z))
            }
            return Block(count: count, positions: positions, colors: colors, cov0: cov0, cov1: cov1)
        }
    }

    /// Giải mã toàn bộ block của một file .gsx (không LOD): trả về mảng nối liền theo thứ tự block.
    static func decodeAll(_ data: Data, progress: ((Int, Int) -> Void)? = nil) throws -> (meta: Meta, block: Block) {
        let meta = try readMeta(data)
        var positions = [SIMD3<Float>](), colors = [SIMD4<Float>](), cov0 = [SIMD3<Float>](), cov1 = [SIMD3<Float>]()
        positions.reserveCapacity(meta.header.splatCount); colors.reserveCapacity(meta.header.splatCount)
        cov0.reserveCapacity(meta.header.splatCount); cov1.reserveCapacity(meta.header.splatCount)
        for (i, entry) in meta.blocks.enumerated() where entry.sizeCompressed > 0 {
            guard entry.offset + entry.sizeCompressed <= data.count else { throw FormatError.truncated("block \(i)") }
            let b = try decodeBlock(data.subdata(in: entry.offset ..< entry.offset + entry.sizeCompressed), header: meta.header, entry: entry)
            positions += b.positions; colors += b.colors; cov0 += b.cov0; cov1 += b.cov1
            if i % 256 == 0 { progress?(i, meta.blocks.count) }
        }
        return (meta, Block(count: positions.count, positions: positions, colors: colors, cov0: cov0, cov1: cov1))
    }

    // MARK: - gzip (framework Compression chỉ làm raw deflate → tự bọc/bóc khung gzip)

    static func gunzip(_ data: Data, expected: Int) throws -> Data {
        guard data.count >= 18, data[data.startIndex] == 0x1f, data[data.startIndex + 1] == 0x8b, data[data.startIndex + 2] == 8 else {
            throw FormatError.gzip("không phải gzip")
        }
        let flg = data[data.startIndex + 3]
        var p = 10
        if flg & 4 != 0 { let xlen = Int(data[data.startIndex + p]) | Int(data[data.startIndex + p + 1]) << 8; p += 2 + xlen }
        if flg & 8 != 0 { while data[data.startIndex + p] != 0 { p += 1 }; p += 1 }
        if flg & 16 != 0 { while data[data.startIndex + p] != 0 { p += 1 }; p += 1 }
        if flg & 2 != 0 { p += 2 }
        let deflateLen = data.count - p - 8
        guard deflateLen > 0 else { throw FormatError.gzip("rỗng") }
        var out = Data(count: expected)
        let written = out.withUnsafeMutableBytes { dst -> Int in
            data.withUnsafeBytes { src -> Int in
                compression_decode_buffer(dst.baseAddress!.assumingMemoryBound(to: UInt8.self), expected,
                                          src.baseAddress!.advanced(by: p).assumingMemoryBound(to: UInt8.self), deflateLen,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        guard written == expected else { throw FormatError.gzip("giải ra \(written) B, mong \(expected) B") }
        return out
    }

    static func gzip(_ data: Data) -> Data {
        let cap = data.count + data.count / 8 + 1024
        var body = Data(count: cap)
        let n = body.withUnsafeMutableBytes { dst -> Int in
            data.withUnsafeBytes { src -> Int in
                compression_encode_buffer(dst.baseAddress!.assumingMemoryBound(to: UInt8.self), cap,
                                          src.baseAddress!.assumingMemoryBound(to: UInt8.self), data.count,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        body.count = n
        var out = Data([0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 3])      // header: deflate, không flag, OS=unix
        out.append(body)
        var crc = crc32(data).littleEndian
        var size = UInt32(truncatingIfNeeded: data.count).littleEndian
        withUnsafeBytes(of: &crc) { out.append(contentsOf: $0) }
        withUnsafeBytes(of: &size) { out.append(contentsOf: $0) }
        return out
    }

    private static let crcTable: [UInt32] = (0 ..< 256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0 ..< 8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func crc32(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xffff_ffff
        data.withUnsafeBytes { raw in
            for b in raw { c = crcTable[Int((c ^ UInt32(b)) & 0xff)] ^ (c >> 8) }
        }
        return c ^ 0xffff_ffff
    }
}
