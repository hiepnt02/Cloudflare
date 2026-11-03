//
//  GaussianSplatRenderer.swift
//  Quick3D
//

import Metal
import QuartzCore
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

/// The Metal side of drawing a sorted splat list into a SceneKit render pass: a compute pass
/// projects every splat of the list once, the render pass expands each into a quad. One
/// instance per SceneKit view (pipelines match that view's pass formats). Render thread only.
final class GsxSplatPass {
    private var pipelines: [String: MTLRenderPipelineState] = [:]
    private var depthStates: [Bool: MTLDepthStencilState] = [:]
    private var projected: MTLBuffer?
    private var projectPipeline: MTLComputePipelineState?
    /// Size of `GsxProjected` in GaussianSplat.metal.
    private static let projectedStride = 48

    struct Settings {
        var nearCull: Float = 0.15
        var maxRadius: Float = 0.5
        var opacity: Float = 1
    }

    func draw(
        renderer: SCNRenderer,
        splats: MTLBuffer,
        order: MTLBuffer,
        count: Int,
        viewModel: simd_float4x4,
        proj: simd_float4x4,
        settings: Settings
    ) {
        let pass = renderer.currentRenderPassDescriptor
        guard count > 0,
              let encoder = renderer.currentRenderCommandEncoder,
              let target = pass.colorAttachments[0].texture,
              let depth = depthState(device: encoder.device, reverseZ: renderer.usesReverseZ) else { return }

        var u = GsxUniforms()
        u.viewModel = viewModel
        u.proj = proj
        u.viewport = SIMD2(Float(target.width), Float(target.height))
        u.focal = SIMD2(proj.columns.0.x * u.viewport.x / 2, proj.columns.1.y * u.viewport.y / 2)
        // Colours go out linear when SceneKit's target encodes sRGB on write.
        u.srgbTarget = Self.isSRGB(target.pixelFormat) ? 1 : 0
        u.limits = SIMD4(settings.nearCull, settings.maxRadius, max(0, min(1, settings.opacity)), 0)

        // Projection on a command buffer committed now, while SceneKit is still encoding its
        // frame, so it runs first on the same queue.
        guard let pso = pipeline(device: encoder.device, pass: pass, target: target),
              let commandBuffer = renderer.commandQueue?.makeCommandBuffer(),
              let projected = encodeProjection(splats: splats, order: order, count: count,
                                               uniforms: &u, commandBuffer: commandBuffer) else { return }
        commandBuffer.label = "Gaussian splats"
        commandBuffer.commit()
        encoder.pushDebugGroup("Gaussian splats")
        encoder.setRenderPipelineState(pso)
        encoder.setDepthStencilState(depth)
        encoder.setCullMode(.none)
        encoder.setVertexBuffer(projected, offset: 0, index: 1)
        encoder.setVertexBytes(&u, length: MemoryLayout<GsxUniforms>.stride, index: 3)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: count)
        encoder.popDebugGroup()
    }

    /// Encodes gsxProject over the draw list (one thread per splat) and returns the buffer it
    /// fills, which the vertex shader reads.
    private func encodeProjection(splats: MTLBuffer, order: MTLBuffer, count: Int, uniforms: inout GsxUniforms,
                                  commandBuffer: MTLCommandBuffer) -> MTLBuffer? {
        let device = commandBuffer.device
        if projectPipeline == nil {
            projectPipeline = device.makeDefaultLibrary()?.makeFunction(name: "gsxProject")
                .flatMap { try? device.makeComputePipelineState(function: $0) }
        }
        // One slot per entry of the order buffer, the most that can be drawn.
        let capacity = order.length / MemoryLayout<UInt32>.stride
        if (projected?.length ?? 0) < capacity * Self.projectedStride {
            projected = device.makeBuffer(length: capacity * Self.projectedStride, options: .storageModePrivate)
        }
        guard let pso = projectPipeline, let projected,
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        var n = UInt32(count)
        encoder.label = "Gaussian splats (project)"
        encoder.setComputePipelineState(pso)
        encoder.setBuffer(splats, offset: 0, index: 0)
        encoder.setBuffer(order, offset: 0, index: 1)
        encoder.setBuffer(projected, offset: 0, index: 2)
        encoder.setBytes(&uniforms, length: MemoryLayout<GsxUniforms>.stride, index: 3)
        encoder.setBytes(&n, length: MemoryLayout<UInt32>.stride, index: 4)
        encoder.dispatchThreads(MTLSize(width: count, height: 1, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: min(256, pso.maxTotalThreadsPerThreadgroup), height: 1, depth: 1))
        encoder.endEncoding()
        return projected
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

/// Gaussian splat layer of the SceneKit AR view: streams the project's .gsx (the file the web
/// viewer shows) and draws it into SceneKit's render pass, where the depth test hides splats
/// behind the point cloud, the IFC model and the occlusion mesh.
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

    /// Layer opacity from the AR slider (0...1). Set on the main thread, read by the render
    /// thread; a torn read of one Float only mis-shades a frame.
    var opacity: Float = 1

    /// Whether the project last passed to `load` has splats, once the lookup has finished.
    private(set) var hasSplats = Task<Bool, Never> { false }
    /// Fetches the geo JSON and projects it while the stream already loads; applied when done.
    private var georeferenceTask: Task<Void, Never>?

    private let lock = NSLock()
    private var stream: GsxStream?
    /// Whether `node.position` places the data (see `followPointCloud`).
    private var followsPointCloud = false
    /// PLY-local -> project CRS, when the project has a geo JSON.
    private var georeference: GaussianSplatGeoreference?
    /// Negative LAS origin in project Z-up coordinates: what the point cloud node subtracts
    /// from project coordinates before its own Z-up -> Y-up swap.
    private var pointCloudShift: SIMD3<Double> = .zero

    // Render-thread state.
    private let pass = GsxSplatPass()

    override init() {
        super.init()
        node.name = "GaussianSplat"
        node.renderingOrder = Self.renderingOrder
        node.rendererDelegate = self
    }

    // MARK: - Loading

    /// Streams the project's latest converted splat file, if it has one. As in 2234 the stream
    /// starts as soon as the file URL is known, so splats show up progressively while they
    /// load; the georeference (geo JSON + four coordinate conversions) is fetched alongside and
    /// moves the splats into place the moment it is ready.
    func load(projectId: String) {
        unload()
        hasSplats = Task { [weak self] in
            guard let url = await GsxProject.fileURL(projectId: projectId) else { return false }
            // unload() runs on the main thread too, so this check cannot race it.
            return await MainActor.run { [weak self] in
                guard !Task.isCancelled, let self else { return false }
                self.start(url: url)
                self.fetchGeoreference(projectId: projectId)
                return true
            }
        }
    }

    /// Main thread. The result applies only to the stream that was current when it started.
    private func fetchGeoreference(projectId: String) {
        georeferenceTask?.cancel()
        let streamAtStart = lock.withLock { stream }
        georeferenceTask = Task { [weak self] in
            let georeference = await GsxProject.georeference(projectId: projectId)
            guard !Task.isCancelled, let georeference else { return }
            await MainActor.run { [weak self] in
                guard !Task.isCancelled, let self else { return }
                self.lock.withLock {
                    guard self.stream === streamAtStart else { return }
                    self.georeference = georeference
                }
            }
        }
    }

    func unload() {
        hasSplats.cancel()
        georeferenceTask?.cancel()
        georeferenceTask = nil
        node.simdPosition = .zero
        let old = lock.withLock { () -> GsxStream? in
            let s = stream
            stream = nil
            followsPointCloud = false
            georeference = nil
            pointCloudShift = .zero
            return s
        }
        old?.stop()
    }

    /// Splats share the point cloud's local frame (the web viewer draws both in one scene with
    /// no transform between them), so they take the point cloud node's position and line up
    /// with it and with the IFC, which is placed relative to the point cloud.
    ///
    /// `projectOffset` is `SfmProject.offset`, the LAS origin in project coordinates (Y-up):
    /// BVHReader reports `lasOrigin + center` and moves its node to `-center`, so
    /// offset + position is the stable `lasOrigin` (the IFC is placed at `ifcOffset - lasOffset`
    /// and calibration subtracts it). Splats need the negative, like the web viewer's
    /// `getOffset()`.
    func followPointCloud(position: SIMD3<Float>, projectOffset: SIMD3<Double>) {
        node.simdPosition = position
        let yUp = projectOffset + SIMD3<Double>(position)
        // Y-up (x, z, -y) back to project Z-up (x, y, z), then negate.
        let shift: SIMD3<Double> = -[yUp.x, -yUp.z, yUp.y]
        lock.withLock {
            followsPointCloud = true
            pointCloudShift = shift
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

    /// The stream and the current data → node matrix, for a second view drawing the same
    /// splats (see `GaussianSplatPreviewRenderer`). Any thread.
    func currentSource() -> (stream: GsxStream, model: simd_float4x4)? {
        guard let current = lock.withLock({ self.stream.map {
                  (stream: $0, follows: followsPointCloud, georeference: georeference, shift: pointCloudShift)
              } }),
              let model = dataToNode(current.stream, followsPointCloud: current.follows,
                                     georeference: current.georeference, pointCloudShift: current.shift) else { return nil }
        return (current.stream, model)
    }

    var passSettings: GsxSplatPass.Settings {
        GsxSplatPass.Settings(nearCull: nearCull, maxRadius: maxRadius, opacity: opacity)
    }

    // MARK: - SCNNodeRendererDelegate

    func renderNode(_ node: SCNNode, renderer: SCNRenderer, arguments: [String: Any]) {
        guard opacity > 0,
              let modelView = arguments[SCNModelViewTransform] as? NSValue,
              let projection = arguments[SCNProjectionTransform] as? NSValue,
              let source = currentSource() else { return }
        let stream = source.stream

        let proj = simd_float4x4(projection.scnMatrix4Value)
        let viewModel = simd_float4x4(modelView.scnMatrix4Value) * source.model
        stream.setProjection(proj)
        stream.updateCamera(viewModel: viewModel)

        guard let state = stream.drawState() else { return }
        pass.draw(renderer: renderer, splats: state.splats, order: state.order, count: state.count,
                  viewModel: viewModel, proj: proj, settings: passSettings)
    }

    // MARK: - Helpers

    /// .gsx data space → node space: same convention as the point cloud readers, which turn
    /// Z-up project coordinates (x, y, z) into (x, z, -y). Centred on the splats themselves
    /// until `followPointCloud(position:projectOffset:)` hands the placement to the node.
    ///
    /// With a georeference the data is PLY-local: it is first mapped to project coordinates,
    /// then shifted by the scene origin (the point cloud's, or the PLY origin itself when the
    /// project has no point cloud), like `getModelMatrix` in the web viewer.
    private func dataToNode(
        _ stream: GsxStream,
        followsPointCloud: Bool,
        georeference: GaussianSplatGeoreference?,
        pointCloudShift: SIMD3<Double>
    ) -> simd_float4x4? {
        let zUpToYUp = simd_float4x4(simd_quatf(angle: -.pi / 2, axis: [1, 0, 0]))
        if let georeference {
            let shift: SIMD3<Double>
            if followsPointCloud {
                shift = pointCloudShift
            } else {
                // No point cloud: centre the splats themselves at the node, like BVHReader does
                // with `-center`. Where the PLY origin sits relative to the ground varies per
                // dataset, so it must not decide where the AR camera starts.
                guard let bounds = stream.bounds else { return nil }
                let centre = georeference.projectFromPly * SIMD4<Double>(SIMD3<Double>(bounds.center), 1)
                shift = -SIMD3<Double>(centre.x, centre.y, centre.z)
            }
            // Composed in Double: project coordinates run to millions of metres, only the
            // shifted result is small enough for Float.
            var local = georeference.projectFromPly
            local.columns.3 += SIMD4<Double>(shift, 0)
            let model = simd_float4x4(columns: (
                SIMD4<Float>(local.columns.0),
                SIMD4<Float>(local.columns.1),
                SIMD4<Float>(local.columns.2),
                SIMD4<Float>(local.columns.3)
            ))
            return zUpToYUp * model
        }
        if followsPointCloud { return zUpToYUp }
        guard let bounds = stream.bounds else { return nil }
        var center = matrix_identity_float4x4
        center.columns.3 = SIMD4(-bounds.center, 1)
        return zUpToYUp * center
    }
}

/// Draws the splats of a `GaussianSplatRenderer` in another SceneKit view (the top-down AR
/// preview) with the same Metal pass. The stream's draw list is sorted for the AR camera, so
/// this keeps its own list, re-sorted for the preview camera on a background queue at most a
/// few times a second. Attach as `rendererDelegate` of the preview's copy of the splat node.
final class GaussianSplatPreviewRenderer: NSObject, SCNNodeRendererDelegate, @unchecked Sendable {

    private weak var source: GaussianSplatRenderer?
    private let pass = GsxSplatPass()
    private let sortQueue = DispatchQueue(label: "gsx.preview.sort", qos: .utility)
    private let scratch = GsxStream.SortScratch()
    private let lock = NSLock()

    private var orders: [MTLBuffer] = []
    private var published: (buffer: Int, count: Int, splats: MTLBuffer)?
    private var sortedView: simd_float4x4?
    private var sortedVersion = -1
    private var sortedStream: ObjectIdentifier?
    private var isSorting = false
    private var lastSortAt: CFTimeInterval = 0
    private static let minSortInterval: CFTimeInterval = 0.4

    init(source: GaussianSplatRenderer) {
        self.source = source
    }

    func renderNode(_ node: SCNNode, renderer: SCNRenderer, arguments: [String: Any]) {
        guard let source, source.opacity > 0,
              let modelView = arguments[SCNModelViewTransform] as? NSValue,
              let projection = arguments[SCNProjectionTransform] as? NSValue,
              let current = source.currentSource() else { return }
        let proj = simd_float4x4(projection.scnMatrix4Value)
        let viewModel = simd_float4x4(modelView.scnMatrix4Value) * current.model

        // While this view is open the stream also loads around the main camera, in every
        // direction, sparser with distance.
        current.stream.requestSurroundings()
        scheduleSort(stream: current.stream, viewModel: viewModel, viewProj: proj * viewModel, device: renderer.device)

        guard let current = lock.withLock({ () -> ((buffer: Int, count: Int, splats: MTLBuffer), MTLBuffer)? in
            guard let published, orders.indices.contains(published.buffer) else { return nil }
            return (published, orders[published.buffer])
        }) else { return }
        pass.draw(renderer: renderer, splats: current.0.splats, order: current.1, count: current.0.count,
                  viewModel: viewModel, proj: proj, settings: source.passSettings)
    }

    private static func changed(_ a: simd_float4x4, _ b: simd_float4x4) -> Bool {
        let d = simd_max(simd_max(simd_abs(a.columns.0 - b.columns.0), simd_abs(a.columns.1 - b.columns.1)),
                         simd_max(simd_abs(a.columns.2 - b.columns.2), simd_abs(a.columns.3 - b.columns.3)))
        return simd_reduce_max(d) > 1e-4
    }

    private func scheduleSort(stream: GsxStream, viewModel: simd_float4x4, viewProj: simd_float4x4, device: MTLDevice?) {
        let now = CACurrentMediaTime()
        let streamId = ObjectIdentifier(stream)
        let shouldSort: Bool = lock.withLock {
            guard !isSorting, now - lastSortAt >= Self.minSortInterval else { return false }
            let version = stream.residentSnapshot()?.version ?? -1
            let moved = sortedView.map { Self.changed($0, viewModel) } ?? true
            guard moved || version != sortedVersion || streamId != sortedStream else { return false }
            isSorting = true
            lastSortAt = now
            return true
        }
        guard shouldSort else { return }

        sortQueue.async { [weak self] in
            guard let self else { return }
            defer { self.lock.withLock { self.isSorting = false } }
            guard let snapshot = stream.residentSnapshot(), let device else { return }
            let capacity = stream.orderCapacity
            guard capacity > 0 else { return }

            // Two order buffers: one being drawn, one being written.
            let target: Int = self.lock.withLock {
                if self.orders.count < 2 || self.orders[0].length < capacity * 4 {
                    self.orders = (0..<2).compactMap { _ in
                        device.makeBuffer(length: capacity * 4, options: .storageModeShared)
                    }
                    self.published = nil
                }
                guard self.orders.count == 2 else { return -1 }
                return ((self.published?.buffer ?? -1) + 1) % 2
            }
            guard target >= 0 else { return }
            let output = self.orders[target].contents().bindMemory(to: UInt32.self, capacity: capacity)
            let n = GsxStream.sortBackToFront(blocks: snapshot.blocks, positions: snapshot.positions,
                                              viewModel: viewModel, viewProj: viewProj,
                                              output: output, scratch: self.scratch)
            self.lock.withLock {
                self.published = (target, n, snapshot.splats)
                self.sortedView = viewModel
                self.sortedVersion = snapshot.version
                self.sortedStream = streamId
            }
        }
    }
}
