//
//  MTLManager.swift
//  Quick3D
//
//  Created by HaNST on 31/10/25.
//

import Foundation
import Metal
import CoreVideo
import ARKit

class MetalManager {
    
    static let shared = MetalManager()
    
    public private(set) var device: MTLDevice?
    
    private lazy var library = makeLibrary()
    private lazy var commandQueue = makeCommandQueue()
    private lazy var textureCache = makeTextureCache()
    
    // Lock để đảm bảo thread-safe cho cache
    private let lock = NSLock()
    private var functions: [String: MTLComputePipelineState] = [:]
    private var fragmentFunctions: [String: MTLRenderPipelineState] = [:]
    
    public var count: ThreadSafeValue<Int> = .init(0)
    
    var isReady: Bool {
        return device != nil
    }
    
    let isPrefixSumSupported: Bool
    
    init() {
        self.device = MTLCreateSystemDefaultDevice()
        self.isPrefixSumSupported = device?.supportsFamily(.apple8) ?? false
    }
    
    private func makeLibrary() -> MTLLibrary? {
        return device?.makeDefaultLibrary()
    }
    
    private func makeCommandQueue() -> MTLCommandQueue? {
        return device?.makeCommandQueue()
    }
    
    private func makeTextureCache() -> CVMetalTextureCache? {
        guard let device = self.device else { return nil }
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
        return cache
    }
    
    func makeCommandBuffer() -> MTLCommandBuffer? {
        return commandQueue?.makeCommandBuffer()
    }
    
    func makeFunction(_ name: String) -> MTLComputePipelineState? {
        lock.lock()
        defer {
            lock.unlock()
        }
        
        if let function = self.functions[name] {
            return function
        }
        
        guard let library = self.library,
              let function = library.makeFunction(name: name) else { return nil }
        
        do {
            let pipeline = try device?.makeComputePipelineState(function: function)
            if let pipeline = pipeline {
                self.functions[name] = pipeline
            }
            return pipeline
        } catch {
            print("Error creating compute pipeline for \(name): \(error)")
            return nil
        }
    }
    
    func makeFragmentFunction(vertex: String, fragment: String) -> MTLRenderPipelineState? {
        lock.lock()
        defer {
            lock.unlock()
        }
        
        let name = "\(vertex):\(fragment)"
        
        if let function = self.fragmentFunctions[name] {
            return function
        }
        
        guard let library = self.library,
              let vertexFunction = library.makeFunction(name: vertex),
              let fragmentFunction = library.makeFunction(name: fragment)
        else { return nil }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            let pipeline = try device?.makeRenderPipelineState(descriptor: descriptor)
            if let pipeline = pipeline {
                self.fragmentFunctions[name] = pipeline
            }
            return pipeline
        } catch {
            print("Error creating render pipeline for \(name): \(error)")
            return nil
        }
    }
    
    func makeComputeCommandEncoder(_ name: String) -> (buffer: MTLCommandBuffer, encoder: MTLComputeCommandEncoder)? {
        guard let commandBuffer = self.commandQueue?.makeCommandBuffer(),
              let function = makeFunction(name),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder()
        else { return nil }
        
        computeEncoder.setComputePipelineState(function)
        return (commandBuffer, computeEncoder)
    }
    
    // MARK: - Copy Operations (Optimized with guard)
    func copy(source: MTLTexture, destination: MTLTexture, complition: (() -> Void)? = nil) {
        if let builder = makeCommandBuilder() {
            try? builder.blit { context in
                context.copy(source: source, destination: destination)
            }
            builder.onCompleted {
                complition?()
            }
            builder.commit()
        }
    }
    
    func copyTexture(from pixelBuffer: CVPixelBuffer, format: MTLPixelFormat, planeIndex: Int, complition: (() -> Void)? = nil) -> MTLTexture? {
        guard let source = makeTexture(from: pixelBuffer, format: format, planeIndex: planeIndex) else { return nil }
        
        guard let destination = makeTexture(width: source.width,
                                            height: source.height,
                                            pixelFormat: source.pixelFormat,
                                            usage: [.shaderRead, .shaderWrite]) else { return nil }
    
        copy(source: source, destination: destination, complition: complition)
        return destination
    }
    
    func makeTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat, usage: MTLTextureUsage = []) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
        descriptor.usage = usage
        return device?.makeTexture(descriptor: descriptor)
    }
    
    func makeTexture(from pixelBuffer: CVPixelBuffer, format: MTLPixelFormat, planeIndex: Int) -> MTLTexture? {
        guard let textureCache = textureCache else { return nil }
        
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        
        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, format, width, height, planeIndex, &cvTexture)
        
        guard status == kCVReturnSuccess, let unwrappedTexture = cvTexture else { return nil }
        return CVMetalTextureGetTexture(unwrappedTexture)
    }
    
}


// MARK: - Image Conversion & Frame Processing
extension MetalManager {
    
    func convertToRGBTexture(yTexture: MTLTexture, cbcrTexture: MTLTexture) -> MTLTexture? {
        guard let outputTexture = makeTexture(width: yTexture.width, height: yTexture.height, pixelFormat: .bgra8Unorm, usage: [.renderTarget, .shaderRead, .shaderWrite]) else { return nil }

        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = outputTexture
        renderPass.colorAttachments[0].loadAction = .clear
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)

