//
//  GSXEncoder.swift
//  Quick3DDemo
//
//  PLY (3DGS) → .gsx ngay trong app — port converter.cpp main():
//    filter → AABB → octree (reservoir sampling theo opacity) → tách node quá to (Hilbert) →
//    mỗi block: Hilbert sort, quantize, payload raw, gzip → lắp file.
//  Lambda gsplat-converter làm việc này trên AWS; ở đây làm trên thiết bị để không cần server.
//

import Foundation
import simd

/// 14 cột tối thiểu của PLY 3DGS, đọc nguyên (không lật trục, không lấy mẫu). Đơn vị như trong file.
struct RawSplats {
    var count = 0
    var x: [Float] = [], y: [Float] = [], z: [Float] = []
    var fdc0: [Float] = [], fdc1: [Float] = [], fdc2: [Float] = []
    var opacity: [Float] = []                       // logit
    var scale0: [Float] = [], scale1: [Float] = [], scale2: [Float] = []   // log
    var rot0: [Float] = [], rot1: [Float] = [], rot2: [Float] = [], rot3: [Float] = []

    func filtered(by keep: [Int]) -> RawSplats {
        var o = RawSplats(); o.count = keep.count
        func pick(_ a: [Float]) -> [Float] { var r = [Float](); r.reserveCapacity(keep.count); for i in keep { r.append(a[i]) }; return r }
        o.x = pick(x); o.y = pick(y); o.z = pick(z)
        o.fdc0 = pick(fdc0); o.fdc1 = pick(fdc1); o.fdc2 = pick(fdc2); o.opacity = pick(opacity)
        o.scale0 = pick(scale0); o.scale1 = pick(scale1); o.scale2 = pick(scale2)
        o.rot0 = pick(rot0); o.rot1 = pick(rot1); o.rot2 = pick(rot2); o.rot3 = pick(rot3)
        return o
    }
}

enum GSXEncoder {

    struct Params {
        var blockSize = 1024
        var hilbertGridBits = 10
        var posBits = 12
        var otherBits = 8
        var useHilbert = true
        var filter = true                  // bỏ opacity < 0.02, scale > 3 m, aniso > 200 (như Lambda)
        /// Đổi hệ toạ độ TRƯỚC mọi thứ (= chỗ Lambda sẽ áp ma trận từ server). nil = không đổi.
        var crs: (from: String, to: String)? = nil
        var rotateQuat = true              // xoay quaternion + cộng ln(scale) theo ma trận cục bộ (đúng)
        var subtractOrigin = true          // trừ tâm AABB, ghi origin f64 vào header byte 60–83
    }

    /// Ma trận cục bộ của phép đổi hệ tại tâm cảnh (như applyCrsTransform trong HTML).
    struct CRSInfo {
        var yawDeg: Double = 0, scale: Double = 1
        var centerSource = SIMD2<Double>(), centerTarget = SIMD2<Double>()
        var identity = true
    }

    struct Stats {
        var kept = 0, dropped = 0, nodes = 0, blocks = 0
        var seconds: Double = 0
        var bytes = 0
        var crs: CRSInfo? = nil
        var origin = SIMD3<Double>()
    }

    enum EncodeError: LocalizedError {
        case unknownCRS(String)
        var errorDescription: String? { if case .unknownCRS(let c) = self { return "CRS \(c) không có trong bảng" }; return nil }
    }

    // MARK: - Đổi hệ toạ độ (port applyCrsTransform): vị trí qua phép chiếu thật (phi tuyến),
    // quaternion/scale dùng affine CỤC BỘ tại tâm cảnh lấy từ 3 điểm thăm dò C, C+1 m Đông, C+1 m Bắc. Z giữ nguyên.

