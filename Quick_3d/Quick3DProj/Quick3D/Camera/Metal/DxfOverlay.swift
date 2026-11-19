//
//  DxfOverlay.swift
//  Quick3D
//

import Foundation
import Metal

/// Top-down DXF texture for the AR point overlay (SC_QUICK-1986), the same data as the web
/// viewer's dxf-texture.ts: each texel holds the RGB of the nearest DXF edge and, in alpha,
/// its distance mapped 0...maxDistance → 0...254 (255 = no edge within maxDistance).
/// Texel (i, j) is centered on easting minE + (i + 0.5) / width * spanE and on
/// -northing minMN + (j + 0.5) / height * spanMN.
struct DxfOverlayTexture {
    let texture: MTLTexture
    let minE: Double
    let minMN: Double
    let spanE: Double
    let spanMN: Double
}

enum DxfOverlayBuilder {

    /// Largest texture side, as on the web (≤ 2048² × 4 B = 16 MB).
    static let maxTextureSize = 2048
    /// Distance the texture covers around the edges, in meters.
    static let maxDistance: Float = 10
    /// Edges are split into short pieces so the KD-tree prunes well (the search margin is
    /// half the longest piece); the nearest edge does not change. The web splits at 25 m;
    /// 4 m makes the fill about 4× faster, which matters in unoptimized Debug builds.
    private static let maxSegmentLength: Double = 4

    private struct Segment {
        var x1: Float
        var z1: Float
        var x2: Float
        var z2: Float
        var mx: Float
        var mz: Float
        var color: UInt32
    }

    private struct SearchEntry {
        var lo: Int32
        var hi: Int32
        var depth: Int32
        var bound: Float
    }

    /// CPU work (KD-tree over the edges, then one nearest-edge query per texel), meant to run
    /// off the main thread. It uses half the cores so the point cloud keeps loading meanwhile.
    static func build(edges: [DxfEdge], device: MTLDevice) -> DxfOverlayTexture? {
        guard !edges.isEmpty else { return nil }

        // Work in (easting, -northing): the frame of the point positions' x and z.
        var minE = Double.infinity, maxE = -Double.infinity
        var minMN = Double.infinity, maxMN = -Double.infinity
        for edge in edges {
            minE = Swift.min(minE, edge.x1, edge.x2)
            maxE = Swift.max(maxE, edge.x1, edge.x2)
            minMN = Swift.min(minMN, -edge.y1, -edge.y2)
            maxMN = Swift.max(maxMN, -edge.y1, -edge.y2)
        }
        let pad = Double(maxDistance)
        minE -= pad; maxE += pad; minMN -= pad; maxMN += pad
        let spanE = maxE - minE
        let spanMN = maxMN - minMN
        let texel = Swift.max(spanE, spanMN) / Double(maxTextureSize)
        let width = Swift.max(1, Int((spanE / texel).rounded(.up)))
        let height = Swift.max(1, Int((spanMN / texel).rounded(.up)))

        // Local coordinates (relative to the texture corner) keep Float precise.
        var segments = tessellate(edges, minE: minE, minMN: minMN)
        var margin: Float = 0
        for s in segments {
            margin = Swift.max(margin, ((s.x2 - s.x1) * (s.x2 - s.x1) + (s.z2 - s.z1) * (s.z2 - s.z1)).squareRoot() * 0.5)
        }
        buildTree(&segments, lo: 0, hi: segments.count, depth: 0)

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let maxDistance2 = maxDistance * maxDistance
        let workers = Swift.max(1, Swift.min(height, ProcessInfo.processInfo.activeProcessorCount / 2))

        segments.withUnsafeBufferPointer { tree in
            pixels.withUnsafeMutableBufferPointer { output in
                let out = output.baseAddress!
                // Interleaved rows keep the workers evenly loaded (edges cluster in places).
                DispatchQueue.concurrentPerform(iterations: workers) { worker in
                    let stack = UnsafeMutablePointer<SearchEntry>.allocate(capacity: stackCapacity(segments: tree.count))
                    defer { stack.deallocate() }
                    for j in stride(from: worker, to: height, by: workers) {
                        let qz = Float((Double(j) + 0.5) / Double(height) * spanMN)
                        for i in 0..<width {
                            let qx = Float((Double(i) + 0.5) / Double(width) * spanE)
                            let o = (j * width + i) * 4
                            guard let (index, distance2) = nearest(qx, qz, tree, margin: margin, limit2: maxDistance2, stack: stack) else {
                                out[o + 3] = 255
                                continue
                            }
                            let color = tree[index].color
                            out[o] = UInt8((color >> 16) & 0xFF)
                            out[o + 1] = UInt8((color >> 8) & 0xFF)
                            out[o + 2] = UInt8(color & 0xFF)
                            out[o + 3] = UInt8(Swift.min(254, (distance2.squareRoot() / maxDistance * 254).rounded()))
                        }
                    }
                }
            }
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = .shaderRead
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        pixels.withUnsafeBytes { bytes in
            texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                            withBytes: bytes.baseAddress!, bytesPerRow: width * 4)
        }
        return DxfOverlayTexture(texture: texture, minE: minE, minMN: minMN, spanE: spanE, spanMN: spanMN)
    }

