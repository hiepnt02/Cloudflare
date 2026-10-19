import ARKit
import MetalKit
import SceneKit
import Combine

extension  SCNGeometry {
    convenience init(from meshGeometry: ARMeshGeometry) {
        // Vertices source
        let vertices = meshGeometry.vertices
        let verticesSource = SCNGeometrySource(
            buffer: vertices.buffer,
            vertexFormat: vertices.format,
            semantic: .vertex,
            vertexCount: vertices.count,
            dataOffset: vertices.offset,
            dataStride: vertices.stride
        )

        // Indices element
        let faces = meshGeometry.faces
        let facesElement = SCNGeometryElement(
            buffer: faces.buffer,
            primitiveType: .triangles,
            primitiveCount: faces.count,
            bytesPerIndex: faces.bytesPerIndex
        )

        self.init(
            sources: [verticesSource],
            elements: [facesElement]
        )
    }
}


extension ARMeshAnchor {
    var vertices: [SIMD3<Float>] {
        var vertices: [SIMD3<Float>] = []
        for i in 0..<geometry.vertices.count {
            vertices.append(geometry.vertex(at: UInt32(i)))
        }
        return vertices
    }
    
    var faces: [SIMD3<Float>] {
        var vertices: [SIMD3<Float>] = []
        for i in 0..<geometry.faces.count {
            vertices += geometry.verticesOf(faceWithIndex: i)
        }
        return vertices
    }
}

extension ARMeshGeometry {
    
    func vertex(at index: UInt32) -> SIMD3<Float> {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * Int(index)))
        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return vertex
    }
    
    func convertVertexLocalToWorld(_ modelMatrix: simd_float4x4) {
        let verticesPointer = vertices.buffer.contents()

        for vertexIndex in 0..<vertices.count {
            let vertex = self.vertex(at: UInt32(vertexIndex))
            
            let vertexLocalTransform = simd_float4(x: vertex.x, y: vertex.y, z: vertex.z, w: 1)
            let vertexWorldPosition = modelMatrix * vertexLocalTransform
            
            let vertexOffset = vertices.offset + vertices.stride * vertexIndex
            let componentStride = vertices.stride / 3
            verticesPointer.storeBytes(of: vertexWorldPosition.x, toByteOffset: vertexOffset, as: Float.self)
            verticesPointer.storeBytes(of: vertexWorldPosition.y, toByteOffset: vertexOffset + componentStride, as: Float.self)
            verticesPointer.storeBytes(of: vertexWorldPosition.z, toByteOffset: vertexOffset + (2 * componentStride), as: Float.self)
        }
    }
    
    func toMDLMesh(device: MTLDevice, camera: ARCamera, modelMatrix: simd_float4x4) -> MDLMesh {
        
        convertVertexLocalToWorld(modelMatrix)
        
        let allocator = MTKMeshBufferAllocator(device: device);

        let data = Data.init(bytes: vertices.buffer.contents(), count: vertices.stride * vertices.count);
        let vertexBuffer = allocator.newBuffer(with: data, type: .vertex);

        let indexData = Data.init(bytes: faces.buffer.contents(), count: faces.bytesPerIndex * faces.count * faces.indexCountPerPrimitive);
        let indexBuffer = allocator.newBuffer(with: indexData, type: .index);

        let submesh = MDLSubmesh(indexBuffer: indexBuffer,
                                 indexCount: faces.count * faces.indexCountPerPrimitive,
                                 indexType: .uInt32,
                                 geometryType: .triangles,
                                 material: nil);

        let vertexDescriptor = MDLVertexDescriptor();
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: 0,
                                                            bufferIndex: 0);
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: vertices.stride);

        let mesh = MDLMesh(vertexBuffer: vertexBuffer,
                       vertexCount: vertices.count,
                       descriptor: vertexDescriptor,
                       submeshes: [submesh])
        
        return mesh
    }
    
    func vertexIndicesOf(faceWithIndex faceIndex: Int) -> [UInt32] {
        assert(faces.bytesPerIndex == MemoryLayout<UInt32>.size, "Expected one UInt32 (four bytes) per vertex index")
        let vertexCountPerFace = faces.indexCountPerPrimitive
        let vertexIndicesPointer = faces.buffer.contents()
        var vertexIndices = [UInt32]()
        vertexIndices.reserveCapacity(vertexCountPerFace)
        for vertexOffset in 0..<vertexCountPerFace {
            let vertexIndexPointer = vertexIndicesPointer.advanced(by: (faceIndex * vertexCountPerFace + vertexOffset) * MemoryLayout<UInt32>.size)
            vertexIndices.append(vertexIndexPointer.assumingMemoryBound(to: UInt32.self).pointee)
        }
        return vertexIndices
    }
    
    func verticesOf(faceWithIndex index: Int) -> [SIMD3<Float>] {
        let vertexIndices = vertexIndicesOf(faceWithIndex: index)
        let vertices = vertexIndices.map { vertex(at: $0) }
        return vertices
    }
    
}


