import SwiftUI
import SceneKit
import Metal
import simd

/// Ordinary project viewer: orbit/pinch a GSX model using SceneKit, without an AR session.
@MainActor
struct GaussianProject3DView: View {
    let projectId: String
    let title: String
    @EnvironmentObject private var userManager: UserManager
    @State private var loading = true
    @State private var failed = false
    @State private var fitRequest = 0
    @State private var orthographic = false
    @State private var attempt = 0

    var body: some View {
        ZStack {
            GaussianProjectScene(projectId: projectId, fitRequest: fitRequest,
                                 orthographic: orthographic) { state in
                loading = state == .loading
                failed = state == .failed
            }
            .id("\(projectId)-\(attempt)")

            VStack {
                Text(title).font(.headline).foregroundColor(.white).lineLimit(1)
                    .padding(.horizontal, 64).padding(.top, 12)
                Spacer()
                HStack(spacing: 24) {
                    Button { fitRequest += 1 } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .accessibilityLabel("Fit model")
                    Button { orthographic.toggle(); fitRequest += 1 } label: {
                        Text(orthographic ? "2D" : "3D")
                    }
                }
                .font(.title3).foregroundColor(.white).padding()
                .background(Color.black.opacity(0.7)).cornerRadius(12)
                .padding(.bottom, 16)
            }
            if loading { ProgressView().tint(.white) }
            if failed {
                VStack(spacing: 16) {
                    Text("DOWNLOAD_FAILED".localized(userManager.userLanguage))
                        .foregroundColor(.white)
                    Button { loading = true; failed = false; attempt += 1 } label: {
                        Image(systemName: "arrow.clockwise").font(.title2)
                    }
                    .accessibilityLabel("Retry")
                }
                .padding().background(Color.black.opacity(0.8)).cornerRadius(12)
            }
        }
        .background(Color.black)
    }
}

@MainActor
private struct GaussianProjectScene: UIViewRepresentable {
    enum State: Equatable { case loading, ready, failed }
    let projectId: String
    let fitRequest: Int
    let orthographic: Bool
    let onState: (State) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onState: onState) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero, options: [SCNView.Option.preferredRenderingAPI.rawValue:
                                                  SCNRenderingAPI.metal.rawValue])
        context.coordinator.setup(view, projectId: projectId)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let coordinator = context.coordinator
        coordinator.camera.camera?.usesOrthographicProjection = orthographic
        if coordinator.fitRequest != fitRequest {
            coordinator.fitRequest = fitRequest
            coordinator.fit(view)
        }
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.stop()
        view.isPlaying = false
        view.rendersContinuously = false
        view.scene = nil
    }

    @MainActor
    final class Coordinator: NSObject {
        let splats = GaussianSplatRenderer()
        let camera = SCNNode()
        var fitRequest = 0
        private let onState: (State) -> Void
        private var loadTask: Task<Void, Never>?
        private var timer: Timer?
        private var startedAt = Date()
        private var fitted = false

        init(onState: @escaping (State) -> Void) { self.onState = onState }

        func setup(_ view: SCNView, projectId: String) {
            guard MTLCreateSystemDefaultDevice() != nil else {
                DispatchQueue.main.async { self.onState(.failed) }
                return
            }
            let scene = SCNScene()
            scene.rootNode.addChildNode(splats.node)
            camera.camera = SCNCamera()
            camera.camera?.fieldOfView = 60
            camera.camera?.zNear = 0.01
            camera.camera?.zFar = 1_000_000
            camera.position = SCNVector3(0, 0, 10)
            scene.rootNode.addChildNode(camera)
            view.scene = scene
            view.pointOfView = camera
            view.backgroundColor = .black
            view.allowsCameraControl = true
            view.defaultCameraController.interactionMode = .orbitTurntable
            view.defaultCameraController.inertiaEnabled = true
            view.defaultCameraController.automaticTarget = false
            view.preferredFramesPerSecond = 30
            view.rendersContinuously = true
            view.isPlaying = true
            splats.nearCull = 0.01
            splats.load(projectId: projectId)
            loadTask = Task { @MainActor [weak self, weak view] in
                guard let self, let view else { return }
                let started = await self.splats.hasSplats.value
                guard !Task.isCancelled else { return }
                guard started else {
                    view.isPlaying = false
                    view.rendersContinuously = false
                    self.onState(.failed)
                    return
                }
                self.startedAt = Date()
                self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self, weak view] _ in
                    Task { @MainActor in
                        guard let self, let view else { return }
                        self.poll(view)
                    }
                }
            }
        }

        private func poll(_ view: SCNView) {
            if splats.streamFailure != nil || Date().timeIntervalSince(startedAt) > 60 {
                timer?.invalidate()
                splats.unload()
                view.isPlaying = false
                view.rendersContinuously = false
                onState(.failed)
                return
            }
            if !fitted { fitted = fit(view) }
            if fitted && splats.hasVisibleSplats {
                fit(view)
                timer?.invalidate()
                onState(.ready)
            }
        }

        @discardableResult
        func fit(_ view: SCNView) -> Bool {
            guard let bounds = splats.sceneBounds() else { return false }
            let center = (bounds.minimum + bounds.maximum) / 2
            let radius = max(0.5, simd_length(bounds.maximum - bounds.minimum) / 2)
            let aspect = max(0.1, min(1, Float(view.bounds.width / max(1, view.bounds.height))))
            let distance = radius / (sin(Float.pi / 6) * aspect) * 1.2
            camera.simdPosition = center + SIMD3<Float>(distance * 0.4, distance * 0.25, distance)
            camera.look(at: SCNVector3(center.x, center.y, center.z))
            camera.camera?.orthographicScale = Double(radius / aspect * 1.2)
            camera.camera?.zNear = Double(max(0.01, radius * 0.0001))
            camera.camera?.zFar = Double(distance * 2 + radius * 10)
            view.pointOfView = camera
            view.defaultCameraController.target = SCNVector3(center.x, center.y, center.z)
            // The splat delegate has no SCNGeometry, so supply its transformed bounds explicitly.
            splats.node.boundingBox = (SCNVector3(bounds.minimum.x, bounds.minimum.y, bounds.minimum.z),
                                       SCNVector3(bounds.maximum.x, bounds.maximum.y, bounds.maximum.z))
            return true
        }

        func stop() {
            loadTask?.cancel()
            timer?.invalidate()
            timer = nil
            splats.unload()
        }
    }
}
