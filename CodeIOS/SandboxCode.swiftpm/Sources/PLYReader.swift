//
//  PLYReader.swift
//  Quick3DDemo
//
//  Đọc file .ply (binary little/big-endian hoặc ascii) thành mảng vị trí + màu cho MetalPointCloud.
//  Hỗ trợ cả PLY thường (x y z + red green blue) lẫn **Gaussian splatting** (x y z + f_dc_0..2 + opacity):
//    màu  = 0.5 + SH_C0 · f_dc          (hệ số spherical harmonics bậc 0 → màu cơ bản)
//    bỏ điểm có sigmoid(opacity) < minOpacity (splat gần như trong suốt)
//  Splat được vẽ như điểm, KHÔNG phải ellipsoid trộn alpha — đủ để nhìn hình và đặt vào AR.
//
//  3DGS huấn luyện từ COLMAP nên trục Y hướng xuống, Z hướng tới → lật Y, Z cho khớp SceneKit (Y lên).
//  Toạ độ được dời: tâm XZ về 0, "sàn" (phân vị 2% của Y) về 0 — giống cách ModelLoader đặt model.
//

import Foundation
import simd

enum PLYReader {

    struct Result {
        let positions: [SIMD3<Float>]
        let colors: [SIMD3<Float>]
        let totalVertices: Int
        let isGaussianSplat: Bool
        let extent: SIMD3<Float>          // kích thước robust (phân vị 2%…98%) sau khi dời
    }

    enum ReadError: LocalizedError {
        case badHeader
        case unsupported(String)
        case noVertices

        var errorDescription: String? {
            switch self {
            case .badHeader: return "Không đọc được header PLY"
            case .unsupported(let what): return "PLY không hỗ trợ: \(what)"
            case .noVertices: return "PLY không có điểm nào (hoặc toàn opacity thấp)"
            }
        }
    }

    /// Giới hạn số điểm đưa lên GPU; file nhiều hơn sẽ được lấy mẫu đều.
    static let maxPoints = 1_000_000
    static let shC0: Float = 0.28209479

    private enum Format { case ascii, binaryLE, binaryBE }

    private struct Property {
        let name: String
        let size: Int
        let isFloat: Bool
        let isSigned: Bool
        var offset = 0
    }

    private struct Header {
        var format = Format.binaryLE
        var vertexCount = 0
        var properties: [Property] = []
        var rowStride = 0
        var length = 0
    }

    // MARK: - API

