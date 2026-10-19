//
//  MetalCommandContext.swift
//  Quick3D
//
//  Created by HaNST on 6/11/25.
//

import Foundation
import Metal

protocol MetalCommand {
    func commit(manager: MetalManager, commandBuffer: MTLCommandBuffer)
    func release()
}

class MetalBlitCommand: MetalCommand {
    
    let context = MetalBlitCommandContext()
    
    init(preparation: ((MetalBlitCommandContext) throws -> Void)? = nil) throws {
        try preparation?(context)
    }
    
    func commit(manager: MetalManager, commandBuffer: MTLCommandBuffer) {
        if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
            context.commit(blitEncoder)
            blitEncoder.endEncoding()
        }
    }
    
    func release() {
        context.release()
    }
}

class MetalComputeCommand: MetalCommand {
    
    let name: String
    let count: Int
    
    private let function: MTLComputePipelineState
    
    let context: MetalComputeCommandContext
    
    init(name: String, count: Int, preparation: ((MetalComputeCommandContext) throws -> Void)? = nil) throws {
        guard count > 0 else { fatalError("Number of elements to process must be greater than zero.") }
        guard let function = MetalManager.shared.makeFunction(name) else { fatalError("Function not found.") }
        self.name = name
        self.count = count
        self.function = function
        
        let maxTotalThreadsPerThreadgroup = function.maxTotalThreadsPerThreadgroup
        let threadExecutionWidth = function.threadExecutionWidth
        let validThreadsPerThreadgroup = sequence(first: threadExecutionWidth, next: { $0 * 2 }).prefix(while: { $0 <= maxTotalThreadsPerThreadgroup })
        let threadgroupCount = validThreadsPerThreadgroup.map { threadsPerThreadgroup in
            let count = Int(ceil(Double(count) / Double(threadsPerThreadgroup)))
            return (count, threadsPerThreadgroup)
        }.min(by: { $0.0 < $1.0 })!
        
        context = MetalComputeCommandContext(threadsPerGroup: threadgroupCount.1, threadgroups: threadgroupCount.0)
        
        try preparation?(context)
    }
    
    func commit(manager: MetalManager, commandBuffer: MTLCommandBuffer) {
        
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            
            var numElements = UInt32(self.count)
            
            computeEncoder.setComputePipelineState(function)
            computeEncoder.setBytes(&numElements, length: MemoryLayout<UInt32>.stride, index: 0)
            context.commit(computeEncoder)
            
            computeEncoder.dispatchThreadgroups(MTLSize(width: context.threadgroups, height: 1, depth: 1),
                                                threadsPerThreadgroup: MTLSize(width: context.threadsPerGroup, height: 1, depth: 1))
            
            computeEncoder.endEncoding()
        }
    }
    
    func release() {
        context.release()
    }
    
}

class MetalRenderCommand: MetalCommand {
    
    let vertex: String
    let fragment: String
    let descriptor: MTLRenderPassDescriptor
    let preparation: ((MTLRenderCommandEncoder) -> Void)?
    
    init(vertex: String, fragment: String, descriptor: MTLRenderPassDescriptor, preparation: ((MTLRenderCommandEncoder) -> Void)? = nil) {
        self.vertex = vertex
        self.fragment = fragment
        self.descriptor = descriptor
        self.preparation = preparation
    }
    
    func commit(manager: MetalManager, commandBuffer: MTLCommandBuffer) {
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor),
           let pipeline = manager.makeFragmentFunction(vertex: vertex, fragment: fragment) {
            renderEncoder.setRenderPipelineState(pipeline)
            self.preparation?(renderEncoder)
            renderEncoder.endEncoding()
        }
    }
    
    func release() {
        
    }
}
