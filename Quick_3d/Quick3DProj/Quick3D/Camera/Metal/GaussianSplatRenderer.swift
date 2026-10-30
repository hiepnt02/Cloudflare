//
//  GaussianSplatRenderer.swift
//  Quick3D
//

import Metal
import SceneKit
import simd

/// Layout shared with `GsxUniforms` in GaussianSplat.metal.
struct GsxUniforms {
    var viewModel = matrix_identity_float4x4
    var proj = matrix_identity_float4x4
    var viewport = SIMD2<Float>(1, 1)
    var focal = SIMD2<Float>(1, 1)
    var srgbTarget: UInt32 = 0
    var limits = SIMD4<Float>(0, 1, 0, 0)
}

/// Gaussian splat layer of the SceneKit AR view: streams the project's .gsx (the file the web
/// viewer shows) and draws it into SceneKit's render pass, where the depth test hides splats
/// behind the point cloud, the IFC model and the occlusion mesh. Each frame a compute pass
/// projects the draw list once per splat; the render pass then only expands quads.
///
/// `node` goes under `arNode` and must stay last in `renderingOrder`: splats blend back to
/// front over what is already drawn and do not write depth. `load`, `unload` and
/// `followPointCloud` run on the main thread, `renderNode` on SceneKit's render thread.
final class GaussianSplatRenderer: NSObject, SCNNodeRendererDelegate, @unchecked Sendable {

    static let renderingOrder = 10_000

    let node = SCNNode()

    /// Splats closer to the camera than this (metres) are not drawn.
    var nearCull: Float = 0.15

    /// Largest on-screen splat radius, as a fraction of the short side of the frame.
    var maxRadius: Float = 0.5

    /// Whether the project last passed to `load` has splats, once the lookup has finished.
    private(set) var hasSplats = Task<Bool, Never> { false }

    private let lock = NSLock()
    private var stream: GsxStream?
    /// Whether `node.position` places the data (see `followPointCloud`).
    private var followsPointCloud = false
    private var georeference: GaussianSplatGeoreference?
    private var georeferenceShift: SIMD3<Double> = .zero
    private var pointCloudShift: SIMD3<Double> = .zero

    // Render-thread state.
    private var pipelines: [String: MTLRenderPipelineState] = [:]
    private var depthStates: [Bool: MTLDepthStencilState] = [:]
    private var projected: MTLBuffer?
    private var projectPipeline: MTLComputePipelineState?
    /// Size of `GsxProjected` in GaussianSplat.metal.
    private static let projectedStride = 48

    override init() {
        super.init()
        node.name = "GaussianSplat"
        node.renderingOrder = Self.renderingOrder
        node.rendererDelegate = self
    }

    // MARK: - Loading

    /// Streams the project's latest converted splat file, if it has one.
    func load(projectId: String) {
        unload()
        hasSplats = Task { [weak self] in
            guard let file = await GsxProject.file(projectId: projectId) else { return false }
            // unload() runs on the main thread too, so this check cannot race it.
            return await MainActor.run { [weak self] in
                guard !Task.isCancelled, let self else { return false }
                self.setGeoreference(file.georeference)
                self.start(url: file.url)
                return true
            }
        }
    }

    func unload() {
        hasSplats.cancel()
        node.simdPosition = .zero
        let old = lock.withLock { () -> GsxStream? in
            let s = stream
            stream = nil
            followsPointCloud = false
            georeference = nil
            georeferenceShift = .zero
            pointCloudShift = .zero
            return s
        }
        old?.stop()
    }

