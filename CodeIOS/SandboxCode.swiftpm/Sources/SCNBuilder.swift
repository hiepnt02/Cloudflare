//
//  SCNBuilder.swift
//  Quick3DDemo
//
//  Tầng ⑥ (geometry) — biến MTLBuffer thành SCNGeometry mà KHÔNG copy dữ liệu.
//  Tương đương: new Points(new BufferGeometry().setAttribute(...), shaderMaterial)
//  Trong project thật: Camera/Utils/SCNBuilder.swift
//

import SceneKit

enum SCNBuilder {

    static func createNode(_ source: MetalPointCloud, program: PointProgram) -> SCNNode {
        let stride = MetalPointCloud.stride

        // SCNGeometrySource trỏ thẳng vào MTLBuffer → semantic .vertex / .color
        // khớp với [[attribute(SCNVertexSemanticPosition)]] / Color trong shader.
        let positionSource = SCNGeometrySource(
            buffer: source.positions,
            vertexFormat: .float3,
            semantic: .vertex,
            vertexCount: source.count,
            dataOffset: 0,
            dataStride: stride
        )
        let colorSource = SCNGeometrySource(
            buffer: source.colors,
            vertexFormat: .float3,
            semantic: .color,
            vertexCount: source.count,
            dataOffset: 0,
            dataStride: stride
        )

        // primitiveType .point → shader nhận [[point_coord]] và dùng [[point_size]]
        let element = SCNGeometryElement(
            buffer: source.indices,
            primitiveType: .point,
            primitiveCount: source.count,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )
        // Bắt buộc set, nếu không SceneKit vẽ điểm 1px bất kể shader
        element.pointSize = CGFloat(program.pointSize)
        element.minimumPointScreenSpaceRadius = 1
        element.maximumPointScreenSpaceRadius = 64

        let geometry = SCNGeometry(sources: [positionSource, colorSource], elements: [element])
        geometry.program = program

        // Shader xuất màu chưa nhân alpha → blend alpha chuẩn
        let material = SCNMaterial()
        material.blendMode = .alpha
        material.readsFromDepthBuffer = true
        material.writesToDepthBuffer = true
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        node.renderingOrder = 10
        // SceneKit cull theo boundingBox; với buffer tự cấp phải tự khai
        node.boundingBox = (
            SCNVector3(source.min.x, source.min.y, source.min.z),
            SCNVector3(source.max.x, source.max.y, source.max.z)
        )
        return node
    }
}
