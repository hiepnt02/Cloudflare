//
//  MetalMesh.swift
//  Quick3D
//
//  Created by HaNST on 6/11/25.
//

import Foundation
import Metal
import SceneKit

class MetalMesh {
    
    var vertices: MetalArray<SIMD3<Float>>
    var indices: MetalArray<UInt32>
    
    let size: Int
    
    var vertexCount: Int {
        get {
            vertices.count
        }
        set (value) {
            vertices.count = value
        }
    }
    
    var indexCount: Int {
        get {
            indices.count
        }
        set (value) {
            indices.count = value
        }
    }
    
    var vertexOffset: Int {
        vertexStride * vertexCount
    }
    
    var vertexStride: Int {
        vertices.stride
    }
    
    var indexOffset: Int {
        indexStride * indexCount
    }
    
    var indexStride: Int {
        indices.stride
    }
    
    var verticesBuffer: MTLBuffer {
        vertices.buffer
    }
    
    var facesBuffer: MTLBuffer {
        indices.buffer
    }
    
    init(vertices: MetalArray<SIMD3<Float>>, size: Int, options: MTLResourceOptions = []) {
        self.size = size
        self.vertices = vertices
        self.indices = MetalManager.shared.makeArrayBuffer(count: size, options: options)!
        MetalManager.shared.fillZero(indices.data)
    }
    
    func append(vertexBuffer: MTLBuffer, vertexCount: Int, faceBuffer: MTLBuffer, faceCount: Int, modelMatrix: simd_float4x4) -> (offset: Int, size: Int, vertexOffset: Int, vertexSize: Int)? {
        
        let vCount = self.vertexCount
        
        let iCount = self.indexCount
        
        let manager = MetalManager.shared
        
        if let builder = manager.makeCommandBuilder() {
            
            let indexCount = 3 * faceCount
            
            self.vertexCount = self.vertexCount + vertexCount
            self.indexCount = self.indexCount + indexCount
            
            try? builder.compute(name: "appendMeshVertices", count: vertexCount) { context in
                context.add(vertexBuffer)
                context.add(UInt32(vCount))
                context.add(self.verticesBuffer)
                context.add(modelMatrix)
            }
            
            try? builder.compute(name: "appendMeshFaces", count: indexCount) { context in
                context.add(faceBuffer)
                context.add(UInt32(iCount))
                context.add(self.facesBuffer)
                context.add(UInt32(vCount))
            }
            
            builder.onCompleted {
//                self.description()
//                print("=====================")
            }
            
            builder.commit()
            
            return (iCount, indexCount, vCount, vertexCount)
        }
        
        return nil
    }
    
    func remove(offset: Int, size: Int, completion: (() -> Void)? = nil) {
        self.indices.remove(offset: offset, size: size, completion: completion)
//        MetalManager.shared.fillSubValue(self.indices, offset: offset, size: size, vaule: 0)
    }
    
    func makeSCNNode() -> SCNNode {
        let vertexSource = SCNGeometrySource(
            buffer: verticesBuffer,
            vertexFormat: .float3,
            semantic: .vertex,
            vertexCount: size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float>>.stride
        )
        
        let element = SCNGeometryElement(buffer: facesBuffer, primitiveType: .triangles, primitiveCount: size / 3, bytesPerIndex: MemoryLayout<UInt32>.size)
        
        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
        
        geometry.firstMaterial = SCNMaterial.mesh
        
        let node = SCNNode(geometry: geometry)
        
        return node
    }
    
    func description() {
        vertices.data.desciption()
        indices.data.desciption()
    }
}

extension MetalManager {
    func makeMesh(vertices: MetalArray<SIMD3<Float>>, size: Int, options: MTLResourceOptions = []) -> MetalMesh? {
        guard isReady else { return nil }
        return MetalMesh(vertices: vertices, size: size, options: options)
    }
}