    /// `flipYZ` nil = tự quyết: lật nếu là Gaussian splatting.
    static func load(url: URL, flipYZ: Bool? = nil, minOpacity: Float = 0.1) throws -> Result {
        let data = try Data(contentsOf: url, options: [.alwaysMapped])
        let header = try parseHeader(data)

        func index(_ name: String) -> Int? { header.properties.firstIndex { $0.name == name } }
        guard let ix = index("x"), let iy = index("y"), let iz = index("z") else {
            throw ReadError.unsupported("thiếu x/y/z")
        }
        let dc = [index("f_dc_0"), index("f_dc_1"), index("f_dc_2")].compactMap { $0 }
        let rgb = [index("red") ?? index("r"), index("green") ?? index("g"), index("blue") ?? index("b")].compactMap { $0 }
        let isSplat = dc.count == 3
        let iOpacity = index("opacity")
        let flip = flipYZ ?? isSplat

        let step = max(1, Int((Double(header.vertexCount) / Double(maxPoints)).rounded(.up)))
        var positions: [SIMD3<Float>] = []
        var colors: [SIMD3<Float>] = []
        positions.reserveCapacity(header.vertexCount / step + 1)
        colors.reserveCapacity(header.vertexCount / step + 1)

        // Cùng một hàm xử lý một hàng cho cả binary lẫn ascii: `get(i)` trả giá trị property i
        func take(_ get: (Int) -> Float) {
            if let iOpacity {
                let a = 1 / (1 + exp(-get(iOpacity)))          // sigmoid
                if a < minOpacity { return }
            }
            var p = SIMD3(get(ix), get(iy), get(iz))
            if flip { p = SIMD3(p.x, -p.y, -p.z) }
            guard p.x.isFinite, p.y.isFinite, p.z.isFinite else { return }
            positions.append(p)

            if isSplat {
                let c = SIMD3(get(dc[0]), get(dc[1]), get(dc[2])) * shC0 + 0.5
                colors.append(simd_clamp(c, SIMD3(repeating: 0), SIMD3(repeating: 1)))
            } else if rgb.count == 3 {
                let r = get(rgb[0]), g = get(rgb[1]), b = get(rgb[2])
                let scale: Float = header.properties[rgb[0]].isFloat ? 1 : 1 / 255
                colors.append(SIMD3(r, g, b) * scale)
            } else {
                colors.append(SIMD3(repeating: 0.8))        // tô theo chiều cao ở dưới
            }
        }

        switch header.format {
        case .binaryLE, .binaryBE:
            let bigEndian = header.format == .binaryBE
            let needed = header.length + header.vertexCount * header.rowStride
            guard data.count >= needed else { throw ReadError.unsupported("file ngắn hơn header khai báo") }
            data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
                for row in stride(from: 0, to: header.vertexCount, by: step) {
                    let base = header.length + row * header.rowStride
                    take { i in
                        let prop = header.properties[i]
                        return value(raw, base + prop.offset, prop, bigEndian: bigEndian)
                    }
                }
            }
        case .ascii:
            // Chỉ hợp với file nhỏ; tách dòng sau header
            let body = data.subdata(in: header.length ..< data.count)
            guard let text = String(data: body, encoding: .utf8) else { throw ReadError.unsupported("ascii không phải UTF-8") }
            var row = 0
            text.enumerateLines { line, stop in
                defer { row += 1 }
                if row >= header.vertexCount { stop = true; return }
                if row % step != 0 { return }
                let tokens = line.split(separator: " ", omittingEmptySubsequences: true)
                guard tokens.count >= header.properties.count else { return }
                take { i in Float(tokens[i]) ?? 0 }
            }
        }

        guard !positions.isEmpty else { throw ReadError.noVertices }

        // Dời về gốc theo phân vị (tránh điểm rác ở xa kéo lệch tâm)
        let (lo, mid, hi) = percentiles(positions)
        let center = SIMD3(mid.x, lo.y, mid.z)
        for i in positions.indices { positions[i] -= center }

        if !isSplat && rgb.count != 3 {
            let h = max(hi.y - lo.y, 0.001)
            for i in positions.indices {
                let t = simd_clamp(positions[i].y / h, 0, 1)
                colors[i] = SIMD3(0.2 + 0.7 * t, 0.5, 0.9 - 0.7 * t)
            }
        }

