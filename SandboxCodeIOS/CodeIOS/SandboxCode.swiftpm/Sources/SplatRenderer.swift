//
//  SplatRenderer.swift
//  Quick3DDemo
//
//  Vẽ Gaussian splatting bằng Metal thuần, giống engine web (ply-to-gsx-viewer.html / engine/renderer.ts):
//  mỗi splat = 1 quad instanced (4 đỉnh triangle strip), cỡ 2√2σ, bù antialias, không depth test,
//  blend ONE / ONE_MINUS_SRC_ALPHA. SceneKit chỉ cho vị trí node + camera; việc vẽ do ta làm trong
//  SCNNodeRendererDelegate.renderNode (SceneKit gọi thay cho việc vẽ geometry của node).
//
//  Point sprite (SplatProgram cũ) bị giới hạn point size (~511 px trên iOS) và không làm được quad
//  xoay theo trục ellipse → hình mờ/bệt hơn web. File này thay thế đường đó.
//

import SceneKit
import Metal
import simd

struct GSplatUniforms {
    var modelView = matrix_identity_float4x4
    var projection = matrix_identity_float4x4
    var viewport = SIMD2<Float>(1, 1)
    var focal: Float = 1
    var splatScale: Float = 1
    var opacity: Float = 1
    /// 2.2 khi attachment là sRGB (SceneKit iOS mặc định): màu web là sRGB, phải giải về tuyến tính trước khi ghi,
    /// nếu không phần cứng mã hoá sRGB lần nữa → nhạt/bệt. 1 = attachment thường (như canvas WebGL).
    var gamma: Float = 1
    var pad = SIMD2<Float>(repeating: 0)
}

final class SplatRenderer: NSObject, SCNNodeRendererDelegate {

    let cloud: SplatCloud
    /// Nhân σ (slider Point size / 14 = 1 → đúng file).
    var splatScale: Float = 1
    var opacity: Float = 1

    private let device: MTLDevice
    private var pipeline: MTLRenderPipelineState?
    private var pipelineKey = ""
    private var depthState: MTLDepthStencilState?
    private var failed = false

    init(cloud: SplatCloud, device: MTLDevice) {
        self.cloud = cloud
        self.device = device
        super.init()
    }

    /// Pipeline phải khớp pixel format / sample count của pass SceneKit đang vẽ → tạo lười theo renderer.
    private func pipeline(for renderer: SCNRenderer) -> MTLRenderPipelineState? {
        let samples = max(1, renderer.currentRenderPassDescriptor.colorAttachments[0].texture?.sampleCount ?? 1)
        let key = "\(renderer.colorPixelFormat.rawValue)/\(renderer.depthPixelFormat.rawValue)/\(renderer.stencilPixelFormat.rawValue)/\(samples)"
        if key == pipelineKey, let pipeline { return pipeline }
        if failed { return nil }
        guard let library = device.makeDefaultLibrary(),
              let vs = library.makeFunction(name: "gsplatVertex"),
              let fs = library.makeFunction(name: "gsplatFragment") else {
            print("[splat] không tìm thấy gsplatVertex/gsplatFragment trong default.metallib"); failed = true; return nil
        }
        let d = MTLRenderPipelineDescriptor()
        d.vertexFunction = vs
        d.fragmentFunction = fs
        d.rasterSampleCount = samples
        d.colorAttachments[0].pixelFormat = renderer.colorPixelFormat
        d.depthAttachmentPixelFormat = renderer.depthPixelFormat
        d.stencilAttachmentPixelFormat = renderer.stencilPixelFormat
        // = gl.blendFunc(ONE, ONE_MINUS_SRC_ALPHA), shader xuất premultiplied
        let c = d.colorAttachments[0]!
        c.isBlendingEnabled = true
        c.sourceRGBBlendFactor = .one
        c.sourceAlphaBlendFactor = .one
        c.destinationRGBBlendFactor = .oneMinusSourceAlpha
        c.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        do {
            pipeline = try device.makeRenderPipelineState(descriptor: d)
            pipelineKey = key
        } catch {
            print("[splat] pipeline lỗi: \(error)"); failed = true; return nil
        }
        // = gl.disable(DEPTH_TEST): không test, không ghi
        let ds = MTLDepthStencilDescriptor()
        ds.depthCompareFunction = .always
        ds.isDepthWriteEnabled = false
        depthState = device.makeDepthStencilState(descriptor: ds)
        return pipeline
    }

    // SceneKit gọi mỗi frame, trên thread render, thay cho việc vẽ geometry của node.
    func renderNode(_ node: SCNNode, renderer: SCNRenderer, arguments: [String: Any]) {
        guard cloud.count > 0,
              let encoder = renderer.currentRenderCommandEncoder,
              let pipeline = pipeline(for: renderer),
              let depthState,
              let mv = (arguments[SCNModelViewTransform] as? NSValue)?.scnMatrix4Value,
              let pr = (arguments[SCNProjectionTransform] as? NSValue)?.scnMatrix4Value
        else { return }

        // Sắp xếp xa → gần theo camera trong hệ local của node (như sorter.needsResort + sort của web)
        if let pov = renderer.pointOfView {
            let camLocal = node.simdConvertPosition(pov.simdWorldPosition, from: nil)
            let dirLocal = simd_normalize(node.simdConvertVector(-pov.simdWorldTransform.columns.2.xyz, from: nil))
            cloud.requestSortIfNeeded(cameraLocal: camLocal, directionLocal: dirLocal)
        }

        let vp = renderer.currentViewport
        var u = GSplatUniforms()
        u.modelView = simd_float4x4(mv)
        u.projection = simd_float4x4(pr)
        u.viewport = SIMD2(Float(vp.width), Float(vp.height))
        u.focal = Float(vp.height) * u.projection[1][1] / 2          // = h * proj[5] / 2 của web
        u.splatScale = splatScale
        u.opacity = opacity
        switch renderer.colorPixelFormat {
        case .bgra8Unorm_srgb, .rgba8Unorm_srgb, .bgr10_xr_srgb, .bgra10_xr_srgb: u.gamma = 2.2
        default: u.gamma = 1
        }

        encoder.pushDebugGroup("gsplat")
        encoder.setRenderPipelineState(pipeline)
        encoder.setDepthStencilState(depthState)
        encoder.setCullMode(.none)
        encoder.setVertexBuffer(cloud.positions, offset: 0, index: 0)
        encoder.setVertexBuffer(cloud.colors, offset: 0, index: 1)
        encoder.setVertexBuffer(cloud.cov0, offset: 0, index: 2)
        encoder.setVertexBuffer(cloud.cov1, offset: 0, index: 3)
        encoder.setVertexBuffer(cloud.indices, offset: 0, index: 4)
        encoder.setVertexBytes(&u, length: MemoryLayout<GSplatUniforms>.stride, index: 5)
        // = gl.drawArraysInstanced(TRIANGLES, 0, 6, total) — ở đây strip 4 đỉnh / instance
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: cloud.count)
        encoder.popDebugGroup()
    }
}