    static func applyCRS(_ P0: RawSplats, from fromCode: String, to toCode: String, rotateQuat: Bool,
                         progress: (String) -> Void) throws -> (RawSplats, CRSInfo) {
        var info = CRSInfo()
        if fromCode == toCode || P0.count == 0 { return (P0, info) }
        guard let from = CRS.byCode(fromCode) else { throw EncodeError.unknownCRS(fromCode) }
        guard let to = CRS.byCode(toCode) else { throw EncodeError.unknownCRS(toCode) }
        let n = P0.count
        var cx = 0.0, cy = 0.0
        for i in 0 ..< n { cx += Double(P0.x[i]); cy += Double(P0.y[i]) }
        cx /= Double(n); cy /= Double(n)
        let step = from.isGeographic ? 1e-5 : 1.0                       // "1 m" thăm dò
        let C = CRS.forward(from: from, to: to, x: cx, y: cy)
        let E = CRS.forward(from: from, to: to, x: cx + step, y: cy)
        let N = CRS.forward(from: from, to: to, x: cx, y: cy + step)
        let ex = (E.0 - C.0) / step, ey = (E.1 - C.1) / step, nx = (N.0 - C.0) / step, ny = (N.1 - C.1) / step
        var yaw = atan2(ey, ex), scale = (hypot(ex, ey) + hypot(nx, ny)) / 2
        // Toạ độ raw gán nhầm hệ (vd. lat/lon mà số không phải độ) → phép chiếu ra NaN/∞: không để trap ở quantize
        if !yaw.isFinite { yaw = 0 }
        if !scale.isFinite || scale <= 0 { scale = 1 }
        info = CRSInfo(yawDeg: yaw * 180 / .pi, scale: scale, centerSource: SIMD2(cx, cy), centerTarget: SIMD2(C.0, C.1), identity: false)
        // qR = quay quanh Z góc yaw, (w, x, y, z) — cùng thứ tự rot_0..3 của PLY
        let h = yaw / 2, qR = (w: Float(cos(h)), x: Float(0), y: Float(0), z: Float(sin(h)))
        let lnS = Float(log(scale))

        var P = P0
        for i in 0 ..< n {
            let p = CRS.forward(from: from, to: to, x: Double(P0.x[i]), y: Double(P0.y[i]))
            if p.0.isFinite && p.1.isFinite && abs(p.0) < 1e9 && abs(p.1) < 1e9 {
                P.x[i] = Float(p.0); P.y[i] = Float(p.1)                 // z giữ nguyên
            } else {
                P.opacity[i] = -100                                      // sigmoid ≈ 0 → filter bỏ splat này
            }
            if rotateQuat {
                let a = qR, b = (w: P0.rot0[i], x: P0.rot1[i], y: P0.rot2[i], z: P0.rot3[i])
                P.rot0[i] = a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z
                P.rot1[i] = a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y
                P.rot2[i] = a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x
                P.rot3[i] = a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w
                P.scale0[i] += lnS; P.scale1[i] += lnS; P.scale2[i] += lnS
            }
            if i % 200_000 == 0 { progress("đổi CRS \(fromCode) → \(toCode): \(i)/\(n)") }
        }
        return (P, info)
    }

    // MARK: - API

