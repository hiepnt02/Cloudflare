//
//  MetalPointCloudOperation.swift
//  Quick3D
//
//  Created by HaNST on 5/3/26.
//

import Foundation

class MetalPointCloudOperationBuffers {
    
    public private(set) var configurationBuffer : MetalBuffer<FrameConfiguration>?
    public private(set) var tempPositionsBuffer: MetalBuffer<SIMD3<Float>>?
    public private(set) var tempColorsBuffer: MetalBuffer<SIMD3<Float>>?
    public private(set) var tempConfidenceBuffer: MetalBuffer<Float>?
    
    public private(set) var threadgroupsIndexBuffer: MetalBuffer<UInt32>?
    public private(set) var threadsIndexBuffer: MetalBuffer<UInt32>?
    
    public private(set) var tempPointCloudsBuffer: MetalPointCloud?
    
    private weak var manager: MetalManager?
    
    init(manager: MetalManager) {
        self.manager = manager
    }

    func process(threadgroups : Int, threads: Int, configuration: FrameConfiguration) throws {
        if tempPositionsBuffer == nil || tempPositionsBuffer!.count != threads {
            tempPositionsBuffer = manager?.makeBuffer(count: threads, options: .storageModePrivate)
        }
        
        if tempColorsBuffer == nil || tempColorsBuffer!.count != threads {
            tempColorsBuffer = manager?.makeBuffer(count: threads, options: .storageModePrivate)
        }
        
        if tempConfidenceBuffer == nil || tempConfidenceBuffer!.count != threads {
            tempConfidenceBuffer = manager?.makeBuffer(count: threads, options: .storageModePrivate)
        }
        
        if threadsIndexBuffer == nil || threadsIndexBuffer!.count != threads {
            threadsIndexBuffer = manager?.makeBuffer(count: threads, options: .storageModePrivate)
        }
        
        if threadgroupsIndexBuffer == nil || threadgroupsIndexBuffer!.count != threadgroups {
            threadgroupsIndexBuffer = manager?.makeBuffer(count: threadgroups, options: .storageModePrivate)
        }
        
        if configurationBuffer == nil {
            configurationBuffer = manager?.makeBuffer(value: configuration)
        } else {
            configurationBuffer![0] = configuration
        }
        
        if tempPointCloudsBuffer == nil || tempPointCloudsBuffer!.count != threads {
            tempPointCloudsBuffer = manager?.makePointCloud(size: threads, options: .storageModePrivate)
        }

        if tempPositionsBuffer == nil
            || tempColorsBuffer == nil
            || tempConfidenceBuffer == nil
            || threadsIndexBuffer == nil
            || threadgroupsIndexBuffer == nil
            || configurationBuffer == nil
            || tempPointCloudsBuffer == nil {
            throw NSError(domain: "MetalPointCloudProcessBuffers", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer."])
        }
        
    }
    
}

final class MetalPointCloudOperation: FrameOperation, @unchecked Sendable {
    
    private static let buffers = MetalPointCloudOperationBuffers(manager: MetalManager.shared)
    
    override func process() throws {
        
        let manager = MetalManager.shared
        
        guard let session = self.session,
              let frame = self.frame,
              let commandBuilder = manager.makeCommandBuilder() else {
            self.finish()
            return
        }
        
        let configuration = PointCloudHelper.makeFrameConfiguration(frame)
        let count = Int(configuration.count)
        
        try commandBuilder.compute(name: "unprojectVertex", count: count, preparation: { context in
            
            try Self.buffers.process(threadgroups: context.threadgroups, threads: context.threads, configuration: configuration)
            
            context.add(Self.buffers.configurationBuffer!)
            context.add(Self.buffers.threadsIndexBuffer!)
            context.add(Self.buffers.threadgroupsIndexBuffer!)
            context.add(Self.buffers.tempPositionsBuffer!)
            context.add(Self.buffers.tempColorsBuffer!)
            context.add(Self.buffers.tempConfidenceBuffer!)
            
            context.add(MetalManager.shared.makeTexture(from: frame.capturedImage, format: .r8Unorm, planeIndex: 0)!)
            context.add(MetalManager.shared.makeTexture(from: frame.capturedImage, format: .rg8Unorm, planeIndex: 1)!)
            context.add(MetalManager.shared.makeTexture(from: frame.depthMap, format: .r32Float, planeIndex: 0)!)
            context.add(MetalManager.shared.makeTexture(from: frame.confidenceMap, format: .r8Uint, planeIndex: 0)!)
            
            context.add(MemoryLayout<Float>.stride * Int(context.threadsPerGroup))
        })
        
        try commandBuilder.compute(name: "merge", count: count, preparation: { context in
            context.add(Self.buffers.threadsIndexBuffer!)
            context.add(Self.buffers.threadgroupsIndexBuffer!)
            context.add(Self.buffers.tempPositionsBuffer!)
            context.add(Self.buffers.tempColorsBuffer!)
            context.add(Self.buffers.tempConfidenceBuffer!)
            context.add(Self.buffers.tempPointCloudsBuffer!)
        })
        
        try commandBuilder.compute(name: "copyPointCloud", count: count, preparation: { context in
            
            let pointCloud = try session.pointClouds.last(count)
            
            context.add(Self.buffers.tempPointCloudsBuffer!.positions)
            context.add(Self.buffers.tempPointCloudsBuffer!.colors)
            context.add(Self.buffers.tempPointCloudsBuffer!.info)
            context.add(UInt32(pointCloud.count))
            context.add(pointCloud.positions)
            context.add(pointCloud.colors)
            context.add(pointCloud.info)
        })
        
        commandBuilder.onCompleted {
            session.cameras.append(frame)
            session.pointClouds.update()
            self.finish()
            self.onCompleted?()
        }
        
        commandBuilder.commit()
    }
    
    override func clear() {
        super.clear()
        Self.buffers.tempPointCloudsBuffer?.count = 0
    }
    
}