    /// Splats share the point cloud's local frame (the web viewer draws both in one scene with
    /// no transform between them), so they take the point cloud node's position and line up
    /// with it and with the IFC, which is placed relative to the point cloud.
    func followPointCloud(position: SIMD3<Float>, projectOffset: SIMD3<Double>) {
        node.simdPosition = position
        lock.withLock {
            followsPointCloud = true
            // BVHReader centers its node by -center. Adding that position back to
            // SfmProject.offset yields the stable negative LAS origin, like Web getOffset().
            // BVHReader has changed the offset to SceneKit Y-up (x, z, -y); convert it back
            // to project Z-up before composing with projectFromPly.
            let yUpPosition = SIMD3<Double>(Double(position.x), Double(position.y), Double(position.z))
            let yUpShift = projectOffset + yUpPosition
            pointCloudShift = [yUpShift.x, -yUpShift.z, yUpShift.y]
            if georeference != nil {
                georeferenceShift = pointCloudShift
            }
        }
    }

    private func setGeoreference(_ georeference: GaussianSplatGeoreference?) {
        lock.withLock {
            self.georeference = georeference
            if let georeference {
                georeferenceShift = followsPointCloud ? pointCloudShift : georeference.referenceShift
            } else {
                georeferenceShift = .zero
            }
        }
    }

    private func start(url: URL) {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        let stream = GsxStream(url: url, device: device, budget: GsxProject.defaultBudget)
        stream.start()
        let old = lock.withLock { () -> GsxStream? in
            let s = self.stream
            self.stream = stream
            return s
        }
        old?.stop()
        print("[gsplat] streaming \(url.lastPathComponent), budget \(GsxProject.defaultBudget) splats")
    }

    // MARK: - SCNNodeRendererDelegate

    func renderNode(_ node: SCNNode, renderer: SCNRenderer, arguments: [String: Any]) {
        let pass = renderer.currentRenderPassDescriptor
        guard let encoder = renderer.currentRenderCommandEncoder,
              let target = pass.colorAttachments[0].texture,
              let modelView = arguments[SCNModelViewTransform] as? NSValue,
              let projection = arguments[SCNProjectionTransform] as? NSValue,
              let current = lock.withLock({ self.stream.map {
                  (stream: $0, follows: followsPointCloud, georeference: georeference, shift: georeferenceShift)
              } }),
              let model = dataToNode(
                  current.stream,
                  followsPointCloud: current.follows,
                  georeference: current.georeference,
                  shift: current.shift
              ) else { return }
        let stream = current.stream

        let proj = simd_float4x4(projection.scnMatrix4Value)
        let viewModel = simd_float4x4(modelView.scnMatrix4Value) * model
        stream.setProjection(proj)
        stream.updateCamera(viewModel: viewModel)

        guard let state = stream.drawState(),
              let depth = depthState(device: encoder.device, reverseZ: renderer.usesReverseZ) else { return }
        let srgb = Self.isSRGB(target.pixelFormat)
        var u = makeUniforms(viewModel: viewModel, proj: proj, width: target.width, height: target.height, srgb: srgb)
        // Projection on a command buffer committed now, while SceneKit is still encoding its
        // frame, so it runs first on the same queue.
        guard let pso = pipeline(device: encoder.device, pass: pass, target: target),
              let commandBuffer = renderer.commandQueue?.makeCommandBuffer(),
              let projected = encodeProjection(state, uniforms: &u, commandBuffer: commandBuffer) else { return }
        commandBuffer.label = "Gaussian splats"
        commandBuffer.commit()
        encoder.pushDebugGroup("Gaussian splats")
        encoder.setRenderPipelineState(pso)
        encoder.setDepthStencilState(depth)
        encoder.setCullMode(.none)
        drawQuads(state.count, projected: projected, uniforms: &u, encoder: encoder)
        encoder.popDebugGroup()
    }

    private func makeUniforms(viewModel: simd_float4x4, proj: simd_float4x4, width: Int, height: Int,
                              srgb: Bool) -> GsxUniforms {
        var u = GsxUniforms()
        u.viewModel = viewModel
        u.proj = proj
        u.viewport = SIMD2(Float(width), Float(height))
        u.focal = SIMD2(proj.columns.0.x * u.viewport.x / 2, proj.columns.1.y * u.viewport.y / 2)
        // Colours go out linear when SceneKit's target encodes sRGB on write.
        u.srgbTarget = srgb ? 1 : 0
        u.limits = SIMD4(nearCull, maxRadius, 0, 0)
        return u
    }

