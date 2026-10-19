//
//  MetalPointCloud.swift
//  Quick3D
//
//  Created by HaNST on 6/11/25.
//

import Foundation
import Metal
import SceneKit

class MetalPointCloud {
    var info: MetalBuffer<ArrayInfo>
    var positions: MetalBuffer<SIMD3<Float>>
    var colors: MetalBuffer<SIMD3<Float>>
    let indices: MetalBuffer<UInt32>
    let program: SCNProgram
    
    var size: Int { positions.count }
    
    var count: Int {
        get { Int(info[0].index) }
        set { info[0].index = UInt32(newValue) }
    }
    
    var pointSize: Int = 4
    
    // MARK: - Khôi phục đầy đủ các Member cũ
    var positionOffset: Int { positionStride * count }
    var colorOffset: Int { colorStride * count }
    var indexOffset: Int { positionStride * count }
    var positionStride: Int { positions.stride }
    var colorStride: Int { colors.stride }
    var indexStride: Int { positions.stride }
    
    var positionsBuffer: MTLBuffer { positions.buffer }
    var colorsBuffer: MTLBuffer { colors.buffer }
    var indicesBuffer: MTLBuffer { indices.buffer }
    
    var writeCount: Int = 0
    
    init(manager: MetalManager, size: Int, options: MTLResourceOptions = []) throws {
        
        guard let info = manager.makeBuffer(value: ArrayInfo(index: 0)),
              let positions: MetalBuffer<SIMD3<Float>> = manager.makeBuffer(count: size, options: options),
              let colors: MetalBuffer<SIMD3<Float>> = manager.makeBuffer(count: size, options: options),
              let indices: MetalBuffer<UInt32> = manager.makeBuffer(count: size, options: .storageModePrivate) else {
            throw NSError(domain: "MetalPointCloud", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer."])
        }
        
        self.info = info
        self.positions = positions
        self.colors = colors
        self.indices = indices
        
        self.program = SCNProgram()
        
        program.vertexFunctionName = "pointVertex"
        program.fragmentFunctionName = "pointFragment"
        
        program.handleBinding(ofBufferNamed: "pointCount", frequency: .perFrame) { [weak self] b, _, _, _ in
            var c = UInt32(self?.count ?? 0)
            b.writeBytes(&c, count: 4)
        }
        
        program.handleBinding(ofBufferNamed: "pointSize", frequency: .perFrame) { [weak self] b, _, _, _ in
            var s = Float(self?.pointSize ?? 0)
            b.writeBytes(&s, count: 4)
        }
        
        manager.fillIndices(self.indices)
    }
    
    func canAppend(_ source: MetalPointCloud) -> Bool { (self.size - self.count) > source.count }
    
    func canAppend(_ count: Int) -> Bool { (self.size - self.count) > count }
    
    func assign(positions: [SIMD3<Float>], colors: [SIMD3<Float>]) {
        self.positions.assign(with: positions)
        self.colors.assign(with: colors)
        self.count = positions.count
    }
    
    func makeSCNNode() -> SCNNode {
        let stride = MemoryLayout<SIMD3<Float>>.stride
        let pSrc = SCNGeometrySource(buffer: positions.buffer, vertexFormat: .float3, semantic: .vertex, vertexCount: size, dataOffset: 0, dataStride: stride)
        let cSrc = SCNGeometrySource(buffer: colors.buffer, vertexFormat: .float3, semantic: .color, vertexCount: size, dataOffset: 0, dataStride: stride)
        let element = SCNGeometryElement(buffer: indices.buffer, primitiveType: .point, primitiveCount: size, bytesPerIndex: 4)
        
        element.pointSize = SCNGeometry.pointSize
        element.minimumPointScreenSpaceRadius = SCNGeometry.pointSize
        element.maximumPointScreenSpaceRadius = SCNGeometry.pointSize
        
        let geo = SCNGeometry(sources: [pSrc, cSrc], elements: [element])
        geo.program = program
        let node = SCNNode(geometry: geo)
        node.renderingOrder = 10
        return node
    }
    
    func write(writer: GLTFWriter, group: DispatchGroup, force: Bool = false) {
        let step = writer.buffer
        let currentCount = self.count
        if force || currentCount >= writeCount + step {
            let start = writeCount
            writeCount = force ? currentCount : (currentCount / step) * step
            var i = start
            while i < writeCount {
                let offset = i
                let len = min(step, currentCount - offset)
                group.enter()
                DispatchQueue.global(qos: .background).async { [weak self] in
                    guard let self = self else {
                        group.leave()
                        return
                    }
                    
                    let p = self.positions.range(at: offset, length: len, size: currentCount)
                    let c = self.colors.range(at: offset, length: len, size: currentCount)
                    writer.append(positions: p, colors: c, convertZUp: true)
                    group.leave()
                }
                i += step
            }
        }
    }
}

extension MetalManager {
    
    private static let sizes: [Int] = [1_000_000, 500_000, 100_000, 50_000]
    
    func makePointCloud(size: Int, options: MTLResourceOptions = []) -> MetalPointCloud? {
        return try? MetalPointCloud(manager: self, size: size, options: options)
    }
    
    func makePointCloud(options: MTLResourceOptions = []) -> MetalPointCloud? {
        var pointCloud: MetalPointCloud?
        
        for size in Self.sizes {
            pointCloud = try? MetalPointCloud(manager: self, size: size, options: options)
            if pointCloud != nil {
                return pointCloud
            }
        }
        
        return nil
    }
    
    
    func copy(source: MetalPointCloud, destination: MetalPointCloud, complition: ((MetalPointCloud, Int) -> Void)? = nil) {
        guard destination.canAppend(source) else { return }
        
        if let builder = makeCommandBuilder() {
            try? builder.blit { context in
                context.copy(from: source.positionsBuffer, sourceOffset: 0, to: destination.positionsBuffer, destinationOffset: destination.positionOffset, size: source.positionOffset)
                context.copy(from: source.colorsBuffer, sourceOffset: 0, to: destination.colorsBuffer, destinationOffset: destination.colorOffset, size: source.colorOffset)
            }
            builder.onCompleted {
                destination.count += source.count
                complition?(destination, destination.count)
            }
            builder.commit()
        }
    }
}
