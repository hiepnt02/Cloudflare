//
//  GsxFormat.swift
//  Quick3D
//

import Compression
import Foundation
import simd

// .gsx v3 reader — port of client/src/ts/viewer/gaussian-splatting/format/{format,decoder,
// quantize,huffman}.ts. Decodes a block straight into GPU-ready splats.

enum GsxError: Error, CustomStringConvertible {
    case badMagic(UInt32), badVersion(Int), truncated(String), gzip, huffman(String), missingStream, tooManySplats(Int)

    var description: String {
        switch self {
        case .badMagic(let m): return String(format: "bad magic 0x%08x", m)
        case .badVersion(let v): return "unsupported version \(v)"
        case .truncated(let what): return "truncated \(what)"
        case .gzip: return "gzip decode failed"
        case .huffman(let why): return "huffman: \(why)"
        case .missingStream: return "block is missing a stream"
        case .tooManySplats(let n): return "block has \(n) splats, more than the slot allows"
        }
    }
}

struct GsxHeader {
    static let size = 96
    static let magic: UInt32 = 0x3158_5347   // "GSX1"
    static let version = 3
    static let flagHuffman: UInt16 = 1 << 0
    static let flagGzip: UInt16 = 1 << 1

    var flags: UInt16
    var splatCount: Int
    var blockCount: Int
    var blockSize: Int
    var nodeCount: Int
    var aabbMin: SIMD3<Float>
    var aabbMax: SIMD3<Float>

    /// Bytes of block index + node table that follow the header.
    var tablesSize: Int { blockCount * GsxBlockEntry.size + nodeCount * GsxNode.size }

    init(_ data: Data) throws {
        guard data.count >= Self.size else { throw GsxError.truncated("header") }
        let r = ByteReader(data)
        let magic = r.u32(0)
        guard magic == Self.magic else { throw GsxError.badMagic(magic) }
        let version = Int(r.u16(4))
        guard version == Self.version else { throw GsxError.badVersion(version) }
        flags = r.u16(6)
        splatCount = Int(r.u32(8))
        blockCount = Int(r.u32(12))
        blockSize = Int(r.u32(16))
        aabbMin = r.float3(20)
        aabbMax = r.float3(32)
        nodeCount = Int(r.u32(52))
    }
}

struct GsxBlockEntry {
    static let size = 48
    var offset: Int
    var sizeCompressed: Int
    var sizeUncompressed: Int
    var aabbMin: SIMD3<Float>
    var aabbMax: SIMD3<Float>
}

struct GsxNode {
    static let size = 72
    static let noBlock: UInt32 = 0xFFFF_FFFF
    var blockId: UInt32
    var level: Int
    var aabbMin: SIMD3<Float>
    var aabbMax: SIMD3<Float>
}

struct GsxMeta {
    let header: GsxHeader
    let blocks: [GsxBlockEntry]
    let nodes: [GsxNode]

    /// `tables` = the bytes right after the header (block index, then node table).
    init(header: GsxHeader, tables: Data) throws {
        guard tables.count >= header.tablesSize else { throw GsxError.truncated("tables") }
        let r = ByteReader(tables)
        var blocks: [GsxBlockEntry] = []
        blocks.reserveCapacity(header.blockCount)
        for i in 0..<header.blockCount {
            let o = i * GsxBlockEntry.size
            blocks.append(GsxBlockEntry(offset: Int(r.f64(o)), sizeCompressed: Int(r.u32(o + 8)),
                                        sizeUncompressed: Int(r.u32(o + 12)),
                                        aabbMin: r.float3(o + 16), aabbMax: r.float3(o + 28)))
        }
        let nodeBase = header.blockCount * GsxBlockEntry.size
        var nodes: [GsxNode] = []
        nodes.reserveCapacity(header.nodeCount)
        for i in 0..<header.nodeCount {
            let o = nodeBase + i * GsxNode.size
            nodes.append(GsxNode(blockId: r.u32(o), level: Int(r.u32(o + 64)),
                                 aabbMin: r.float3(o + 40), aabbMax: r.float3(o + 52)))
        }
        self.header = header
        self.blocks = blocks
        self.nodes = nodes
    }
}

/// Where a decoded block goes: splat `i` is written at global index `target(i)`.
struct GsxBlockTarget {
    /// GPU splats, `GsxDecoder.splatStride` bytes each.
    let splats: UnsafeMutableRawPointer
    /// xyz per splat, for the CPU depth sort.
    let positions: UnsafeMutablePointer<Float>
    let pages: [Int]
    let pageSize: Int