    /// Encodes gsxProject over the draw list (one thread per splat) and returns the buffer it
    /// fills, which `drawQuads` reads.
    private func encodeProjection(_ state: GsxStream.DrawState, uniforms: inout GsxUniforms,
                                  commandBuffer: MTLCommandBuffer) -> MTLBuffer? {
        let device = commandBuffer.device
        if projectPipeline == nil {
            projectPipeline = device.makeDefaultLibrary()?.makeFunction(name: "gsxProject")
                .flatMap { try? device.makeComputePipelineState(function: $0) }
        }
        // One slot per entry of the order buffer, the most that can be drawn.
        let capacity = state.order.length / MemoryLayout<UInt32>.stride
        if (projected?.length ?? 0) < capacity * Self.projectedStride {
            projected = device.makeBuffer(length: capacity * Self.projectedStride, options: .storageModePrivate)
        }
        guard let pso = projectPipeline, let projected,
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        var count = UInt32(state.count)
        encoder.label = "Gaussian splats (project)"
        encoder.setComputePipelineState(pso)
        encoder.setBuffer(state.splats, offset: 0, index: 0)
        encoder.setBuffer(state.order, offset: 0, index: 1)
        encoder.setBuffer(projected, offset: 0, index: 2)
        encoder.setBytes(&uniforms, length: MemoryLayout<GsxUniforms>.stride, index: 3)
        encoder.setBytes(&count, length: MemoryLayout<UInt32>.stride, index: 4)
        encoder.dispatchThreads(MTLSize(width: state.count, height: 1, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: min(256, pso.maxTotalThreadsPerThreadgroup), height: 1, depth: 1))
        encoder.endEncoding()
        return projected
    }

