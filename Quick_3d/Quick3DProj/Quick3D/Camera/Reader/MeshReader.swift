//
//  MeshReader.swift
//  Quick3D
//
//  Created by HaNST on 17/10/25.
//

import Foundation
import ARKit

class MeshReader {
    
    private let lock = NSLock()
    
    private var anchors: [UUID: ARMeshAnchor] = [:]
    
    var vertices: [Vertex] {
        var vertices: [SIMD3<Float>] = []
        for anchor in anchors.values {
            anchor.geometry.convertVertexLocalToWorld(anchor.transform)
            vertices += anchor.faces
        }
        return vertices.map { Vertex( $0 ) }
    }
    
    func append(_ mesh: ARMeshAnchor) {
        lock.lock()
        defer {
            lock.unlock()
        }
        anchors[mesh.identifier] = mesh
    }
    
    func remove(_ mesh: ARMeshAnchor) {
        lock.lock()
        defer {
            lock.unlock()
        }
        anchors.removeValue(forKey: mesh.identifier)
    }
    
    func removeAll() {
        lock.lock()
        defer {
            lock.unlock()
        }
        anchors.removeAll()
    }
    
    func getVertices(_ mesh: ARMeshAnchor) -> [Vertex] {
        var vertices: [Vertex] = []
        let modelMatrix = mesh.transform
        
        for i in 0..<mesh.geometry.faces.count {
            let faceVertexIndices = mesh.geometry.vertexIndicesOf(faceWithIndex: i)
            for j in 0..<faceVertexIndices.count {
                let vertex = mesh.geometry.vertex(at: UInt32(j))
                vertices.append(Vertex(convert(vertex, modelMatrix: modelMatrix)))
            }
        }
        return vertices
    }
    
    func convert(_ vertex: SIMD3<Float>, modelMatrix: simd_float4x4) -> SIMD3<Float> {
        var vertexLocalTransform = matrix_identity_float4x4
        vertexLocalTransform.columns.3 = SIMD4<Float>(x: vertex.x, y: vertex.y, z: vertex.z, w: 1)
        let vertexWorldPosition = (modelMatrix * vertexLocalTransform).columns.3
        return make_simd_float3(vertexWorldPosition)
    }
    
    func readBuffer(size: Int, handler: ([Vertex]) -> Void, completion: (() -> Void)? = nil) {
        lock.lock()
        defer {
            lock.unlock()
        }
        var isWrite: Bool = false
        var vertices: [Vertex] = []
        for anchor in anchors.values {
            isWrite = true
            anchor.geometry.convertVertexLocalToWorld(anchor.transform)
            vertices += anchor.faces.map { Vertex( $0 ) }
            if vertices.count >= size {
                handler(vertices)
                vertices = []
            }
        }
        
        if vertices.count > 0 {
            handler(vertices)
        }
        
        if isWrite {
            completion?()
        }
    }
}
