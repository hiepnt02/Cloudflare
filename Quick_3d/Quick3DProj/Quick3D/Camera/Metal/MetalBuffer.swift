//
//  MetalBuffer.swift
//  Quick3D
//
//  Created by HaNST on 13/11/24.
//

import MetalKit

struct MetalBuffer<Element> {
        
    let buffer: MTLBuffer
    
    let count: Int
    
    let stride: Int

    init(device: MTLDevice, count: Int, label: String? = nil, options: MTLResourceOptions = []) throws {
        
        guard let buffer = device.makeBuffer(length: MemoryLayout<Element>.stride * count, options: options) else {
            throw NSError(domain: "MetalBuffer", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer."])
        }
        
        self.buffer = buffer
        self.buffer.label = label
        self.count = count
        self.stride = MemoryLayout<Element>.stride
    }
    
    init(device: MTLDevice, array: [Element], label: String? = nil) throws {
        
        let _buffer = array.withUnsafeBytes { bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: MemoryLayout<Element>.stride * array.count, options: .storageModeShared)
        }
        
        guard let buffer = _buffer else {
            throw NSError(domain: "MetalBuffer", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer."])
        }
        
        self.buffer = buffer
        self.buffer.label = label
        self.count = array.count
        self.stride = MemoryLayout<Element>.stride
    }
    
    init(device: MTLDevice, value: Element, label: String? = nil) throws {
        try self.init(device: device, array: [value], label: label)
    }
    
    init(buffer: MTLBuffer, count: Int) {
        self.buffer = buffer
        self.count = count
        self.stride = MemoryLayout<Element>.stride
    }
    
    func assign(_ value: Element, at index: Int = 0) {
        precondition(index <= count - 1, "Index \(index) is greater than maximum allowable index of \(count - 1) for this buffer.")
        withUnsafePointer(to: value) {
            buffer.contents().advanced(by: index * stride).copyMemory(from: $0, byteCount: stride)
        }
    }
    
    func assign(with array: [Element]) {
        let byteCount = array.count * stride
        precondition(byteCount <= buffer.length, "Mismatch between the byte count of the array's contents and the MTLBuffer length.")
        
        array.withUnsafeBytes { bytes in
            let pointer = buffer.contents()
            pointer.copyMemory(from: bytes.baseAddress!, byteCount: byteCount)
        }
    }
    
    subscript(index: Int) -> Element {
        get {
            precondition(stride * index <= buffer.length - stride, "This buffer is not large enough to have an element at the index: \(index)")
            return buffer.contents().advanced(by: index * stride).load(as: Element.self)
        }
        
        set {
            assign(newValue, at: index)
        }
    }
    
    func range(at index: Int, length: Int, size: Int?) -> [Element] {
        let max = size ?? self.count
        if index >= max {
            return []
        }
        var count = length
        if index + length >= max {
            count = max - index
        }
        let ptr = buffer.contents().advanced(by: index * stride).bindMemory(to: Element.self, capacity: count)
        let array = Array(UnsafeBufferPointer(start: ptr, count: count))
        return array
    }
    
    func range(at index: Int) -> [Element] {
        if index >= self.count {
            return []
        }
        let ptr = buffer.contents().advanced(by: index * stride).bindMemory(to: Element.self, capacity: count)
        let array = Array(UnsafeBufferPointer(start: ptr, count: count))
        return array
    }
    
    func desciption() {
        var array: [Element] = []
        let pointer = buffer.contents().bindMemory(to: Element.self, capacity: count)
        for i in 0..<count {
            array.append(pointer[i])
        }
        print("MetalBuffer: \(array)")
    }
    
}

extension MTLComputeCommandEncoder {
    func setBuffer<T>(_ buffer: MetalBuffer<T>, offset: Int = 0, index: Int) {
        setBuffer(buffer.buffer, offset: offset, index: index)
    }
}

extension MetalManager {
    
    func makeBuffer<T>(array: [T]) -> MetalBuffer<T>? {
        guard let device = device else { return nil }
        return try? MetalBuffer<T>(device: device, array: array)
    }
    
    func makeBuffer<T>(value: T) -> MetalBuffer<T>? {
        guard let device = device else { return nil }
        return try? MetalBuffer<T>(device: device, value: value)
    }
    
    func makeBuffer<T>(count: Int, options: MTLResourceOptions = []) -> MetalBuffer<T>? {
        guard let device = device else { return nil }
        return try? MetalBuffer<T>(device: device, count: count, options: options)
    }
    
}