    static func encode(_ input: RawSplats, params: Params = Params(), progress: @escaping (String) -> Void) throws -> (Data, Stats) {
        let t0 = Date()
        var stats = Stats()

        // ── filter trên dữ liệu GỐC (opacity < 0.02, scale > 3 m, aniso > 200) ──
        // Lambda lọc sau khi đổi hệ; ở đây lọc trước, vì gán hệ gốc không hợp số raw (vd. lat/lon cho số mét)
        // sẽ cộng ln(scale) rất lớn vào mọi splat → "scale > 3 m" bỏ sạch, ra file rỗng.
        var P = input
        if params.filter {
            var keep: [Int] = []; keep.reserveCapacity(input.count)
            for i in 0 ..< input.count {
                if sigmoid(input.opacity[i]) < 0.02 { continue }
                if !(input.x[i].isFinite && input.y[i].isFinite && input.z[i].isFinite) { continue }
                let s0 = exp(input.scale0[i]), s1 = exp(input.scale1[i]), s2 = exp(input.scale2[i])
                let mx = max(s0, s1, s2); if mx > 3 { continue }
                let mn = min(s0, s1, s2); if mx / max(mn, 1e-9) > 200 { continue }
                keep.append(i)
            }
            if keep.count < input.count { P = input.filtered(by: keep) }
        }
        stats.kept = P.count; stats.dropped = input.count - P.count
        progress("filter: giữ \(P.count)/\(input.count)")

        // ── đổi hệ toạ độ (= chỗ Lambda sẽ áp ma trận từ server) ──
        if let crs = params.crs {
            let (Pt, info) = try applyCRS(P, from: crs.from, to: crs.to, rotateQuat: params.rotateQuat, progress: progress)
            stats.crs = info
            // bỏ điểm không hữu hạn sau phép chiếu (applyCRS đã đánh dấu opacity = -100)
            var keep: [Int] = []; keep.reserveCapacity(Pt.count)
            for i in 0 ..< Pt.count where Pt.opacity[i] > -99 && Pt.x[i].isFinite && Pt.y[i].isFinite { keep.append(i) }
            P = keep.count < Pt.count ? Pt.filtered(by: keep) : Pt
            if !info.identity {
                progress(String(format: "CRS: xoay %.3f° · scale %.6f · tâm đích (%.2f, %.2f) · giữ %d/%d",
                                info.yawDeg, info.scale, info.centerTarget.x, info.centerTarget.y, P.count, Pt.count))
                if info.scale > 1.5 || info.scale < 0.67 {
                    progress(String(format: "CẢNH BÁO: scale cục bộ %.3f bất thường → hệ gốc gán không hợp với số raw của PLY", info.scale))
                }
            }
            stats.kept = P.count; stats.dropped = input.count - P.count
        }

        // ── AABB ──
        var gMin = SIMD3<Float>(repeating: .greatestFiniteMagnitude), gMax = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for i in 0 ..< P.count { let v = SIMD3(P.x[i], P.y[i], P.z[i]); gMin = simd_min(gMin, v); gMax = simd_max(gMax, v) }
        if P.count == 0 { gMin = .zero; gMax = .zero }

        // ── trừ origin = tâm AABB để .gsx/GPU chỉ giữ số nhỏ (toạ độ UTM ~10⁵–10⁶ vào float32 sẽ rung) ──
        if params.subtractOrigin && P.count > 0 {
            let o = (SIMD3<Double>(gMin) + SIMD3<Double>(gMax)) * 0.5
            stats.origin = o
            let of = SIMD3<Float>(o)
            for i in 0 ..< P.count { P.x[i] -= of.x; P.y[i] -= of.y; P.z[i] -= of.z }
            gMin -= of; gMax -= of
            progress(String(format: "origin: trừ (%.2f, %.2f, %.2f)", o.x, o.y, o.z))
        }

        // ── octree ──
        progress("octree: reservoir sampling…")
        var tree = buildOctree(P, gMin: gMin, gMax: gMax, blockSize: params.blockSize)

        // ── tách node quá to theo Hilbert ──
        let originalNodes = tree.nodes.count
        for nodeId in 0 ..< originalNodes where tree.splats[nodeId].count > params.blockSize {
            let own = tree.splats[nodeId]
            let order = hilbertOrder(own, P, tree.nodes[nodeId].aabbMin, tree.nodes[nodeId].aabbMax, params.hilbertGridBits)
            let sorted = order.map { own[Int($0)] }
            let pieces = (sorted.count + params.blockSize - 1) / params.blockSize
            for p in 0 ..< pieces {
                let chunk = Array(sorted[p * params.blockSize ..< min(sorted.count, (p + 1) * params.blockSize)])
                let (mn, mx) = tightAABB(P, chunk)
                if p == 0 {
                    tree.splats[nodeId] = chunk; tree.nodes[nodeId].aabbMin = mn; tree.nodes[nodeId].aabbMax = mx
                } else {
                    var sib = GSX.Node(); sib.level = tree.nodes[nodeId].level; sib.parentId = tree.nodes[nodeId].parentId
                    sib.aabbMin = mn; sib.aabbMax = mx
                    tree.nodes.append(sib); tree.splats.append(chunk)
                }
            }
        }
        let nodeCount = tree.nodes.count
        stats.nodes = nodeCount; stats.blocks = nodeCount
        progress("octree: \(nodeCount) node")

        // ── từng block: hilbert + quantize + payload + gzip (song song) ──
        struct Encoded { var compressed = Data(); var sizeUncompressed = 0; var aabbMin = SIMD3<Float>(); var aabbMax = SIMD3<Float>() }
        var blocks = [Encoded](repeating: Encoded(), count: nodeCount)
        for i in 0 ..< nodeCount { blocks[i].aabbMin = tree.nodes[i].aabbMin; blocks[i].aabbMax = tree.nodes[i].aabbMax }
        let lock = NSLock()
        var done = 0
        let shBits = params.otherBits, scBits = params.otherBits, rotBits = params.otherBits, opaBits = params.otherBits
        DispatchQueue.concurrentPerform(iterations: nodeCount) { nodeId in
            let ids = tree.splats[nodeId]
            if ids.isEmpty { return }
            let node = tree.nodes[nodeId]
            let n = ids.count
            let perm: [UInt32] = params.useHilbert ? hilbertOrder(ids, P, node.aabbMin, node.aabbMax, params.hilbertGridBits) : (0 ..< n).map { UInt32($0) }
            var bPos = [Float](repeating: 0, count: n * 3), bSh = [Float](repeating: 0, count: n * 3), bSc = [Float](repeating: 0, count: n * 3)
            var bRot = [Float](repeating: 0, count: n * 4), bOpa = [Float](repeating: 0, count: n)
            var mn = SIMD3<Float>(repeating: .greatestFiniteMagnitude), mx = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
            for i in 0 ..< n {
                let s = ids[Int(perm[i])]
                let v = SIMD3(P.x[s], P.y[s], P.z[s])
                bPos[i * 3] = v.x; bPos[i * 3 + 1] = v.y; bPos[i * 3 + 2] = v.z
                mn = simd_min(mn, v); mx = simd_max(mx, v)
                bSh[i * 3] = P.fdc0[s]; bSh[i * 3 + 1] = P.fdc1[s]; bSh[i * 3 + 2] = P.fdc2[s]
                bSc[i * 3] = P.scale0[s]; bSc[i * 3 + 1] = P.scale1[s]; bSc[i * 3 + 2] = P.scale2[s]
                bRot[i * 4] = P.rot0[s]; bRot[i * 4 + 1] = P.rot1[s]; bRot[i * 4 + 2] = P.rot2[s]; bRot[i * 4 + 3] = P.rot3[s]
                bOpa[i] = P.opacity[s]
            }
            let qPos = quantizePosition(bPos, n, mn, mx, params.posBits)
            let qSh = quantizeShDc(bSh, shBits), qSc = quantizeScale(bSc, scBits)
            let qRot = quantizeRotation(bRot, n, rotBits), qOpa = quantizeOpacity(bOpa, opaBits)
            let payload = payloadData(n, qPos, params.posBits, qSh, shBits, qSc, scBits, qRot, rotBits, qOpa, opaBits)
            let gz = GSX.gzip(payload)
            lock.lock()
            blocks[nodeId].compressed = gz; blocks[nodeId].sizeUncompressed = payload.count
            blocks[nodeId].aabbMin = mn; blocks[nodeId].aabbMax = mx
            done += 1
            if done % 64 == 0 { progress("encode + gzip: \(done)/\(nodeCount) block") }
            lock.unlock()
        }

        // ── lắp file ──
        let indexOff = GSX.headerSize, octreeOff = indexOff + nodeCount * GSX.indexEntrySize, blocksOff = octreeOff + nodeCount * GSX.nodeSize
        var offsets = [Int](repeating: 0, count: nodeCount)
        var cursor = blocksOff
        for i in 0 ..< nodeCount { offsets[i] = cursor; cursor += blocks[i].compressed.count }
        var out = Data(count: cursor)
        out.withUnsafeMutableBytes { raw in
            func u32(_ o: Int, _ v: UInt32) { raw.storeBytes(of: v.littleEndian, toByteOffset: o, as: UInt32.self) }
            func i32(_ o: Int, _ v: Int32) { raw.storeBytes(of: v.littleEndian, toByteOffset: o, as: Int32.self) }
            func u16(_ o: Int, _ v: UInt16) { raw.storeBytes(of: v.littleEndian, toByteOffset: o, as: UInt16.self) }
            func f32(_ o: Int, _ v: Float) { raw.storeBytes(of: v.bitPattern.littleEndian, toByteOffset: o, as: UInt32.self) }
            func f64(_ o: Int, _ v: Double) { raw.storeBytes(of: v.bitPattern.littleEndian, toByteOffset: o, as: UInt64.self) }
            u32(0, GSX.magic); u16(4, GSX.version); u16(6, GSX.flagGzip)
            u32(8, UInt32(P.count)); u32(12, UInt32(nodeCount)); u32(16, UInt32(params.blockSize))
            f32(20, gMin.x); f32(24, gMin.y); f32(28, gMin.z); f32(32, gMax.x); f32(36, gMax.y); f32(40, gMax.z)
            raw[44] = UInt8(params.posBits); raw[45] = UInt8(shBits); raw[46] = UInt8(scBits); raw[47] = UInt8(rotBits); raw[48] = UInt8(opaBits)
            u32(52, UInt32(nodeCount)); i32(56, 0)
            f64(60, stats.origin.x); f64(68, stats.origin.y); f64(76, stats.origin.z)     // origin f64 (đề xuất Atlas CRS)
            for i in 0 ..< nodeCount {
                let o = indexOff + i * GSX.indexEntrySize, b = blocks[i]
                f64(o, Double(offsets[i])); u32(o + 8, UInt32(b.compressed.count)); u32(o + 12, UInt32(b.sizeUncompressed))
                f32(o + 16, b.aabbMin.x); f32(o + 20, b.aabbMin.y); f32(o + 24, b.aabbMin.z); f32(o + 28, b.aabbMax.x); f32(o + 32, b.aabbMax.y); f32(o + 36, b.aabbMax.z)
            }
            for i in 0 ..< nodeCount {
                let o = octreeOff + i * GSX.nodeSize, nd = tree.nodes[i]
                u32(o, tree.splats[i].isEmpty ? GSX.noBlock : UInt32(i)); i32(o + 4, nd.parentId)
                for j in 0 ..< 8 { i32(o + 8 + j * 4, nd.childIds[j]) }
                f32(o + 40, nd.aabbMin.x); f32(o + 44, nd.aabbMin.y); f32(o + 48, nd.aabbMin.z); f32(o + 52, nd.aabbMax.x); f32(o + 56, nd.aabbMax.y); f32(o + 60, nd.aabbMax.z)
                u32(o + 64, UInt32(nd.level))
            }
            for i in 0 ..< nodeCount where !blocks[i].compressed.isEmpty {
                blocks[i].compressed.withUnsafeBytes { src in
                    raw.baseAddress!.advanced(by: offsets[i]).copyMemory(from: src.baseAddress!, byteCount: src.count)
                }
            }
        }
        stats.seconds = Date().timeIntervalSince(t0); stats.bytes = out.count
        progress(String(format: "gsx: %.1f MB, %d block, %.1f s", Double(out.count) / 1048576, nodeCount, stats.seconds))
        return (out, stats)
    }