    @inline(__always) func index(_ i: Int) -> Int { pages[i / pageSize] * pageSize + i % pageSize }
}

enum GsxDecoder {
    /// packed_float3 position, uint rgba8 (sRGB colour, alpha = opacity),
    /// packed_float3 Σ00 Σ01 Σ02, packed_float3 Σ11 Σ12 Σ22. Float, not half: data is in
    /// metres and small splats have σ² ≈ 1e-6, deep in half's subnormal range.
    static let splatStride = 40

    private static let streamPosition = 0, streamShDc = 1, streamScale = 2, streamRotation = 3, streamOpacity = 4
    private static let shDcRange: Float = 4
    private static let scaleMin: Float = -10, scaleMax: Float = 5
    private static let shC0: Float = 0.28209479177387814

    /// Decodes one block (the raw Range bytes) into `target`. Returns the splat count.
    static func decode(compressed: Data, entry: GsxBlockEntry, flags: UInt16, maxSplats: Int,
                       target: (Int) throws -> GsxBlockTarget) throws -> Int {
        let payload = try payloadBytes(compressed, entry: entry, flags: flags)
        let r = ByteReader(payload)
        let count = Int(r.u32(0))
        guard count <= maxSplats else { throw GsxError.tooManySplats(count) }
        let streamCount = Int(r.u8(4))
        var p = 5
        var streams: [Int: (bits: Int, values: [Int32])] = [:]
        for _ in 0..<streamCount {
            let id = Int(r.u8(p)), bits = Int(r.u8(p + 1)), mode = r.u8(p + 2)
            let symbols = Int(r.u32(p + 3))
            p += 7
            if mode == 1 {
                let tableLen = Int(r.u32(p)); p += 4
                let table = payload.subdata(in: p..<(p + tableLen)); p += tableLen
                let codeLen = Int(r.u32(p)); p += 4
                let code = payload.subdata(in: p..<(p + codeLen)); p += codeLen
                streams[id] = (bits, try huffmanDecode(code: code, table: table, count: symbols))
            } else {
                let rawLen = Int(r.u32(p)); p += 4
                guard rawLen >= symbols * 4, p + rawLen <= payload.count else { throw GsxError.truncated("raw stream") }
                var values = [Int32](repeating: 0, count: symbols)
                payload.withUnsafeBytes { src in
                    values.withUnsafeMutableBytes { dst in
                        dst.copyMemory(from: UnsafeRawBufferPointer(rebasing: src[p..<(p + symbols * 4)]))
                    }
                }
                p += rawLen
                streams[id] = (bits, values)
            }
        }
        guard let pos = streams[streamPosition], let sh = streams[streamShDc], let scale = streams[streamScale],
              let rot = streams[streamRotation], let opa = streams[streamOpacity],
              pos.values.count >= count * 3, sh.values.count >= count * 3, scale.values.count >= count * 3,
              rot.values.count >= count * 4, opa.values.count >= count else { throw GsxError.missingStream }

        let t = try target(count)
        let posMax = Float((1 << pos.bits) - 1), shMax = Float((1 << sh.bits) - 1)
        let scaleMaxQ = Float((1 << scale.bits) - 1), rotMax = Float((1 << rot.bits) - 1)
        let opaMax = Float((1 << opa.bits) - 1)
        let extent = entry.aabbMax - entry.aabbMin
        let sqrtHalf: Float = 0.70710678

        for i in 0..<count {
            let position = entry.aabbMin + SIMD3<Float>(Float(pos.values[i * 3]), Float(pos.values[i * 3 + 1]),
                                                        Float(pos.values[i * 3 + 2])) / posMax * extent
            var color = SIMD3<Float>(Float(sh.values[i * 3]), Float(sh.values[i * 3 + 1]), Float(sh.values[i * 3 + 2]))
            color = color / shMax * (2 * shDcRange) - shDcRange
            color = simd_clamp(shC0 * color + 0.5, SIMD3<Float>(repeating: 0), SIMD3<Float>(repeating: 1))
            // Stored as a logit by the encoder; the renderer's sigmoid gives back the quantised value.
            let alpha = min(max(Float(opa.values[i]) / opaMax, 0), 1)
            let logScale = SIMD3<Float>(Float(scale.values[i * 3]), Float(scale.values[i * 3 + 1]),
                                        Float(scale.values[i * 3 + 2])) / scaleMaxQ * (scaleMax - scaleMin) + scaleMin
            let s = SIMD3<Float>(exp(logScale.x), exp(logScale.y), exp(logScale.z))

            // Quaternion in file order (w, x, y, z), INRIA 3DGS convention.
            var q = SIMD4<Float>(repeating: 0)
            if rot.bits >= 16 {
                for c in 0..<4 { q[c] = Float(rot.values[i * 4 + c]) / rotMax * 2 - 1 }
            } else {
                let largestIndex = Int(rot.values[i * 4] & 3)
                var others = SIMD3<Float>()
                for c in 0..<3 { others[c] = Float(rot.values[i * 4 + 1 + c]) / rotMax * (2 * sqrtHalf) - sqrtHalf }
                let largest = sqrt(max(0, 1 - simd_length_squared(others)))
                var o = 0
                for c in 0..<4 {
                    if c == largestIndex { q[c] = largest } else { q[c] = others[o]; o += 1 }
                }
            }
            let n = simd_length(q)
            q = n > 0 ? q / n : SIMD4<Float>(1, 0, 0, 0)
            let (w, x, y, z) = (q[0], q[1], q[2], q[3])
            let rotation = simd_float3x3(
                SIMD3(1 - 2 * (y * y + z * z), 2 * (x * y + w * z), 2 * (x * z - w * y)),
                SIMD3(2 * (x * y - w * z), 1 - 2 * (x * x + z * z), 2 * (y * z + w * x)),
                SIMD3(2 * (x * z + w * y), 2 * (y * z - w * x), 1 - 2 * (x * x + y * y)))
            let m = rotation * simd_float3x3(diagonal: s)
            let sigma = m * m.transpose

            let g = t.index(i)
            let dst = t.splats.advanced(by: g * splatStride)
            dst.storeBytes(of: position.x, toByteOffset: 0, as: Float.self)
            dst.storeBytes(of: position.y, toByteOffset: 4, as: Float.self)
            dst.storeBytes(of: position.z, toByteOffset: 8, as: Float.self)
            let rgba = UInt32(color.x * 255 + 0.5) | UInt32(color.y * 255 + 0.5) << 8
                | UInt32(color.z * 255 + 0.5) << 16 | UInt32(alpha * 255 + 0.5) << 24
            dst.storeBytes(of: rgba, toByteOffset: 12, as: UInt32.self)
            dst.storeBytes(of: sigma[0][0], toByteOffset: 16, as: Float.self)
            dst.storeBytes(of: sigma[0][1], toByteOffset: 20, as: Float.self)
            dst.storeBytes(of: sigma[0][2], toByteOffset: 24, as: Float.self)
            dst.storeBytes(of: sigma[1][1], toByteOffset: 28, as: Float.self)
            dst.storeBytes(of: sigma[1][2], toByteOffset: 32, as: Float.self)
            dst.storeBytes(of: sigma[2][2], toByteOffset: 36, as: Float.self)
            t.positions[g * 3] = position.x
            t.positions[g * 3 + 1] = position.y
            t.positions[g * 3 + 2] = position.z
        }
        return count
    }

