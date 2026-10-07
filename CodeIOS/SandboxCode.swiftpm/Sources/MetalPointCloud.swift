//
//  MetalPointCloud.swift
//  Quick3DDemo
//
//  Tầng ⑥ (dữ liệu) — point cloud nằm sẵn trên GPU dưới dạng MTLBuffer.
//  Tương đương BufferAttribute của Three.js nhưng đã ở GPU.
//  Trong project thật: Camera/Metal/MetalPointCloud.swift (phức tạp hơn: append
//  từng block, compute kernel copy/merge). Ở đây chỉ cần 3 buffer.
//

import Metal
import simd

final class MetalPointCloud {
    let device: MTLDevice
    let positions: MTLBuffer   // SIMD3<Float> × count (stride 16 byte)
    let colors: MTLBuffer      // SIMD3<Float> × count
    let indices: MTLBuffer     // UInt32 × count (0,1,2,…) — SceneKit cần element index
    let count: Int
    let min: SIMD3<Float>
    let max: SIMD3<Float>

    static let stride = MemoryLayout<SIMD3<Float>>.stride   // = 16, không phải 12

    init?(device: MTLDevice, positions p: [SIMD3<Float>], colors c: [SIMD3<Float>]) {
        precondition(p.count == c.count)
        guard !p.isEmpty,
              let pb = device.makeBuffer(bytes: p, length: p.count * Self.stride, options: .storageModeShared),
              let cb = device.makeBuffer(bytes: c, length: c.count * Self.stride, options: .storageModeShared)
        else { return nil }

        var idx = [UInt32](repeating: 0, count: p.count)
        for i in 0..<p.count { idx[i] = UInt32(i) }
        guard let ib = device.makeBuffer(bytes: idx, length: idx.count * 4, options: .storageModeShared) else { return nil }

        self.device = device
        self.positions = pb
        self.colors = cb
        self.indices = ib
        self.count = p.count

        var mn = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var mx = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for v in p { mn = simd_min(mn, v); mx = simd_max(mx, v) }
        self.min = mn
        self.max = mx
    }

    // MARK: - Dữ liệu giả lập (thay cho BVH tải từ server)

    /// Mặt đất lượn sóng `size`×`size` mét + một cột trụ ở giữa. ~100k điểm.
    static func makeTerrain(device: MTLDevice, grid: Int = 300, size: Float = 2.0) -> MetalPointCloud? {
        var pos: [SIMD3<Float>] = []
        var col: [SIMD3<Float>] = []
        pos.reserveCapacity(grid * grid + 20_000)
        col.reserveCapacity(grid * grid + 20_000)

        // Đất
        for iz in 0..<grid {
            for ix in 0..<grid {
                let x = (Float(ix) / Float(grid - 1) - 0.5) * size
                let z = (Float(iz) / Float(grid - 1) - 0.5) * size
                let y = 0.12 * sin(3.0 * x) * cos(3.0 * z) + 0.02 * sin(17.0 * x + 11.0 * z)
                pos.append(SIMD3(x, y, z))
                col.append(terrainColor(y))
            }
        }

        // Cột trụ (bán kính 0.15 m, cao 1 m) để nhìn thấy chiều sâu
        let rings = 200, perRing = 100
        for r in 0..<rings {
            let y = Float(r) / Float(rings - 1) * 1.0
            for k in 0..<perRing {
                let a = Float(k) / Float(perRing) * 2 * .pi
                pos.append(SIMD3(0.15 * cos(a), y, 0.15 * sin(a)))
                let g = 0.55 + 0.35 * (0.5 + 0.5 * cos(a * 3))
                col.append(SIMD3(g, g * 0.95, g * 0.9))
            }
        }

        return MetalPointCloud(device: device, positions: pos, colors: col)
    }

    private static func terrainColor(_ y: Float) -> SIMD3<Float> {
        // thấp: xanh nước → cỏ → đất → đỉnh sáng
        let t = simd_clamp((y + 0.14) / 0.28, 0, 1)
        if t < 0.35 { return mix(SIMD3(0.10, 0.35, 0.65), SIMD3(0.20, 0.60, 0.25), t / 0.35) }
        if t < 0.75 { return mix(SIMD3(0.20, 0.60, 0.25), SIMD3(0.55, 0.42, 0.25), (t - 0.35) / 0.40) }
        return mix(SIMD3(0.55, 0.42, 0.25), SIMD3(0.95, 0.95, 0.92), (t - 0.75) / 0.25)
    }

    private static func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> {
        a + (b - a) * t
    }
}

extension SIMD4 {
    /// Tiện lấy .xyz của cột ma trận (project có extension tương tự trong Utils/Ext.swift)
    var xyz: SIMD3<Scalar> { SIMD3(x, y, z) }
}
