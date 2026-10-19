import Foundation
import ARKit
import Accelerate

// Mở rộng tiện ích cho simd
extension simd_float4x4 {
    var block3x3: simd_float3x3 {
        simd_float3x3(self.columns.0.xyz, self.columns.1.xyz, self.columns.2.xyz)
    }
}

class FovOverlapCalculator: OverlapCalculator {
    
    var lastFrame: FrameMetadata?
    private var recentDistances: [Float] = []
    private var maxSmoothingFrames = 5
    private let isIphone = UIDevice.current.isIphone
    
    func resetDistances() {
        recentDistances = []
    }
    
    func calculateFromFov(
        _ frame: FrameCalculationData,
        _ scanRatio: Float,
        _ maxSmoothingFrames: Int
    ) -> (Float, Float) {
        self.maxSmoothingFrames = maxSmoothingFrames
        guard let lastFrame = lastFrame else { return (0, 0) }
        
        // 1. Tính toán Z với làm mượt
        let rawZ = calculateDynamicDistance(frame.depthMap, frame.confidenceMap, scanRatio)
        let z = getSmoothedDistance(rawZ)
        
        // 2. Tính toán ma trận tương đối
        let relativeMatrix = frame.transform.inverse * lastFrame.transform
        let t = relativeMatrix.columns.3.xyz
        
        // 3. Xử lý logic riêng cho thiết bị (trục tọa độ)
        let deltaX = isIphone ? abs(t.x) : abs(t.y)
        let deltaY = isIphone ? abs(t.y) : abs(t.x)
        
        // 4. Tính toán Overlap
        let fov = frame.fieldOfView(for: frame.imageResolution)
        let halfWidth = z * tan(fov.horizontal / 2)
        let halfHeight = z * tan(fov.vertical / 2)
        
        let overlap = 1.0 - sqrt(
            pow(deltaX / (halfWidth * 2.0), 2) +
            pow(deltaY / (halfHeight * 2.0), 2) +
            pow(t.z / z, 2)
        )
        
        return (z, max(0.0, min(1.0, overlap)))
    }
    
    // MARK: - Private Helpers
    
    private func getSmoothedDistance(_ newDistance: Float) -> Float {
        recentDistances.append(newDistance)
        if recentDistances.count > maxSmoothingFrames {
            recentDistances.removeFirst()
        }
        return recentDistances.reduce(0, +) / Float(recentDistances.count)
    }
    
    func calculateDynamicDistance(
        _ depthMap: CVPixelBuffer?,
        _ confidenceMap: CVPixelBuffer?,
        _ scanRatio: Float
    ) -> Float {
        guard let depthMap = depthMap else { return 3.0 }
        
        return CVPixelBuffer.withLockedBaseAddress(depthMap, .readOnly) { depthPtr in
            let width = CVPixelBufferGetWidth(depthMap)
            let height = CVPixelBufferGetHeight(depthMap)
            let depthData = depthPtr.assumingMemoryBound(to: Float32.self)
            
            return CVPixelBuffer.withOptionalLockedBaseAddress(confidenceMap, .readOnly) { confPtr in
                let confData = confPtr?.assumingMemoryBound(to: UInt8.self)
                
                var sum: Float = 0
                var count: Int = 0
                
                let midY = height / 2
                let midX = width / 2
                let limitX = Int(Float(width) * (scanRatio / 2))
                let limitY = Int(Float(height) * (scanRatio / 2))
                
                let accumulate = { (x: Int, y: Int) in
                    let index = y * width + x
                    let depth = depthData[index]
                    let conf = confData?[index] ?? 2
                    
                    if depth < 18.0 && (conf == 1 || conf == 2) {
                        sum += depth
                        count += 1
                    }
                }
                
                for i in stride(from: -limitX, to: limitX, by: 5) { accumulate(midX + i, midY) }
                for j in stride(from: -limitY, to: limitY, by: 5) where j != 0 { accumulate(midX, midY + j) }
                
                return count > 0 ? sum / Float(count) : 3.0
            }
        }
    }
}

// Helper để quản lý Locking an toàn hơn
extension CVPixelBuffer {
    static func withLockedBaseAddress<T>(_ buffer: CVPixelBuffer, _ flags: CVPixelBufferLockFlags, _ block: (UnsafeMutableRawPointer) -> T) -> T {
        CVPixelBufferLockBaseAddress(buffer, flags)
        defer { CVPixelBufferUnlockBaseAddress(buffer, flags) }
        return block(CVPixelBufferGetBaseAddress(buffer)!)
    }
    
    static func withOptionalLockedBaseAddress<T>(_ buffer: CVPixelBuffer?, _ flags: CVPixelBufferLockFlags, _ block: (UnsafeMutableRawPointer?) -> T) -> T {
        guard let buffer = buffer else { return block(nil) }
        return withLockedBaseAddress(buffer, flags, block)
    }
}
