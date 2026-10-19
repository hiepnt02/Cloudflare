//
//  DefaultPointCloudOperation.swift
//  Quick3D
//
//  Created by HaNST on 5/3/26.
//

import Foundation

class DefaultPointCloudOperationBuffers {
    
    public private(set) var configurationBuffer : MetalBuffer<FrameConfiguration>?
    public private(set) var tempPositionsBuffer: MetalBuffer<SIMD3<Float>>?
    public private(set) var tempColorsBuffer: MetalBuffer<SIMD3<Float>>?
    public private(set) var tempConfidenceBuffer: MetalBuffer<Float>?
    
    public private(set) var tempPointCloudsBuffer: MetalPointCloud?
    
    private weak var manager: MetalManager?
    
    init(manager: MetalManager) {
        self.manager = manager
    }

    func process(threadgroups : Int, threads: Int, configuration: FrameConfiguration) throws {
        if tempPositionsBuffer == nil || tempPositionsBuffer!.count != threads {
            tempPositionsBuffer = manager?.makeBuffer(count: threads, options: .storageModeShared)
        }
        
        if tempColorsBuffer == nil || tempColorsBuffer!.count != threads {
            tempColorsBuffer = manager?.makeBuffer(count: threads, options: .storageModeShared)
        }
        
        if tempConfidenceBuffer == nil || tempConfidenceBuffer!.count != threads {
            tempConfidenceBuffer = manager?.makeBuffer(count: threads, options: .storageModeShared)
        }
        
        if configurationBuffer == nil {
            configurationBuffer = manager?.makeBuffer(value: configuration)
        } else {
            configurationBuffer![0] = configuration
        }
        
        if tempPointCloudsBuffer == nil || tempPointCloudsBuffer!.count != threads {
            tempPointCloudsBuffer = manager?.makePointCloud(size: threads, options: .storageModeShared)
        }

        if tempPositionsBuffer == nil
            || tempColorsBuffer == nil
            || tempConfidenceBuffer == nil
            || configurationBuffer == nil
            || tempPointCloudsBuffer == nil {
            throw NSError(domain: "MetalPointCloudProcessBuffers", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer."])
        }
        
    }
    
}

final class DefaultPointCloudOperation: FrameOperation, @unchecked Sendable {

    private static let buffers = DefaultPointCloudOperationBuffers(manager: MetalManager.shared)
    
    override func process() throws {
        
        let manager = MetalManager.shared
        
        guard let session = self.session,
              let frame = self.frame,
              let commandBuilder = manager.makeCommandBuilder() else {
            self.finish()
            return
        }
        
        session.cameras.append(frame)
        
        let configuration = PointCloudHelper.makeFrameConfiguration(frame)
        
        let count = Int(configuration.count)
        
        let pointCloud = try session.pointClouds.last(count)
        
        commandBuilder.add(try MetalComputeCommand(name: "unprojectVertexWithoutPrefixSum", count: count, preparation: { context in
            
            try Self.buffers.process(threadgroups: context.threadgroups, threads: context.threads, configuration: configuration)
            
            context.add(Self.buffers.configurationBuffer!)
            context.add(Self.buffers.tempPositionsBuffer!)
            context.add(Self.buffers.tempColorsBuffer!)
            context.add(Self.buffers.tempConfidenceBuffer!)
            
            context.add(MetalManager.shared.makeTexture(from: frame.capturedImage, format: .r8Unorm, planeIndex: 0)!)
            context.add(MetalManager.shared.makeTexture(from: frame.capturedImage, format: .rg8Unorm, planeIndex: 1)!)
            context.add(MetalManager.shared.makeTexture(from: frame.depthMap, format: .r32Float, planeIndex: 0)!)
            context.add(MetalManager.shared.makeTexture(from: frame.confidenceMap, format: .r8Uint, planeIndex: 0)!)
            
            context.add(MemoryLayout<Float>.stride * Int(context.threadsPerGroup))
        }))
        
        commandBuilder.onCompleted {
            
            let positions = Self.buffers.tempPositionsBuffer!.range(at: 0)
            let colors = Self.buffers.tempColorsBuffer!.range(at: 0)
            let confidence = Self.buffers.tempConfidenceBuffer!.range(at: 0)
            
            var tempPositions: [SIMD3<Float>] = []
            var tempColors: [SIMD3<Float>] = []
            
            for i in 0..<positions.count {
                if confidence[i] >= 1 {
                    tempPositions.append(positions[i])
                    tempColors.append(colors[i])
                }
            }
            
            if tempPositions.count == 0 {
                self.finish()
                self.onCompleted?()
                return
            }
            
            Self.buffers.tempPointCloudsBuffer?.assign(positions: tempPositions, colors: tempColors)
            
            manager.copy(source: Self.buffers.tempPointCloudsBuffer!, destination: pointCloud) { destination, _ in
                session.pointClouds.update()
                self.finish()
                self.onCompleted?()
            }
            
        }
        
        commandBuilder.commit()
            
    }
    
    override func clear() {
        super.clear()
        Self.buffers.tempPointCloudsBuffer?.count = 0
    }
}
