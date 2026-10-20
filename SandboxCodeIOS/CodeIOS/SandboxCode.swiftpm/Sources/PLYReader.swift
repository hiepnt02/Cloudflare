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
        /// Chỉ có ở mode .splats với file 3DGS đủ scale_*/rot_*: covariance 3D đối xứng tách 2 nửa + opacity.
        let cov0: [SIMD3<Float>]          // Σxx Σxy Σxz
        let cov1: [SIMD3<Float>]          // Σyy Σyz Σzz
        let opacities: [Float]            // đã sigmoid
        var hasSplats: Bool { !cov0.isEmpty }
    }

    enum Mode {
        case points      // chấm tròn, bỏ splat gần trong suốt (opacity < 0.1)
        case splats      // ellipse mờ, giữ tới opacity 1/255, đọc thêm scale/rot
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

    /// Các file .ply đóng gói kèm app (thư mục Sources/Data, khai `resources:` trong Package.swift).
    /// App Playground không sinh `Bundle.module`: tài nguyên nằm thẳng trong Bundle.main (hoặc một
    /// *.bundle con tuỳ phiên bản Xcode), có thể giữ thư mục "Data" hoặc không → tìm hết.
    static let bundled: [URL] = {
        var bundles = [Bundle.main]
        if let subs = Bundle.main.urls(forResourcesWithExtension: "bundle", subdirectory: nil) {
            bundles += subs.compactMap { Bundle(url: $0) }
        }
        var found: [URL] = []
        for bundle in bundles {
            for sub in ["Data", nil] as [String?] {
                found += bundle.urls(forResourcesWithExtension: "ply", subdirectory: sub) ?? []
                // File > 100 MB bị GitHub chặn → cắt thành ten.ply.part1, .part2… ; chỉ liệt kê mảnh 1
                found += bundle.urls(forResourcesWithExtension: "part1", subdirectory: sub) ?? []
            }
        }
        var seen = Set<String>()
        return found
            .filter { seen.insert($0.lastPathComponent).inserted }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }()

    /// Tên hiển thị: "mihama_0_optimized.ply.part1" → "mihama_0_optimized.ply"
    static func displayName(_ url: URL) -> String {
        url.pathExtension == "part1" ? url.deletingPathExtension().lastPathComponent : url.lastPathComponent
    }

    /// Nếu `url` là mảnh .part1 → ghép part1, part2… thành file nguyên trong Caches (một lần, lần sau dùng lại).
    /// File thường trả về nguyên vẹn.
    static func assembleIfSplit(_ url: URL) throws -> URL {
        guard url.pathExtension == "part1" else { return url }
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        let name = url.deletingPathExtension().lastPathComponent          // ten.ply

        var parts: [URL] = []
        var total = 0
        var i = 1
        while true {
            let part = dir.appendingPathComponent(name).appendingPathExtension("part\(i)")
            guard let size = try? fm.attributesOfItem(atPath: part.path)[.size] as? Int else { break }
            parts.append(part)
            total += size
            i += 1
        }
        guard !parts.isEmpty else { throw ReadError.unsupported("không thấy \(name).part1") }

        let caches = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let joined = caches.appendingPathComponent(name)
        if let existing = try? fm.attributesOfItem(atPath: joined.path)[.size] as? Int, existing == total {
            return joined                                                   // đã ghép từ trước
        }
        try? fm.removeItem(at: joined)
        fm.createFile(atPath: joined.path, contents: nil)
        let out = try FileHandle(forWritingTo: joined)
        defer { try? out.close() }
        for part in parts {
            let data = try Data(contentsOf: part, options: [.alwaysMapped])
            out.write(data)
        }
        return joined
    }
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
    static func load(url: URL, mode: Mode = .points, flipYZ: Bool? = nil) throws -> Result {
        let data = try Data(contentsOf: url, options: [.alwaysMapped])
        let header = try parseHeader(data)

        func index(_ name: String) -> Int? { header.properties.firstIndex { $0.name == name } }
        guard let ix = index("x"), let iy = index("y"), let iz = index("z") else {
            throw ReadError.unsupported("thiếu x/y/z")
        }
        let dc = [index("f_dc_0"), index("f_dc_1"), index("f_dc_2")].compactMap { $0 }
        let rgb = [index("red") ?? index("r"), index("green") ?? index("g"), index("blue") ?? index("b")].compactMap { $0 }
        let sc = [index("scale_0"), index("scale_1"), index("scale_2")].compactMap { $0 }
        let rot = [index("rot_0"), index("rot_1"), index("rot_2"), index("rot_3")].compactMap { $0 }
        let isSplat = dc.count == 3
        let iOpacity = index("opacity")
        let flip = flipYZ ?? isSplat
        let wantSplats = mode == .splats && isSplat && sc.count == 3 && rot.count == 4
        let minOpacity: Float = wantSplats ? 1 / 255 : 0.1
        // Lật Y, Z = F·R với F = diag(1, −1, −1); covariance Σ = (F R S)(F R S)ᵀ
        let flipMatrix = simd_float3x3(diagonal: SIMD3(1, flip ? -1 : 1, flip ? -1 : 1))

        let step = max(1, Int((Double(header.vertexCount) / Double(maxPoints)).rounded(.up)))
        var positions: [SIMD3<Float>] = []
        var colors: [SIMD3<Float>] = []
        var cov0: [SIMD3<Float>] = []
        var cov1: [SIMD3<Float>] = []
        var opacities: [Float] = []
        positions.reserveCapacity(header.vertexCount / step + 1)
        colors.reserveCapacity(header.vertexCount / step + 1)
        if wantSplats {
            cov0.reserveCapacity(header.vertexCount / step + 1)
            cov1.reserveCapacity(header.vertexCount / step + 1)
            opacities.reserveCapacity(header.vertexCount / step + 1)
        }

        // Cùng một hàm xử lý một hàng cho cả binary lẫn ascii: `get(i)` trả giá trị property i
        func take(_ get: (Int) -> Float) {
            var alpha: Float = 1
            if let iOpacity {
                alpha = 1 / (1 + exp(-get(iOpacity)))          // sigmoid
                if alpha < minOpacity { return }
            }
            var p = SIMD3(get(ix), get(iy), get(iz))
            if flip { p = SIMD3(p.x, -p.y, -p.z) }
            guard p.x.isFinite, p.y.isFinite, p.z.isFinite else { return }

            if wantSplats {
                // 3DGS lưu log(scale) và quaternion (w, x, y, z)
                let s = SIMD3(exp(get(sc[0])), exp(get(sc[1])), exp(get(sc[2])))
                var q = simd_quatf(ix: get(rot[1]), iy: get(rot[2]), iz: get(rot[3]), r: get(rot[0]))
                guard s.x.isFinite, s.y.isFinite, s.z.isFinite, simd_length(q.vector) > 1e-6 else { return }
                q = simd_normalize(q)
                let m = flipMatrix * simd_float3x3(q) * simd_float3x3(diagonal: s)
                let sigma = m * m.transpose
                cov0.append(SIMD3(sigma.columns.0.x, sigma.columns.1.x, sigma.columns.2.x))
                cov1.append(SIMD3(sigma.columns.1.y, sigma.columns.2.y, sigma.columns.2.z))
                opacities.append(alpha)
            }
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
                      totalVertices: header.vertexCount, isGaussianSplat: isSplat, extent: hi - lo,
                      cov0: cov0, cov1: cov1, opacities: opacities)
    }

    // MARK: - Đọc nguyên 14 cột 3DGS cho GSXEncoder (không lấy mẫu, không lật trục, không dời gốc)

    /// Dùng cho đường .gsx: PLY → RawSplats → GSXEncoder. Lọc/lật/dời làm sau khi giải mã .gsx (SceneContext).
    /// Cần đủ x y z f_dc_0..2 opacity scale_0..2 rot_0..3 (file 3DGS chuẩn INRIA).
    static func loadRaw(url: URL) throws -> RawSplats {
        let data = try Data(contentsOf: url, options: [.alwaysMapped])
        let header = try parseHeader(data)
        func index(_ name: String) throws -> Int {
            guard let i = header.properties.firstIndex(where: { $0.name == name }) else { throw ReadError.unsupported("thiếu cột \(name) (không phải PLY 3DGS)") }
            return i
        }
        let cols = try ["x", "y", "z", "f_dc_0", "f_dc_1", "f_dc_2", "opacity",
                        "scale_0", "scale_1", "scale_2", "rot_0", "rot_1", "rot_2", "rot_3"].map(index)
        let n = header.vertexCount
        guard n > 0 else { throw ReadError.noVertices }
        var arrays = [[Float]](repeating: [Float](repeating: 0, count: n), count: 14)

        switch header.format {
        case .binaryLE, .binaryBE:
            let bigEndian = header.format == .binaryBE
            guard data.count >= header.length + n * header.rowStride else { throw ReadError.unsupported("file ngắn hơn header khai báo") }
            data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
                for row in 0 ..< n {
                    let base = header.length + row * header.rowStride
                    for (k, c) in cols.enumerated() {
                        let prop = header.properties[c]
                        arrays[k][row] = value(raw, base + prop.offset, prop, bigEndian: bigEndian)
                    }
                }
            }
        case .ascii:
            let body = data.subdata(in: header.length ..< data.count)
            guard let text = String(data: body, encoding: .utf8) else { throw ReadError.unsupported("ascii không phải UTF-8") }
            var row = 0
            text.enumerateLines { line, stop in
                defer { row += 1 }
                if row >= n { stop = true; return }
                let tokens = line.split(separator: " ", omittingEmptySubsequences: true)
                guard tokens.count >= header.properties.count else { return }
                for (k, c) in cols.enumerated() { arrays[k][row] = Float(tokens[c]) ?? 0 }
            }
        }
        var out = RawSplats()
        out.count = n
        out.x = arrays[0]; out.y = arrays[1]; out.z = arrays[2]
        out.fdc0 = arrays[3]; out.fdc1 = arrays[4]; out.fdc2 = arrays[5]; out.opacity = arrays[6]
        out.scale0 = arrays[7]; out.scale1 = arrays[8]; out.scale2 = arrays[9]
        out.rot0 = arrays[10]; out.rot1 = arrays[11]; out.rot2 = arrays[12]; out.rot3 = arrays[13]
        return out
    }

    /// Phân vị 2% / 50% / 98% — bản public cho SceneContext dời cloud .gsx về gốc giống `load`.
    static func percentiles(of p: [SIMD3<Float>]) -> (lo: SIMD3<Float>, mid: SIMD3<Float>, hi: SIMD3<Float>) {
        percentiles(p)
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