    // MARK: - Octree (build_octree_recursive + weighted_reservoir_split)

    private struct Tree { var nodes: [GSX.Node] = []; var splats: [[Int]] = [] }

    private static func buildOctree(_ P: RawSplats, gMin: SIMD3<Float>, gMax: SIMD3<Float>, blockSize: Int) -> Tree {
        var tree = Tree()
        func mk(_ level: Int, _ parent: Int32, _ mn: SIMD3<Float>, _ mx: SIMD3<Float>) -> Int {
            var n = GSX.Node(); n.level = level; n.parentId = parent; n.aabbMin = mn; n.aabbMax = mx
            tree.nodes.append(n); tree.splats.append([]); return tree.nodes.count - 1
        }
        if P.count == 0 { _ = mk(0, GSX.noNode, gMin, gMax); return tree }
        let targetCells = max(1, (P.count + blockSize - 1) / blockSize)
        let inferredMax = max(1, Int(ceil(log2(Double(targetCells)) / 3)))
        let maxLevel = max(inferredMax + 1, 10)
        var rng = XorShift(seed: 0xC0FFEE)

        func rec(_ indices: [Int], _ mn: SIMD3<Float>, _ mx: SIMD3<Float>, _ level: Int, _ parent: Int32) -> Int {
            let cell = mk(level, parent, mn, mx)
            if indices.isEmpty { return cell }
            if level >= maxLevel || indices.count <= blockSize { tree.splats[cell] = indices; return cell }
            let (kept, rest) = reservoirSplit(indices, k: blockSize, opacity: P.opacity, rng: &rng)
            tree.splats[cell] = kept
            let c = (mn + mx) * 0.5
            var buckets = [[Int]](repeating: [], count: 8)
            for i in rest {
                var o = 0
                if P.x[i] >= c.x { o |= 1 }; if P.y[i] >= c.y { o |= 2 }; if P.z[i] >= c.z { o |= 4 }
                buckets[o].append(i)
            }
            for o in 0 ..< 8 where !buckets[o].isEmpty {
                let cmn = SIMD3((o & 1) != 0 ? c.x : mn.x, (o & 2) != 0 ? c.y : mn.y, (o & 4) != 0 ? c.z : mn.z)
                let cmx = SIMD3((o & 1) != 0 ? mx.x : c.x, (o & 2) != 0 ? mx.y : c.y, (o & 4) != 0 ? mx.z : c.z)
                let child = rec(buckets[o], cmn, cmx, level + 1, Int32(cell))
                tree.nodes[cell].childIds[o] = Int32(child)
            }
            return cell
        }
        _ = rec(Array(0 ..< P.count), gMin, gMax, 0, GSX.noNode)
        return tree
    }

