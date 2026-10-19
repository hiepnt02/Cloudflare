//
//  MetalMeshes.swift
//  Quick3D
//
//  Created by HaNST on 6/11/25.
//

import Foundation
import Metal
import SceneKit
import ARKit

struct MetalMeshIndex {
    let dataIndex: Int
    let offset: Int
    let size: Int
    let vertexOffset: Int
    let vertexSize: Int
}

class MetalMeshes {
    
    var vertices: [MetalArray<SIMD3<Float>>] = []
    
    var faces: [MetalMesh] = []
    
    var identifiers: [UUID: MetalMeshIndex] = [:]
    
    let maxSize: Int
    
    init(_ size: Int) {
        self.maxSize = size
    }
    
    func canAppendVertices(_ count: Int) -> Bool {
        if let vertices = self.vertices.last {
            return vertices.size - vertices.count >= count
        }
        return false
    }
    
    func canAppendFaces(_ count: Int) -> Bool {
        if let faces = self.faces.last {
            return faces.size - faces.indexCount >= 3 * count
        }
        return false
    }
    
    func append(_ anchor: ARMeshAnchor) {
        let vertexCount = anchor.geometry.vertices.count
        let faceCount = anchor.geometry.faces.count
        
        var vertices = self.vertices.last
        var faces = self.faces.last
        
        if vertices == nil || !canAppendVertices(vertexCount) {
            vertices = MetalManager.shared.makeArrayBuffer(count: maxSize, options: .storageModeShared)
            faces = nil
            self.vertices.append(vertices!)
        }
        
        if faces == nil || !canAppendFaces(faceCount) {
            faces = MetalManager.shared.makeMesh(vertices: vertices!, size: maxSize, options: .storageModeShared)
            self.faces.append(faces!)
        }
        
        if let r = faces?.append(vertexBuffer: anchor.geometry.vertices.buffer,
                                 vertexCount: anchor.geometry.vertices.count,
                                 faceBuffer: anchor.geometry.faces.buffer,
                                 faceCount: anchor.geometry.faces.count,
                                 modelMatrix: anchor.transform) {
            let index = MetalMeshIndex(dataIndex: self.faces.count - 1, offset: r.offset, size: r.size, vertexOffset: r.vertexOffset, vertexSize: r.vertexSize)
            identifiers[anchor.identifier] = index
        }
        
        print("MetalMeshes vertices count: \(self.vertices.count): \(vertices?.count) faces count: \(self.faces.count) \(faces?.indexCount)")
//        print("ARMeshAnchor count: \(mesh?.positionCount) \(mesh?.indexCount)")
        
    }
    
    func remove(_ identifier: UUID, completion: (() -> Void)? = nil) {
        if let index = identifiers[identifier] {
            let faces = self.faces[index.dataIndex]
            let vextices = faces.vertices
            faces.remove(offset: index.offset, size: index.size) {
                vextices.remove(offset: index.vertexOffset, size: index.vertexSize, completion: completion)
            }
            identifiers[identifier] = nil
        } else {
            completion?()
        }
    }
    
    func update(_ anchor: ARMeshAnchor) {
//        if let index = identifiers[anchor.identifier] {
//            let vertexCount = anchor.geometry.vertices.count
//            let indexCount = anchor.geometry.faces.count * 3
//            
//            if indexCount <= index.size {
//                if vertexCount <= index.vertexSize {
//                    print("Update vertices & faces <=")
//                } else {
//                    print("Update faces <=")
//                }
//                
//            } else if vertexCount <= index.vertexSize {
//                print("Update vertices <=")
//            }
//            
//        }
        remove(anchor.identifier) {
            self.append(anchor)
        }
    }
}