extension matrix_float4x4 {
    // Function to convert rad to deg
    func radiansToDegress(radians: Float32) -> Float32 {
        return radians * 180 / (Float32.pi)
    }
    var translation: SCNVector3 {
       get {
           return SCNVector3Make(columns.3.x, columns.3.y, columns.3.z)
       }
    }
    // Retrieve euler angles from a quaternion matrix
    var eulerAngles: SCNVector3 {
        get {
            // Get quaternions
            let qw = sqrt(1 + self.columns.0.x + self.columns.1.y + self.columns.2.z) / 2.0
            let qx = (self.columns.2.y - self.columns.1.z) / (qw * 4.0)
            let qy = (self.columns.0.z - self.columns.2.x) / (qw * 4.0)
            let qz = (self.columns.1.x - self.columns.0.y) / (qw * 4.0)

            // Deduce euler angles
            /// yaw (z-axis rotation)
            let siny = +2.0 * (qw * qz + qx * qy)
            let cosy = +1.0 - 2.0 * (qy * qy + qz * qz)
            let yaw = radiansToDegress(radians:atan2(siny, cosy))
            // pitch (y-axis rotation)
            let sinp = +2.0 * (qw * qy - qz * qx)
            var pitch: Float
            if abs(sinp) >= 1 {
                pitch = radiansToDegress(radians:copysign(Float.pi / 2, sinp))
            } else {
                pitch = radiansToDegress(radians:asin(sinp))
            }
            /// roll (x-axis rotation)
            let sinr = +2.0 * (qw * qx + qy * qz)
            let cosr = +1.0 - 2.0 * (qx * qx + qy * qy)
            let roll = radiansToDegress(radians:atan2(sinr, cosr))
            
            /// return array containing ypr values
            return SCNVector3(yaw, pitch, roll)
            }
    }
}

public typealias SinglePublisher<Element> = AnyPublisher<Element, Never>
public typealias CurrentPublisher<Element> = CurrentValueSubject<Element, Never>
public typealias Passthrough<Element> = PassthroughSubject<Element, Never>

extension SCNGeometry {
    
    static let pointSize : CGFloat = 4
    
    static func build(points: [SIMD3<Float>], colors: [SIMD3<Float>]) -> SCNGeometry {
        
        let pointSource = SCNGeometrySource(
            data: Data(bytes: points, count: points.count * MemoryLayout<SIMD3<Float>>.size),
            semantic: .vertex,
            vectorCount: points.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float>>.size
        )
        
        let colorSource = SCNGeometrySource(
            data: Data(bytes: colors, count: colors.count * MemoryLayout<SIMD3<Float>>.size),
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float>>.size
        )
        
        return build(sources: [pointSource, colorSource], size: points.count)
    }
    
    static func build(sources: [SCNGeometrySource], size: Int) -> SCNGeometry {
        var indices = Array(0..<size).map { Int32($0) }
        let indexData = Data(bytes: &indices, count: indices.count * MemoryLayout<Int32>.size)
        
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .point,
            primitiveCount: indices.count,
            bytesPerIndex: MemoryLayout<Int32>.size
        )
        element.pointSize = pointSize
        element.minimumPointScreenSpaceRadius = pointSize
        element.maximumPointScreenSpaceRadius = pointSize
        
        let geometry = SCNGeometry(sources: sources, elements: [element])
        
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.readsFromDepthBuffer = false
        material.writesToDepthBuffer = false
        material.isDoubleSided = true
        
        geometry.firstMaterial = material
        