    /// Reservoir có trọng số (Pareto key U^(1/w), w = sigmoid opacity) với min-heap cỡ k.
    private static func reservoirSplit(_ indices: [Int], k: Int, opacity: [Float], rng: inout XorShift) -> ([Int], [Int]) {
        if indices.count <= k { return (indices, []) }
        var hk = [Double](repeating: 0, count: k), hi = [Int](repeating: 0, count: k)
        func keyOf(_ i: Int) -> Double { pow(rng.nextDouble(), 1 / Double(max(sigmoid(opacity[i]), 1e-6))) }
        func siftDown(_ start: Int) {
            var i = start
            while true {
                let l = 2 * i + 1, r = l + 1; var m = i
                if l < k && hk[l] < hk[m] { m = l }
                if r < k && hk[r] < hk[m] { m = r }
                if m == i { return }
                hk.swapAt(i, m); hi.swapAt(i, m); i = m
            }
        }
        for i in 0 ..< k { hk[i] = keyOf(indices[i]); hi[i] = indices[i] }
        var i = k / 2 - 1
        while i >= 0 { siftDown(i); i -= 1 }
        var rest: [Int] = []; rest.reserveCapacity(indices.count - k)
        for j in k ..< indices.count {
            let idx = indices[j], key = keyOf(idx)
            if key > hk[0] { rest.append(hi[0]); hk[0] = key; hi[0] = idx; siftDown(0) } else { rest.append(idx) }
        }
        return (hi, rest)
    }

