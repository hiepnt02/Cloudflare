//
//  SplatCloud.swift
//  Quick3DDemo
//
//  Dữ liệu Gaussian splatting trên GPU (= MetalPointCloud + covariance + opacity) và việc SẮP XẾP:
//  splat trộn alpha nên phải vẽ từ xa tới gần. Mỗi khi camera dịch/xoay đủ nhiều, sắp lại index buffer
//  ở thread nền bằng counting sort 16 bit theo độ sâu (O(n), 1 triệu splat vài chục ms), rồi memcpy
//  vào `indices` — SceneKit đọc buffer này trực tiếp nên frame sau đã đúng thứ tự.
//

import Metal
import simd

final class SplatCloud {
    let positions: MTLBuffer    // SIMD3<Float> × count (stride 16)
    let colors: MTLBuffer       // SIMD4<Float> × count: rgb + opacity
    let cov0: MTLBuffer         // SIMD3<Float>: Σxx Σxy Σxz
    let cov1: MTLBuffer         // SIMD3<Float>: Σyy Σyz Σzz
    let indices: MTLBuffer      // UInt32 × count, thứ tự vẽ (xa → gần)
    let count: Int
    let min: SIMD3<Float>
    let max: SIMD3<Float>
    var extent: Float { simd_reduce_max(max - min) }

    static let stride3 = MemoryLayout<SIMD3<Float>>.stride   // 16
    static let stride4 = MemoryLayout<SIMD4<Float>>.stride   // 16

    // Bản CPU để sắp xếp
    private let localPositions: [SIMD3<Float>]
    private var depths: [Float]
    private var keys: [UInt16]
    private var counts: [Int]
    private var order: [UInt32]

    private let sortQueue = DispatchQueue(label: "demo.splat.sort", qos: .userInteractive)
    private let lock = NSLock()
    private var sorting = false
    private var lastCamera: SIMD3<Float>?
    private var lastDirection: SIMD3<Float>?

    init?(device: MTLDevice, positions p: [SIMD3<Float>], colors c: [SIMD4<Float>],
          cov0 a: [SIMD3<Float>], cov1 b: [SIMD3<Float>]) {
        precondition(p.count == c.count && p.count == a.count && p.count == b.count)
        guard !p.isEmpty,
              let pb = device.makeBuffer(bytes: p, length: p.count * Self.stride3, options: .storageModeShared),
              let cb = device.makeBuffer(bytes: c, length: c.count * Self.stride4, options: .storageModeShared),
              let ab = device.makeBuffer(bytes: a, length: a.count * Self.stride3, options: .storageModeShared),
              let bb = device.makeBuffer(bytes: b, length: b.count * Self.stride3, options: .storageModeShared)
        else { return nil }

        var idx = [UInt32](repeating: 0, count: p.count)
        for i in 0 ..< p.count { idx[i] = UInt32(i) }
        guard let ib = device.makeBuffer(bytes: idx, length: idx.count * 4, options: .storageModeShared) else { return nil }

        positions = pb; colors = cb; cov0 = ab; cov1 = bb; indices = ib
        count = p.count
        localPositions = p
        depths = [Float](repeating: 0, count: p.count)
        keys = [UInt16](repeating: 0, count: p.count)
        counts = [Int](repeating: 0, count: 65536)
        order = idx

        var mn = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var mx = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for v in p { mn = simd_min(mn, v); mx = simd_max(mx, v) }
        min = mn
        max = mx
    }

    /// Gọi mỗi frame (từ binding của SplatProgram, thread render) với camera đã đổi sang hệ local của node.
    /// Chỉ sắp lại khi camera dịch > 2 % kích thước cloud hoặc xoay > 1.5°, và không sắp chồng nhau.
    func requestSortIfNeeded(cameraLocal: SIMD3<Float>, directionLocal: SIMD3<Float>) {
        lock.lock()
        defer { lock.unlock() }
        if sorting { return }
        if let lc = lastCamera, let ld = lastDirection,
           simd_distance(lc, cameraLocal) < 0.02 * extent,
           simd_dot(ld, directionLocal) > cos(1.5 * .pi / 180) {
            return
        }
        sorting = true
        lastCamera = cameraLocal
        lastDirection = directionLocal
        sortQueue.async { [weak self] in
            guard let self else { return }
            self.sort(camera: cameraLocal, direction: directionLocal)
            self.lock.lock()
            self.sorting = false
            self.lock.unlock()
        }
    }

    /// Counting sort theo độ sâu lượng tử hoá 16 bit, xa trước gần sau. Chỉ chạy trên sortQueue.
    private func sort(camera: SIMD3<Float>, direction: SIMD3<Float>) {
        let n = count
        var dmin = Float.greatestFiniteMagnitude
        var dmax = -Float.greatestFiniteMagnitude
        localPositions.withUnsafeBufferPointer { p in
            depths.withUnsafeMutableBufferPointer { d in
                for i in 0 ..< n {
                    let v = simd_dot(p[i] - camera, direction)
                    d[i] = v
                    if v < dmin { dmin = v }
                    if v > dmax { dmax = v }
                }
            }
        }
        let scale = Float(65535) / Swift.max(dmax - dmin, 1e-6)

        for i in counts.indices { counts[i] = 0 }
        keys.withUnsafeMutableBufferPointer { k in
            counts.withUnsafeMutableBufferPointer { c in
                for i in 0 ..< n {
                    let q = Int((depths[i] - dmin) * scale)
                    let key = UInt16(clamping: q)
                    k[i] = key
                    c[Int(key)] += 1
                }
                // Prefix sum từ key lớn (xa) xuống nhỏ (gần) → thứ tự giảm dần theo độ sâu
                var sum = 0
                var key = 65535
                while key >= 0 {
                    let cnt = c[key]
                    c[key] = sum
                    sum += cnt
                    key -= 1
                }
                order.withUnsafeMutableBufferPointer { o in
                    for i in 0 ..< n {
                        let slot = Int(k[i])
                        o[c[slot]] = UInt32(i)
                        c[slot] += 1
                    }
                }
            }
        }
        order.withUnsafeBytes { src in
            indices.contents().copyMemory(from: src.baseAddress!, byteCount: n * 4)
        }
    }
}