    private static func tessellate(_ edges: [DxfEdge], minE: Double, minMN: Double) -> [Segment] {
        var segments: [Segment] = []
        segments.reserveCapacity(edges.count)
        for edge in edges {
            let x1 = edge.x1 - minE, z1 = -edge.y1 - minMN
            let dx = edge.x2 - minE - x1, dz = -edge.y2 - minMN - z1
            let pieces = Swift.max(1, Int(((dx * dx + dz * dz).squareRoot() / maxSegmentLength).rounded(.up)))
            var px = x1, pz = z1
            for k in 1...pieces {
                let t = Double(k) / Double(pieces)
                let nx = x1 + dx * t, nz = z1 + dz * t
                segments.append(Segment(x1: Float(px), z1: Float(pz), x2: Float(nx), z2: Float(nz),
                                        mx: Float((px + nx) * 0.5), mz: Float((pz + nz) * 0.5), color: edge.color))
                px = nx; pz = nz
            }
        }
        return segments
    }

    /// Implicit KD-tree: the node of [lo, hi) is the median at (lo + hi) / 2, split on the
    /// midpoint x at even depths and z at odd ones.
    private static func buildTree(_ segments: inout [Segment], lo: Int, hi: Int, depth: Int) {
        guard hi - lo > 1 else { return }
        let mid = (lo + hi) >> 1
        select(&segments, lo: lo, hi: hi, k: mid, onX: depth % 2 == 0)
        buildTree(&segments, lo: lo, hi: mid, depth: depth + 1)
        buildTree(&segments, lo: mid + 1, hi: hi, depth: depth + 1)
    }

    /// Quickselect: puts the k-th smallest of [lo, hi) at k, smaller keys before it.
    private static func select(_ segments: inout [Segment], lo: Int, hi: Int, k: Int, onX: Bool) {
        func key(_ s: Segment) -> Float { onX ? s.mx : s.mz }
        var left = lo
        var right = hi - 1
        while left < right {
            let pivot = key(segments[(left + right) >> 1])
            var i = left
            var j = right
            while i <= j {
                while key(segments[i]) < pivot { i += 1 }
                while key(segments[j]) > pivot { j -= 1 }
                if i <= j {
                    segments.swapAt(i, j)
                    i += 1
                    j -= 1
                }
            }
            if k <= j {
                right = j
            } else if k >= i {
                left = i
            } else {
                return
            }
        }
    }

    /// Each visit pops one entry and pushes two, and the tree is log2(n) deep.
    private static func stackCapacity(segments: Int) -> Int {
        return 2 * (Int.bitWidth - segments.leadingZeroBitCount) + 4
    }

    /// Nearest segment to (qx, qz) closer than sqrt(limit2), as the web's KD-tree search:
    /// the near side first, the far side only if the split plane minus the longest
    /// half-segment is still closer than the best so far. Raw pointers keep this hot loop
    /// usable in unoptimized (Debug) builds too.
    private static func nearest(_ qx: Float, _ qz: Float, _ tree: UnsafeBufferPointer<Segment>, margin: Float,
                                limit2: Float, stack: UnsafeMutablePointer<SearchEntry>) -> (Int, Float)? {
        guard let segments = tree.baseAddress else { return nil }
        var best = limit2
        var bestIndex = -1
        var top = 0
        stack[0] = SearchEntry(lo: 0, hi: Int32(tree.count), depth: 0, bound: 0)
        top = 1
        while top > 0 {
            top -= 1
            let entry = stack[top]
            if entry.bound > 0, entry.bound * entry.bound >= best { continue }
            let lo = Int(entry.lo), hi = Int(entry.hi)
            guard lo < hi else { continue }
            let mid = (lo + hi) >> 1
            let s = segments[mid]

            let dx = s.x2 - s.x1, dz = s.z2 - s.z1
            let length2 = dx * dx + dz * dz
            var t: Float = length2 > 0 ? ((qx - s.x1) * dx + (qz - s.z1) * dz) / length2 : 0
            if t < 0 { t = 0 } else if t > 1 { t = 1 }
            let ax = qx - (s.x1 + t * dx), az = qz - (s.z1 + t * dz)
            let distance2 = ax * ax + az * az
            if distance2 < best {
                best = distance2
                bestIndex = mid
            }

            let diff = entry.depth & 1 == 0 ? qx - s.mx : qz - s.mz
            let gap = (diff < 0 ? -diff : diff) - margin
            let farBound: Float = gap > 0 ? gap : 0
            let left = SearchEntry(lo: entry.lo, hi: Int32(mid), depth: entry.depth + 1, bound: diff < 0 ? 0 : farBound)
            let right = SearchEntry(lo: Int32(mid + 1), hi: entry.hi, depth: entry.depth + 1, bound: diff < 0 ? farBound : 0)
            // Popped last-in first: the near side is searched first.
            stack[top] = diff < 0 ? right : left
            stack[top + 1] = diff < 0 ? left : right
            top += 2
        }
        return bestIndex >= 0 ? (bestIndex, best) : nil
    }
}