        guard let commandBuffer = commandQueue?.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass),
              let pipeline = makeFragmentFunction(vertex: "vertexPassthrough", fragment: "ycbcrToRGBFragment")
        else { return nil }

        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(yTexture, index: 0)
        encoder.setFragmentTexture(cbcrTexture, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.commit()
        // Tối ưu: Chỉ dùng waitUntilCompleted() nếu thực sự cần dữ liệu ngay lập tức trên luồng này.
        commandBuffer.waitUntilCompleted()

        return outputTexture
    }
    
    func convertToRGBTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard isReady else { return nil }
        
        let yTexture = makeTexture(from: pixelBuffer, format: .r8Unorm, planeIndex: 0)
        let cbcrTexture = makeTexture(from: pixelBuffer, format: .rg8Unorm, planeIndex: 1)
        
        guard let y = yTexture, let cbcr = cbcrTexture else { return nil }
        return convertToRGBTexture(yTexture: y, cbcrTexture: cbcr)
    }
    
    func makeFrameData(_ frame: ARFrame, index: Int, fps: Int = 0, completion: ((FrameData?) -> Void)?) {
        guard isReady, CVPixelBufferGetPlaneCount(frame.capturedImage) >= 2 else {
            completion?(nil)
            return
        }

        guard let depthMap = frame.sceneDepth?.depthMap,
              let confidenceMap = frame.sceneDepth?.confidenceMap,
              let builder = makeCommandBuilder()
        else {
            completion?(nil)
            return
        }
        
        // Sử dụng autoreleasepool để giải phóng các texture tạm thời của AR ngay lập tức
        autoreleasepool {
            let _imageY = makeTexture(from: frame.capturedImage, format: .r8Unorm, planeIndex: 0)
            let _imageCbCr = makeTexture(from: frame.capturedImage, format: .rg8Unorm, planeIndex: 1)
            let _depthMap = makeTexture(from: depthMap, format: .r32Float, planeIndex: 0)
            let _confidenceMap = makeTexture(from: confidenceMap, format: .r8Uint, planeIndex: 0)
            
            guard let y = _imageY, let cbcr = _imageCbCr, let d = _depthMap, let c = _confidenceMap else {
                completion?(nil)
                return
            }
            
            let _imageOut = makeTexture(width: y.width, height: y.height, pixelFormat: .bgra8Unorm, usage: [.renderTarget, .shaderRead, .shaderWrite])
            let _depthMapOut = makeTexture(width: d.width, height: d.height, pixelFormat: d.pixelFormat, usage: [.shaderRead, .shaderWrite])
            let _confidenceMapOut = makeTexture(width: c.width, height: c.height, pixelFormat: c.pixelFormat, usage: [.shaderRead, .shaderWrite])
            
            guard let imgOut = _imageOut, let dOut = _depthMapOut, let cOut = _confidenceMapOut else {
                completion?(nil)
                return
            }
            
            let renderPass = MTLRenderPassDescriptor()
            renderPass.colorAttachments[0].texture = imgOut
            renderPass.colorAttachments[0].loadAction = .clear
            renderPass.colorAttachments[0].storeAction = .store
            renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
            
            builder.render(vertex: "vertexPassthrough", fragment: "ycbcrToRGBFragment", descriptor: renderPass) { encoder in
                encoder.setFragmentTexture(y, index: 0)
                encoder.setFragmentTexture(cbcr, index: 1)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
            
            try? builder.blit { context in
                context.copy(source: d, destination: dOut)
                context.copy(source: c, destination: cOut)
            }
            
            builder.onCompleted {
                // frameData logic here
                completion?(nil)
            }
            
            builder.commit()
        }
    }
}

// MARK: - Compute Helpers
extension MetalManager {
    func fillIndices(_ buffer: MetalBuffer<UInt32>, completion: (() -> Void)? = nil) {
        if let builder = makeCommandBuilder() {
            try? builder.compute(name: "fillIndices", count: buffer.count) { context in
                context.add(buffer)
            }
            builder.onCompleted { completion?() }
            builder.commit()
        }
    }
    
    func fillValue(_ buffer: MetalBuffer<UInt32>, vaule: UInt32, completion: (() -> Void)? = nil) {
        if let builder = makeCommandBuilder() {
            try? builder.compute(name: "fillValue", count: buffer.count) { context in
                context.add(buffer)
                context.add(vaule)
            }
            builder.onCompleted { completion?() }
            builder.commit()
        }
    }
    
    func fillZero(_ buffer: MetalBuffer<UInt32>, completion: (() -> Void)? = nil) {
        if let builder = makeCommandBuilder() {
            try? builder.blit { context in
                context.fill(buffer: buffer, offset: 0, size: buffer.count)
            }
            builder.onCompleted { completion?() }
            builder.commit()
        }
    }
    
    func fillSubValue(_ buffer: MetalBuffer<UInt32>, offset: Int, size: Int, vaule: UInt32) {
        if let builder = makeCommandBuilder() {
            try? builder.compute(name: "fillSubValue", count: size) { context in
                context.add(buffer)
                context.add(UInt32(offset))
                context.add(vaule)
            }
            builder.commit()
        }
    }
}