        return Result(positions: positions, colors: colors,
                      totalVertices: header.vertexCount, isGaussianSplat: isSplat, extent: hi - lo)
    }

    // MARK: - Header

    private static func parseHeader(_ data: Data) throws -> Header {
        let probe = data.prefix(1 << 16)
        guard let text = String(data: probe, encoding: .isoLatin1),
              text.hasPrefix("ply"),
              let endRange = text.range(of: "end_header")
        else { throw ReadError.badHeader }

        // Độ dài header = tới hết dòng "end_header" (kể cả \n hoặc \r\n)
        var end = text.distance(from: text.startIndex, to: endRange.upperBound)
        while end < probe.count, probe[probe.startIndex + end] != 0x0A { end += 1 }
        end += 1

        var header = Header()
        header.length = end
        var inVertex = false
        var sawVertex = false

        for rawLine in text[..<endRange.lowerBound].split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let parts = rawLine.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard let key = parts.first else { continue }
            switch key {
            case "format":
                switch parts.dropFirst().first {
                case "ascii": header.format = .ascii
                case "binary_little_endian": header.format = .binaryLE
                case "binary_big_endian": header.format = .binaryBE
                default: throw ReadError.badHeader
                }
            case "element":
                guard parts.count >= 3 else { throw ReadError.badHeader }
                if parts[1] == "vertex" {
                    guard !sawVertex else { throw ReadError.unsupported("nhiều element vertex") }
                    header.vertexCount = Int(parts[2]) ?? 0
                    inVertex = true
                    sawVertex = true
                } else {
                    // Element khác (face…) đứng TRƯỚC vertex thì không biết nhảy qua bao nhiêu byte
                    if !sawVertex && header.format != .ascii && (Int(parts[2]) ?? 0) > 0 {
                        throw ReadError.unsupported("element \(parts[1]) đứng trước vertex")
                    }
                    inVertex = false
                }
            case "property":
                guard inVertex else { continue }
                guard parts.count >= 3 else { throw ReadError.badHeader }
                if parts[1] == "list" { throw ReadError.unsupported("property list trong vertex") }
                guard let (size, isFloat, isSigned) = typeInfo(parts[1]) else {
                    throw ReadError.unsupported("kiểu \(parts[1])")
                }
                var prop = Property(name: parts[2], size: size, isFloat: isFloat, isSigned: isSigned)
                prop.offset = header.rowStride
                header.rowStride += size
                header.properties.append(prop)
            default:
                continue        // comment, obj_info…
            }
        }
        guard sawVertex, !header.properties.isEmpty else { throw ReadError.badHeader }
        return header
    }

    private static func typeInfo(_ t: String) -> (Int, Bool, Bool)? {
        switch t {
        case "char", "int8": return (1, false, true)
        case "uchar", "uint8": return (1, false, false)
        case "short", "int16": return (2, false, true)
        case "ushort", "uint16": return (2, false, false)
        case "int", "int32": return (4, false, true)
        case "uint", "uint32": return (4, false, false)
        case "float", "float32": return (4, true, true)
        case "double", "float64": return (8, true, true)
        default: return nil
        }
    }

    // MARK: - Đọc một giá trị nhị phân

    private static func value(_ raw: UnsafeRawBufferPointer, _ off: Int, _ p: Property, bigEndian: Bool) -> Float {
        switch (p.size, p.isFloat, p.isSigned) {
        case (4, true, _):
            var bits = raw.loadUnaligned(fromByteOffset: off, as: UInt32.self)
            if bigEndian { bits = bits.byteSwapped }
            return Float(bitPattern: bits)
        case (8, true, _):
            var bits = raw.loadUnaligned(fromByteOffset: off, as: UInt64.self)
            if bigEndian { bits = bits.byteSwapped }
            return Float(Double(bitPattern: bits))
        case (1, false, false):
            return Float(raw[off])
        case (1, false, true):
            return Float(Int8(bitPattern: raw[off]))
        case (2, false, let signed):
            var v = raw.loadUnaligned(fromByteOffset: off, as: UInt16.self)
            if bigEndian { v = v.byteSwapped }
            return signed ? Float(Int16(bitPattern: v)) : Float(v)
        case (4, false, let signed):
            var v = raw.loadUnaligned(fromByteOffset: off, as: UInt32.self)
            if bigEndian { v = v.byteSwapped }
            return signed ? Float(Int32(bitPattern: v)) : Float(v)
        default:
            return 0
        }
    }

    // MARK: - Thống kê

    /// Phân vị 2% / 50% / 98% từng trục, tính trên mẫu ≤ 50k điểm.
    private static func percentiles(_ p: [SIMD3<Float>]) -> (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) {
        let step = max(1, p.count / 50_000)
        var xs: [Float] = [], ys: [Float] = [], zs: [Float] = []
        for i in stride(from: 0, to: p.count, by: step) {
            xs.append(p[i].x); ys.append(p[i].y); zs.append(p[i].z)
        }
        xs.sort(); ys.sort(); zs.sort()
        func at(_ a: [Float], _ q: Float) -> Float { a[min(a.count - 1, Int(Float(a.count - 1) * q))] }
        return (SIMD3(at(xs, 0.02), at(ys, 0.02), at(zs, 0.02)),
                SIMD3(at(xs, 0.5), at(ys, 0.5), at(zs, 0.5)),
                SIMD3(at(xs, 0.98), at(ys, 0.98), at(zs, 0.98)))
    }
}