    private static func tightAABB(_ P: RawSplats, _ ids: [Int]) -> (SIMD3<Float>, SIMD3<Float>) {
        var mn = SIMD3<Float>(repeating: .greatestFiniteMagnitude), mx = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for i in ids { let v = SIMD3(P.x[i], P.y[i], P.z[i]); mn = simd_min(mn, v); mx = simd_max(mx, v) }
        return (mn, mx)
    }

    // MARK: - Hilbert (Skilling) — hilbert_index_3d

    private static func hilbertIndex(_ x: UInt32, _ y: UInt32, _ z: UInt32, bits: Int) -> UInt64 {
        var X = [x, y, z]
        let M: UInt32 = 1 << UInt32(bits - 1)
        var Q = M
        while Q > 1 {
            let Pm = Q - 1
            for i in 0 ..< 3 {
                if X[i] & Q != 0 { X[0] ^= Pm } else { let t = (X[0] ^ X[i]) & Pm; X[0] ^= t; X[i] ^= t }
            }
            Q >>= 1
        }
        for i in 1 ..< 3 { X[i] ^= X[i - 1] }
        var t: UInt32 = 0
        Q = M
        while Q > 1 { if X[2] & Q != 0 { t ^= Q - 1 }; Q >>= 1 }
        for i in 0 ..< 3 { X[i] ^= t }
        var h: UInt64 = 0
        var p = bits - 1
        while p >= 0 { for i in 0 ..< 3 { h = (h << 1) | UInt64((X[i] >> UInt32(p)) & 1) }; p -= 1 }
        return h
    }