        return geometry
    }
    
    static func build(points: MetalArray<SIMD3<Float>>, colors: MetalArray<SIMD3<Float>>) -> SCNGeometry {
        
        let pointSource = SCNGeometrySource(
            buffer: points.buffer,
            vertexFormat: .float3,
            semantic: .vertex,
            vertexCount: points.count,
            dataOffset: 0,
            dataStride: points.stride
        )
        
        let colorSource = SCNGeometrySource(
            buffer: colors.buffer,
            vertexFormat: .float3,
            semantic: .color,
            vertexCount: colors.count,
            dataOffset: 0,
            dataStride: colors.stride
        )
        
        let element = SCNGeometryElement(
            data: nil,
            primitiveType: .point,
            primitiveCount: colors.count,
            bytesPerIndex: 0
        )
        
        element.pointSize = SCNGeometry.pointSize
        element.minimumPointScreenSpaceRadius = SCNGeometry.pointSize
        element.maximumPointScreenSpaceRadius = SCNGeometry.pointSize
        
        let geometry = SCNGeometry(sources: [pointSource, colorSource], elements: [element])
        
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.readsFromDepthBuffer = true
        material.writesToDepthBuffer = true
        material.isDoubleSided = true
        
        geometry.firstMaterial = material
        
        return geometry
    }
    
    static func build(_ buffer: MetalPointCloud) -> SCNGeometry {
        
        let pointSource = SCNGeometrySource(
            buffer: buffer.positionsBuffer,
            vertexFormat: .float3,
            semantic: .vertex,
            vertexCount: buffer.count,
            dataOffset: 0,
            dataStride: buffer.positionStride
        )
        
        let colorSource = SCNGeometrySource(
            buffer: buffer.colorsBuffer,
            vertexFormat: .float3,
            semantic: .color,
            vertexCount: buffer.count,
            dataOffset: 0,
            dataStride: buffer.colorStride
        )
        
        let element = SCNGeometryElement(
            buffer: buffer.indicesBuffer,
            primitiveType: .point,
            primitiveCount: buffer.count,
            bytesPerIndex: buffer.indexStride
        )
        
        element.pointSize = SCNGeometry.pointSize
        element.minimumPointScreenSpaceRadius = SCNGeometry.pointSize
        element.maximumPointScreenSpaceRadius = SCNGeometry.pointSize
        
        let geometry = SCNGeometry(sources: [pointSource, colorSource], elements: [element])
        
        geometry.firstMaterial = SCNMaterial.pointClouds
        
        return geometry
    }
    
    static func build(points: MetalBuffer<SIMD3<Float>>, colors: MetalBuffer<SIMD3<Float>>) -> SCNGeometry {
        
        let pointSource = SCNGeometrySource(
            buffer: points.buffer,
            vertexFormat: .float3,
            semantic: .vertex,
            vertexCount: points.count,
            dataOffset: 0,
            dataStride: points.stride
        )
        
        let colorSource = SCNGeometrySource(
            buffer: colors.buffer,
            vertexFormat: .float3,
            semantic: .color,
            vertexCount: colors.count,
            dataOffset: 0,
            dataStride: colors.stride
        )
        
        let element = SCNGeometryElement(
            data: nil,
            primitiveType: .point,
            primitiveCount: colors.count,
            bytesPerIndex: 0
        )
        
        element.pointSize = SCNGeometry.pointSize
        element.minimumPointScreenSpaceRadius = SCNGeometry.pointSize
        element.maximumPointScreenSpaceRadius = SCNGeometry.pointSize
        
        let geometry = SCNGeometry(sources: [pointSource, colorSource], elements: [element])
        
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.readsFromDepthBuffer = true
        material.writesToDepthBuffer = true
        material.isDoubleSided = true
        
        geometry.firstMaterial = material
        
        return geometry
    }
    
    static func build(sources: [SCNGeometrySource], size: Int, pointSize: CGFloat = pointSize, color: UIColor? = nil) -> SCNGeometry {
        var indices = Array(0..<size).map { Int32($0) }
        let indexData = Data(bytes: &indices, count: indices.count * MemoryLayout<Int32>.size)
        
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .point,
            primitiveCount: indices.count,
            bytesPerIndex: MemoryLayout<Int32>.size
        )
        element.pointSize = pointSize
        element.minimumPointScreenSpaceRadius = pointSize
        element.maximumPointScreenSpaceRadius = pointSize
        
        let geometry = SCNGeometry(sources: sources, elements: [element])
        
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.readsFromDepthBuffer = false
        material.writesToDepthBuffer = false
        material.isDoubleSided = true
        if let color = color {
            material.diffuse.contents = color
        }
        
        geometry.firstMaterial = material
        
        return geometry
    }
}

extension SCNNode {
    static func build(points: [SIMD3<Float>], colors: [SIMD3<Float>]) -> SCNNode {
        return SCNNode(geometry: SCNGeometry.build(points: points, colors: colors))
    }
}

extension SCNMaterial {
    static let pointClouds: SCNMaterial = {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.readsFromDepthBuffer = true
        material.writesToDepthBuffer = true
        material.isDoubleSided = true
        return material
    }()
    
    static let mesh: SCNMaterial = {
        let material = SCNMaterial()
        material.fillMode = .lines
        material.isDoubleSided = false
        material.cullMode = .back
        material.diffuse.contents = UIColor.white.withAlphaComponent(0.7)
        material.lightingModel = .constant
        return material
    }()
}
