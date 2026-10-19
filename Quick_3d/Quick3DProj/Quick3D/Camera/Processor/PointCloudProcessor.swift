//
//  PointCloudProcessor.swift
//  Quick3D
//
//  Created by HaNST on 13/11/24.
//

import Metal
import MetalKit
import simd
import SceneKit

class PointCloudProcessor: FrameProcessor {
    
    private var queue = JobManager(maxCount: 10)
    
    var count: Int {
        queue.count
    }
    
    var isLimited: Bool {
        queue.isLimited
    }
    
    func process(_ session: CaptureSession, frame: FrameData, onCompleted: (() -> Void)? = nil, onError: ((Error) -> Void)? = nil) {
        guard MetalManager.shared.isReady else  { return }
        let operation = MetalManager.shared.isPrefixSumSupported ? MetalPointCloudOperation(session, frame: frame) : DefaultPointCloudOperation(session, frame: frame)
        queue.addTask(operation)
    }
    
    func waitUntilCompleted() {
        queue.waitUntilCompleted()
    }
    
    func cancel() {
        queue.cancel()
    }
    
}

class PointCloudHelper {

    static var defaultGridSpacing: Float { 20.0 }
    
    static func makeGridPoints(_ frame: FrameData, spacing: Float) -> [SIMD2<Float>] {
        let x = Float(frame.width)
        let y = Float(frame.height)
        let deltaX = Int(round(x / spacing))
        let deltaY = Int(round(y / spacing))

        var points = [SIMD2<Float>]()
        for gridY in 0..<deltaY {
            let alternatingOffsetX = Float(gridY % 2) * spacing / 2
            for gridX in 0..<deltaX {
                let cameraPoint = SIMD2<Float>(
                    alternatingOffsetX + (Float(gridX) + 0.5) * spacing,
                    (Float(gridY) + 0.5) * spacing)
                points.append(cameraPoint)
            }
        }

        return points
    }
    
    static func makeGrid(_ frame: FrameData, spacing: Float) -> SIMD2<Int32> {
        let x = Float(frame.width)
        let y = Float(frame.height)
        let deltaX = Int32(round(x / spacing))
        let deltaY = Int32(round(y / spacing))
        return [deltaX, deltaY]
    }
    
    static func makeFrameConfiguration(_ frame: FrameData) -> FrameConfiguration {
        
        let rotateToARCamera = frame.rotateMatrix
        let cameraIntrinsicsInversed = frame.intrinsics.inverse
        let viewMatrix = frame.viewMatrix
        let viewMatrixInversed = viewMatrix.inverse
        let projectionMatrix = frame.projectionMatrix
        
        var configuration = FrameConfiguration()
        
        configuration.cameraResolution = SIMD2<Float>(x: Float(frame.width), y: Float(frame.height))
        configuration.viewProjectionMatrix = projectionMatrix * viewMatrix
        configuration.localToWorld = viewMatrixInversed * rotateToARCamera
        configuration.cameraIntrinsicsInversed = cameraIntrinsicsInversed
        
        let spacing = CaptureSession.current?.pointClouds.spacing ?? defaultGridSpacing
        
        configuration.grid = makeGrid(frame, spacing: spacing)
        configuration.spacing = spacing
        configuration.count = configuration.grid.x * configuration.grid.y
        
        return configuration
    }
    
}
