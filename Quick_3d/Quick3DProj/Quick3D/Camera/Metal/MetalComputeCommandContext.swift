//
//  MetalComputeCommandContext.swift
//  Quick3D
//
//  Created by HaNST on 6/11/25.
//

import Foundation
import Metal

class MetalComputeCommandContext {
    
    private var buffers: [MTLBuffer] = []
    private var textures: [MTLTexture] = []
    private var memoryLengths: [Int] = []
    
    let threadsPerGroup: Int
    let threadgroups : Int
    let threads: Int
    
    init(threadsPerGroup: Int, threadgroups: Int) {
        self.threadsPerGroup = threadsPerGroup
        self.threadgroups = threadgroups
        self.threads = threadsPerGroup * threadgroups
    }
    
    func commit(_ encoder: MTLComputeCommandEncoder) {
        for i in 0..<buffers.count {
            encoder.setBuffer(buffers[i], offset: 0, index: i + 1)
        }
        for i in 0..<textures.count {
            encoder.setTexture(textures[i], index: i)
        }
        for i in 0..<memoryLengths.count {
            encoder.setThreadgroupMemoryLength(memoryLengths[i], index: i)
        }
    }
    
    func release() {
        textures.removeAll()
        buffers.removeAll()
        memoryLengths.removeAll()
    }
    
}

extension MetalComputeCommandContext {
    func add(_ buffer: MTLBuffer) {
        buffers.append(buffer)
    }
    
    func add<T>(_ buffer: MetalBuffer<T>) {
        buffers.append(buffer.buffer)
    }
    
    func add<T>(_ data: MetalArray<T>) {
        add(data.info)
        add(data.data)
    }
    
    func add(_ data: MetalPointCloud) {
        add(data.info)
        add(data.positions)
        add(data.colors)
        add(data.indices)
    }

    func add<T>(_ value: T) {
        let buffer = MetalManager.shared.makeBuffer(value: value)!
        add(buffer.buffer)
    }
}

extension MetalComputeCommandContext {
    func add(_ texture: MTLTexture) {
        textures.append(texture)
    }
}

extension MetalComputeCommandContext {
    func add(_ length: Int) {
        memoryLengths.append(length)
    }
}