    private func drawQuads(_ count: Int, projected: MTLBuffer, uniforms: inout GsxUniforms, encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBuffer(projected, offset: 0, index: 1)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<GsxUniforms>.stride, index: 3)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: count)
    }

    // MARK: - Helpers

    /// Bounds in the containing scene, including the JSON transform. Ordinary SCNView
    /// uses these to fit its orbit camera without relying on an AR session or geometry.
    @MainActor
    func sceneBounds() -> (minimum: SIMD3<Float>, maximum: SIMD3<Float>)? {
        guard let current = lock.withLock({ self.stream.map {
            (stream: $0, follows: followsPointCloud, geo: georeference, shift: georeferenceShift)
        } }), let bounds = current.stream.bounds,
              let local = dataToNode(current.stream, followsPointCloud: current.follows,
                                     georeference: current.geo, shift: current.shift) else { return nil }
        let model = node.simdTransform * local
        var minimum = SIMD3<Float>(repeating: .infinity)
        var maximum = SIMD3<Float>(repeating: -.infinity)
        for corner in 0..<8 {
            let sign = SIMD3<Float>((corner & 1) == 0 ? -1 : 1,
                                    (corner & 2) == 0 ? -1 : 1,
                                    (corner & 4) == 0 ? -1 : 1)
            let p = model * SIMD4<Float>(bounds.center + sign * bounds.extent / 2, 1)
            guard p.x.isFinite, p.y.isFinite, p.z.isFinite else { return nil }
            minimum = simd_min(minimum, SIMD3<Float>(p.x, p.y, p.z))
            maximum = simd_max(maximum, SIMD3<Float>(p.x, p.y, p.z))
        }
        return (minimum, maximum)
    }

    var hasVisibleSplats: Bool {
        lock.withLock { stream?.drawState() != nil }
    }

    var streamFailure: String? {
        lock.withLock {
            guard let stats = stream?.stats, stats.state == "failed" else { return nil }
            return stats.lastError
        }
    }

    /// .gsx data space → node space: same convention as the point cloud readers, which turn
    /// Z-up project coordinates (x, y, z) into (x, z, -y). Centred on the splats themselves
    /// until `followPointCloud(position:)` hands the placement to the node.
    private func dataToNode(
        _ stream: GsxStream,
        followsPointCloud: Bool,
        georeference: GaussianSplatGeoreference?,
        shift: SIMD3<Double>
    ) -> simd_float4x4? {
        let zUpToYUp = simd_float4x4(simd_quatf(angle: -.pi / 2, axis: [1, 0, 0]))
        if let georeference {
            let localShift = simd_double4x4(columns: (
                SIMD4<Double>(1, 0, 0, 0),
                SIMD4<Double>(0, 1, 0, 0),
                SIMD4<Double>(0, 0, 1, 0),
                SIMD4<Double>(shift, 1)
            ))
            // Compose in Double precision before converting to the renderer's Float matrix.
            // Project CRS coordinates can be millions of metres from the origin.
            let projectLocalFromPly = localShift * georeference.projectFromPly
            let c = projectLocalFromPly.columns
            let model = simd_float4x4(columns: (
                SIMD4<Float>(Float(c.0.x), Float(c.0.y), Float(c.0.z), Float(c.0.w)),
                SIMD4<Float>(Float(c.1.x), Float(c.1.y), Float(c.1.z), Float(c.1.w)),
                SIMD4<Float>(Float(c.2.x), Float(c.2.y), Float(c.2.z), Float(c.2.w)),
                SIMD4<Float>(Float(c.3.x), Float(c.3.y), Float(c.3.z), Float(c.3.w))
            ))
            return zUpToYUp * model
        }
        if followsPointCloud { return zUpToYUp }
        guard let bounds = stream.bounds else { return nil }
        var center = matrix_identity_float4x4
        center.columns.3 = SIMD4(-bounds.center, 1)
        return zUpToYUp * center
    }

    /// Matches SceneKit's pass (formats and MSAA sample count), which changes with settings
    /// such as AR occlusion.
    private func pipeline(device: MTLDevice, pass: MTLRenderPassDescriptor, target: MTLTexture) -> MTLRenderPipelineState? {
        let depthFormat = pass.depthAttachment.texture?.pixelFormat ?? .invalid
        let stencilFormat = pass.stencilAttachment.texture?.pixelFormat ?? .invalid
        let key = "\(target.pixelFormat.rawValue)|\(depthFormat.rawValue)|\(stencilFormat.rawValue)|\(target.sampleCount)"
        if let cached = pipelines[key] { return cached }
        guard let library = device.makeDefaultLibrary() else { return nil }
        let d = MTLRenderPipelineDescriptor()
        d.label = "Gaussian splats"
        d.vertexFunction = library.makeFunction(name: "gsxVertex")
        d.fragmentFunction = library.makeFunction(name: "gsxFragment")
        d.rasterSampleCount = target.sampleCount
        d.depthAttachmentPixelFormat = depthFormat
        d.stencilAttachmentPixelFormat = stencilFormat
        // Premultiplied alpha, back to front.
        let c = d.colorAttachments[0]!
        c.pixelFormat = target.pixelFormat
        c.isBlendingEnabled = true
        c.sourceRGBBlendFactor = .one
        c.sourceAlphaBlendFactor = .one
        c.destinationRGBBlendFactor = .oneMinusSourceAlpha
        c.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        guard let state = try? device.makeRenderPipelineState(descriptor: d) else { return nil }
        pipelines[key] = state
        return state
    }

    /// Tested against the scene's depth, never written: splats are sorted, not depth-resolved.
    private func depthState(device: MTLDevice, reverseZ: Bool) -> MTLDepthStencilState? {
        if let cached = depthStates[reverseZ] { return cached }
        let d = MTLDepthStencilDescriptor()
        d.depthCompareFunction = reverseZ ? .greaterEqual : .lessEqual
        d.isDepthWriteEnabled = false
        let state = device.makeDepthStencilState(descriptor: d)
        depthStates[reverseZ] = state
        return state
    }

    private static func isSRGB(_ f: MTLPixelFormat) -> Bool {
        [.bgra8Unorm_srgb, .rgba8Unorm_srgb, .bgra10_xr_srgb, .bgr10_xr_srgb].contains(f)
    }
}
