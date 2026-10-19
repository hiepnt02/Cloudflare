//
//  MetalCopyContext.swift
//  Quick3D
//
//  Created by Admin on 3/4/26.
//

import Foundation
import Metal

struct MetalCopyItemBuffer {
    let sourceBuffer: MTLBuffer
    let sourceOffset: Int
    let destinationBuffer: MTLBuffer
    let destinationOffset: Int
    let size: Int
}

struct MetalFillItemBuffer {
    let buffer: MTLBuffer
    let offset: Int
    let size: Int
}

struct MetalCopyItemTexture {
    let sourceTexture: MTLTexture
    let destinationTexture: MTLTexture
}


class MetalBlitCommandContext {
    
    private var buffers: [MetalCopyItemBuffer] = []
    private var textures: [MetalCopyItemTexture] = []
    private var filling: [MetalFillItemBuffer] = []
    
    func copy(from sourceBuffer: MTLBuffer, sourceOffset: Int, to destinationBuffer: MTLBuffer, destinationOffset: Int, size: Int) {
        buffers.append(MetalCopyItemBuffer(sourceBuffer: sourceBuffer, sourceOffset: sourceOffset, destinationBuffer: destinationBuffer, destinationOffset: destinationOffset, size: size))
    }
    
    func copy<T>(from sourceBuffer: MetalBuffer<T>, sourceOffset: Int, to destinationBuffer: MetalBuffer<T>, destinationOffset: Int, size: Int) {
        copy(from: sourceBuffer.buffer, sourceOffset: sourceOffset * sourceBuffer.stride, to: destinationBuffer.buffer, destinationOffset: destinationOffset * destinationBuffer.stride, size: size * destinationBuffer.stride)
    }
    
    func copy<T>(source: MetalArray<T>, destination: MetalArray<T>) {
        buffers.append(MetalCopyItemBuffer(sourceBuffer: source.buffer, sourceOffset: 0, destinationBuffer: destination.buffer, destinationOffset:  destination.offset, size: source.offset))
    }
    
    func copy(source: MTLTexture, destination: MTLTexture) {
        textures.append(MetalCopyItemTexture(sourceTexture: source, destinationTexture: destination))
    }
    
    func fill<T>(buffer: MetalBuffer<T>, offset: Int, size: Int) {
        filling.append(MetalFillItemBuffer(buffer: buffer.buffer, offset: offset * buffer.stride, size: size * buffer.stride))
    }
    
    func release() {
        buffers.removeAll()
        textures.removeAll()
        filling.removeAll()
    }
    
    func commit(_ encoder: MTLBlitCommandEncoder) {
        for i in 0..<buffers.count {
            let buffer = buffers[i]
            encoder.copy(from: buffer.sourceBuffer, sourceOffset: buffer.sourceOffset, to: buffer.destinationBuffer, destinationOffset: buffer.destinationOffset, size: buffer.size)
        }
        for i in 0..<textures.count {
            let texture = textures[i]
            encoder.copy(from: texture.sourceTexture, to: texture.destinationTexture)
        }
        for i in 0..<filling.count {
            let f = filling[i]
            encoder.fill(buffer: f.buffer, range: f.offset..<f.offset+f.size, value: 0)
        }
    }
}