    /// Permutation (chỉ số trong `ids`) theo thứ tự Hilbert trong AABB cho trước.
    private static func hilbertOrder(_ ids: [Int], _ P: RawSplats, _ mn: SIMD3<Float>, _ mx: SIMD3<Float>, _ bits: Int) -> [UInt32] {
        let grid = Float((1 << bits) - 1)
        let ext = mx - mn
        let inv = SIMD3(ext.x > 0 ? grid / ext.x : 0, ext.y > 0 ? grid / ext.y : 0, ext.z > 0 ? grid / ext.z : 0)
        var packed = [UInt64](repeating: 0, count: ids.count)      // key << 32 | i → sort nhanh không comparator
        for (i, idx) in ids.enumerated() {
            let q = simd_clamp((SIMD3(P.x[idx], P.y[idx], P.z[idx]) - mn) * inv, SIMD3(repeating: 0), SIMD3(repeating: grid))
            let key = hilbertIndex(UInt32(q.x.rounded()), UInt32(q.y.rounded()), UInt32(q.z.rounded()), bits: bits)
            packed[i] = key << 32 | UInt64(i)
        }
        packed.sort()
        return packed.map { UInt32(truncatingIfNeeded: $0 & 0xffff_ffff) }
    }

    // MARK: - Quantize (converter.cpp)

    @inline(__always) private static func clampI(_ v: Int, _ lo: Int, _ hi: Int) -> Int { v < lo ? lo : (v > hi ? hi : v) }
    @inline(__always) static func sigmoid(_ x: Float) -> Float { x >= 0 ? 1 / (1 + exp(-x)) : { let e = exp(x); return e / (1 + e) }() }