    private static func payloadBytes(_ compressed: Data, entry: GsxBlockEntry, flags: UInt16) throws -> Data {
        guard compressed.count >= entry.sizeCompressed else { throw GsxError.truncated("block") }
        // Rebased copy: offsets below are relative to the payload start.
        if flags & GsxHeader.flagGzip == 0 { return Data(compressed.prefix(entry.sizeCompressed)) }
        return try gunzip(compressed, expectedSize: entry.sizeUncompressed)
    }

    /// gzip member → bytes, via Apple's raw-DEFLATE decoder.
    static func gunzip(_ data: Data, expectedSize: Int) throws -> Data {
        try data.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Data in
            let b = src.bindMemory(to: UInt8.self)
            guard b.count > 18, b[0] == 0x1F, b[1] == 0x8B, b[2] == 8 else { throw GsxError.gzip }
            let flg = b[3]
            var p = 10
            if flg & 4 != 0 { p += 2 + (Int(b[p]) | Int(b[p + 1]) << 8) }
            if flg & 8 != 0 { while p < b.count, b[p] != 0 { p += 1 }; p += 1 }
            if flg & 16 != 0 { while p < b.count, b[p] != 0 { p += 1 }; p += 1 }
            if flg & 2 != 0 { p += 2 }
            guard p < b.count - 8, let base = b.baseAddress else { throw GsxError.gzip }
            var out = Data(count: expectedSize)
            let written = out.withUnsafeMutableBytes { dst in
                compression_decode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, expectedSize,
                                          base + p, b.count - p - 8, nil, COMPRESSION_ZLIB)
            }
            guard written == expectedSize else { throw GsxError.gzip }
            return out
        }
    }

    /// Canonical Huffman (see huffman.ts for the wire format).
    static func huffmanDecode(code: Data, table: Data, count: Int) throws -> [Int32] {
        let r = ByteReader(table)
        guard table.count >= 8 else { throw GsxError.huffman("table too small") }
        let n = Int(r.u32(0)), total = Int(r.u32(4))
        guard total == count else { throw GsxError.huffman("count \(count) vs table \(total)") }
        guard table.count >= 8 + n * 3 else { throw GsxError.huffman("table truncated") }
        var entries: [(symbol: Int32, length: Int)] = (0..<n).map { (Int32(r.u16(8 + $0 * 3)), Int(r.u8(8 + $0 * 3 + 2))) }
        var out = [Int32](repeating: 0, count: count)
        if count == 0 { return out }
        if entries.count == 1 { return [Int32](repeating: entries[0].symbol, count: count) }
        entries.sort { $0.length != $1.length ? $0.length < $1.length : $0.symbol < $1.symbol }

        // Canonical codes, grouped by length: first code, first index and size of each length.
        let maxLength = 32
        var firstCode = [Int](repeating: 0, count: maxLength + 1)
        var firstIndex = [Int](repeating: 0, count: maxLength + 1)
        var lengthCount = [Int](repeating: 0, count: maxLength + 1)
        var symbols: [Int32] = []
        var canonical = 0, prevLength = 0
        for e in entries where e.length > 0 {
            guard e.length <= maxLength else { throw GsxError.huffman("code too long") }
            canonical = prevLength == 0 ? 0 : (canonical + 1) << (e.length - prevLength)
            if lengthCount[e.length] == 0 {
                firstCode[e.length] = canonical
                firstIndex[e.length] = symbols.count
            }
            lengthCount[e.length] += 1
            symbols.append(e.symbol)
            prevLength = e.length
        }
        try readCodes(code, symbols: symbols, firstCode: firstCode, firstIndex: firstIndex,
                      lengthCount: lengthCount, into: &out)
        return out
    }

    private static func readCodes(_ code: Data, symbols: [Int32], firstCode: [Int], firstIndex: [Int],
                                  lengthCount: [Int], into out: inout [Int32]) throws {
        let count = out.count
        try code.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let bytes = raw.bindMemory(to: UInt8.self)
            var bit = 0
            for n in 0..<count {
                var acc = 0, length = 0
                while true {
                    guard bit >> 3 < bytes.count else { throw GsxError.huffman("unexpected end of stream") }
                    acc = (acc << 1) | Int((bytes[bit >> 3] >> (7 - UInt8(bit & 7))) & 1)
                    bit += 1
                    length += 1
                    guard length <= 32 else { throw GsxError.huffman("invalid code") }
                    let offset = acc - firstCode[length]
                    if lengthCount[length] > 0, offset >= 0, offset < lengthCount[length] {
                        out[n] = symbols[firstIndex[length] + offset]
                        break
                    }
                }
            }
        }
    }
}

/// Little-endian reads from `Data` at offsets relative to its start.
struct ByteReader {
    let data: Data
    init(_ data: Data) { self.data = data }

    @inline(__always) private func load<T>(_ offset: Int, _: T.Type) -> T {
        data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: T.self) }
    }
    func u8(_ o: Int) -> UInt8 { load(o, UInt8.self) }
    func u16(_ o: Int) -> UInt16 { UInt16(littleEndian: load(o, UInt16.self)) }
    func u32(_ o: Int) -> UInt32 { UInt32(littleEndian: load(o, UInt32.self)) }
    func f32(_ o: Int) -> Float { Float(bitPattern: u32(o)) }
    func f64(_ o: Int) -> Double { Double(bitPattern: UInt64(littleEndian: load(o, UInt64.self))) }
    func float3(_ o: Int) -> SIMD3<Float> { SIMD3(f32(o), f32(o + 4), f32(o + 8)) }
}
