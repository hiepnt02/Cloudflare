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

    /// Gaussian splatting: cùng kiểu .point nhưng thêm 2 source covariance (texcoord0/1) và màu float4
    /// (alpha = opacity). Không ghi depth vì trộn alpha; thứ tự vẽ do SplatCloud sắp lại index buffer.
    static func createSplatNode(_ source: SplatCloud, program: SplatProgram) -> SCNNode {
        let positionSource = SCNGeometrySource(
            buffer: source.positions, vertexFormat: .float3, semantic: .vertex,
            vertexCount: source.count, dataOffset: 0, dataStride: SplatCloud.stride3)
        let colorSource = SCNGeometrySource(
            buffer: source.colors, vertexFormat: .float4, semantic: .color,
            vertexCount: source.count, dataOffset: 0, dataStride: SplatCloud.stride4)
        let cov0Source = SCNGeometrySource(
            buffer: source.cov0, vertexFormat: .float3, semantic: .texcoord,
            vertexCount: source.count, dataOffset: 0, dataStride: SplatCloud.stride3)
        let cov1Source = SCNGeometrySource(
            buffer: source.cov1, vertexFormat: .float3, semantic: .texcoord,
            vertexCount: source.count, dataOffset: 0, dataStride: SplatCloud.stride3)

        let element = SCNGeometryElement(
            buffer: source.indices, primitiveType: .point,
            primitiveCount: source.count, bytesPerIndex: MemoryLayout<UInt32>.size)
        element.pointSize = 1                               // shader quyết định cỡ thật
        element.minimumPointScreenSpaceRadius = 0.5
        element.maximumPointScreenSpaceRadius = 512         // = point_size tối đa 1024 px trong shader

        let geometry = SCNGeometry(sources: [positionSource, colorSource, cov0Source, cov1Source], elements: [element])
        geometry.program = program

        let material = SCNMaterial()
        material.blendMode = .alpha
        material.readsFromDepthBuffer = true                // bị model/point cloud che
        material.writesToDepthBuffer = false                // splat mờ không che nhau qua depth
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        node.renderingOrder = 20                            // vẽ sau model để blend lên trên
        node.boundingBox = (
            SCNVector3(source.min.x, source.min.y, source.min.z),
            SCNVector3(source.max.x, source.max.y, source.max.z)
        )
        return node
    }
}