    private static func quantizePosition(_ a: [Float], _ n: Int, _ mn: SIMD3<Float>, _ mx: SIMD3<Float>, _ bits: Int) -> [UInt32] {
        let maxv = (1 << bits) - 1, ext = mx - mn
        let inv = SIMD3(ext.x > 0 ? Float(maxv) / ext.x : 0, ext.y > 0 ? Float(maxv) / ext.y : 0, ext.z > 0 ? Float(maxv) / ext.z : 0)
        var out = [UInt32](repeating: 0, count: n * 3)
        for i in 0 ..< n {
            out[i * 3] = UInt32(clampI(Int(((a[i * 3] - mn.x) * inv.x).rounded()), 0, maxv))
            out[i * 3 + 1] = UInt32(clampI(Int(((a[i * 3 + 1] - mn.y) * inv.y).rounded()), 0, maxv))
            out[i * 3 + 2] = UInt32(clampI(Int(((a[i * 3 + 2] - mn.z) * inv.z).rounded()), 0, maxv))
        }
        return out
    }
    private static func quantizeShDc(_ a: [Float], _ bits: Int) -> [UInt32] {
        let maxv = (1 << bits) - 1, r = GSX.shDcRange
        return a.map { let v = min(max($0, -r), r); return UInt32(clampI(Int((((v + r) / (2 * r)) * Float(maxv)).rounded()), 0, maxv)) }
    }
    private static func quantizeScale(_ a: [Float], _ bits: Int) -> [UInt32] {
        let maxv = (1 << bits) - 1, range = GSX.scaleMax - GSX.scaleMin
        return a.map { let v = min(max($0, GSX.scaleMin), GSX.scaleMax); return UInt32(clampI(Int((((v - GSX.scaleMin) / range) * Float(maxv)).rounded()), 0, maxv)) }
    }
    private static func quantizeOpacity(_ a: [Float], _ bits: Int) -> [UInt32] {
        let maxv = (1 << bits) - 1
        return a.map { UInt32(clampI(Int((sigmoid($0) * Float(maxv)).rounded()), 0, maxv)) }
    }
    private static func quantizeRotation(_ a: [Float], _ n: Int, _ bits: Int) -> [UInt32] {
        let maxv = (1 << bits) - 1
        var out = [UInt32](repeating: 0, count: n * 4)
        for i in 0 ..< n {
            var q = [a[i * 4], a[i * 4 + 1], a[i * 4 + 2], a[i * 4 + 3]]
            let norm = max(sqrt(q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3]), 1e-12)
            for j in 0 ..< 4 { q[j] /= norm }
            if bits >= 16 {
                for j in 0 ..< 4 { out[i * 4 + j] = UInt32(clampI(Int((((q[j] + 1) / 2) * Float(maxv)).rounded()), 0, maxv)) }
            } else {
                var maxIdx = 0
                for j in 1 ..< 4 where abs(q[j]) > abs(q[maxIdx]) { maxIdx = j }
                if q[maxIdx] < 0 { for j in 0 ..< 4 { q[j] = -q[j] } }
                out[i * 4] = UInt32(maxIdx)
                var s = 1
                for j in 0 ..< 4 where j != maxIdx {
                    let v = min(max(q[j], -GSX.sqrtHalf), GSX.sqrtHalf)
                    out[i * 4 + s] = UInt32(clampI(Int((((v + GSX.sqrtHalf) / (2 * GSX.sqrtHalf)) * Float(maxv)).rounded()), 0, maxv)); s += 1
                }
            }
        }
        return out
    }

    /// encode_block_payload: u32 n, u8 5, rồi mỗi stream u8 id, u8 bits, u8 0, u32 count, u32 rawLen, u32×count
    private static func payloadData(_ n: Int, _ qPos: [UInt32], _ posBits: Int, _ qSh: [UInt32], _ shBits: Int,
                                    _ qSc: [UInt32], _ scBits: Int, _ qRot: [UInt32], _ rotBits: Int, _ qOpa: [UInt32], _ opaBits: Int) -> Data {
        let streams: [(UInt8, Int, [UInt32])] = [(0, posBits, qPos), (1, shBits, qSh), (2, scBits, qSc), (3, rotBits, qRot), (4, opaBits, qOpa)]
        var total = 5; for s in streams { total += 11 + s.2.count * 4 }
        var out = Data(count: total)
        out.withUnsafeMutableBytes { raw in
            var p = 0
            func u32(_ v: UInt32) { raw.storeBytes(of: v.littleEndian, toByteOffset: p, as: UInt32.self); p += 4 }
            func u8(_ v: UInt8) { raw[p] = v; p += 1 }
            u32(UInt32(n)); u8(GSX.numStreams)
            for (id, bits, vals) in streams {
                u8(id); u8(UInt8(bits)); u8(0); u32(UInt32(vals.count)); u32(UInt32(vals.count * 4))
                for v in vals { u32(v) }
            }
        }
        return out
    }

    struct XorShift {
        var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
        mutating func next() -> UInt64 { state ^= state << 13; state ^= state >> 7; state ^= state << 17; return state }
        mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    }
}
