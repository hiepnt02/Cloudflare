//
//  MetalArray.swift
//  Quick3D
//
//  Created by HaNST on 6/11/25.
//

import Foundation
import Metal

class MetalArray<Element> {
    
    var info: MetalBuffer<ArrayInfo>
    let data: MetalBuffer<Element>
    
    var size: Int {
        data.count
    }
    
    var count: Int {
        get {
            Int(info[0].index)
        }
        set (value) {
            info[0].index = UInt32(value)
        }
    }
    
    var offset: Int {
        stride * count
    }
    
    var stride: Int {
        data.stride
    }
    
    var buffer: MTLBuffer {
        data.buffer
    }
    
    init(device: MTLDevice, count: Int, label: String? = nil, options: MTLResourceOptions = []) throws {
        self.info = try MetalBuffer(device: device, array: [ArrayInfo(index: 0)])
        self.data = try MetalBuffer(device: device, count: count, options: options)
    }
    
    func remove(offset: Int, size: Int, completion: (() -> Void)? = nil) {
        if let builder = MetalManager.shared.makeCommandBuilder() {
            let count = self.count - offset - size
            if count < 0 {
                print("Temp buffer size: \(self.count) \(offset) \(size)")
            }
            var tempBuffer: MetalBuffer<Element>? = MetalManager.shared.makeBuffer(count: count)!
            
            defer {
                tempBuffer = nil
            }
            
            try? builder.blit { context in
                context.copy(from: self.data, sourceOffset: offset + size, to: tempBuffer!, destinationOffset: 0, size: tempBuffer!.count)
                context.copy(from: tempBuffer!, sourceOffset: 0, to: self.data, destinationOffset: offset, size: tempBuffer!.count)
                context.fill(buffer: self.data, offset: offset + tempBuffer!.count, size: self.count - offset - tempBuffer!.count)
                self.count = self.count - size
            }
            
            builder.onCompleted {
                completion?()
            }
            
            builder.commit()
        }
    }
    
}

extension MTLBlitCommandEncoder {
    func copy<T>(source: MetalArray<T>, destination: MetalArray<T>) {
        copy(from: source.buffer, sourceOffset: 0, to: destination.buffer, destinationOffset:  destination.offset, size: source.offset)
    }
}

extension MetalManager {
    
    func makeArrayBuffer<T>(count: Int, options: MTLResourceOptions = []) -> MetalArray<T>? {
        guard let device = self.device else { return nil }
        return try? MetalArray(device: device, count: count, options: options)
    }
    
    func copy<T>(source: MetalArray<T>, destination: MetalArray<T>, complition: (() -> Void)? = nil) {
        guard destination.count + source.count <= destination.size else {
            complition?()
            return
        }
        
        if let builder = makeCommandBuilder() {
            try? builder.blit { context in
                context.copy(source: source, destination: destination)
            }
            builder.onCompleted {
                destination.count += source.count
                complition?()
            }
            builder.commit()
        }
    }

}
