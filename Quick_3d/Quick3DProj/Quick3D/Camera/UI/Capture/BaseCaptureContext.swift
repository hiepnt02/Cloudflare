//
//  BaseCaptureContext.swift
//  Quick3D
//
//  QUICK-935: Intermediate base class that centralises shared state and logic
//  from CaptureContext and ARCaptureContext.
//

import Foundation
import ARKit
import Accelerate

class BaseCaptureContext<T: ARContentView>: CameraContextTemplate<T>, CaptureEventContext, ARSessionDelegate {

    required override init() { super.init() }

    var delegate: CaptureDelegate?

    public private(set) var status: ARStatus = .initial

    var isEnableMesh = false

    var resolution: ImageResolutionEnum = .normal

    var isReady = false

    var overlapCalculator: OverlapCalculator = FovOverlapCalculator()

    let imageProcessor: ImageProcessor = .init()

    var isProcessing: ThreadSafeValue<Bool> = .init(false)

    var lastProcessingTime: TimeInterval = 0

    var lastFrameTime: TimeInterval = 0

    override func configuration() -> ARConfiguration {

        let configuration = ARWorldTrackingConfiguration()

        configuration.worldAlignment = .gravity
        configuration.frameSemantics = [.sceneDepth]
        configuration.isAutoFocusEnabled = true
        configuration.environmentTexturing = .none
        configuration.isLightEstimationEnabled = false

        isEnableMesh = UserSession.shared.isEnableMesh || UserSession.shared.isSaveMesh

        if isEnableMesh {
            configuration.sceneReconstruction = .mesh
        }

        resolution = UserSession.shared.imageResolution

        if let format = CameraVideoFormatHelper.videoFromats[resolution] {
            configuration.videoFormat = format
        }

        return configuration
    }

    override func options() -> ARSession.RunOptions {
        return [.resetTracking, .resetSceneReconstruction, .removeExistingAnchors]
    }

    func applySettings() {

        let resolution = UserSession.shared.imageResolution
        let isEnableMesh = UserSession.shared.isEnableMesh || UserSession.shared.isSaveMesh

        if resolution != self.resolution || isEnableMesh != self.isEnableMesh {
            start()
        }
    }

    func preCapture() {
        resetDistances()
    }

    func resetDistances() {
        overlapCalculator.resetDistances()
    }

    func perform(_ event: any Event) {
        handle(event) { [weak self] in
            if let ctx = self, let e = event as? CaptureEvent {
                DispatchQueue.main.async {
                    e.call(ctx)
                }
            }
        }
    }

    func error(_ error: any Error) {
        delegate?.capture(CaptureSession.current, error: error, action: nil)
    }

    override func clear() {
        super.clear()
        ARTrackingObject.shared.reset()
    }

    func discard() {

        imageProcessor.cancel()

        StorageManager.cancel()

        CaptureSession.stop()

        overlapCalculator.lastFrame = nil

        DispatchQueue.main.async {
            self.cleanupMesh()
            self.delegate?.capture(CaptureSession.current, didCapture: 0)
            self.delegate?.capture(CaptureSession.current, didCalculateOverlap: 0.0, zDistance: 0.0)
            self.delegate?.capture(CaptureSession.current, didStart: self.isReady)
        }
    }

    func cleanupMesh() {}

    func ready(_ value: Bool) {
        if isReady != value {
            isReady = value
            DispatchQueue.main.async {
                self.delegate?.capture(CaptureSession.current, didStart: self.isReady)
            }
        }
    }

    func changeStatus(_ status: ARStatus) {
        DispatchQueue.main.async {
            if self.status == status {
                return
            }

            self.status = status

            self.delegate?.capture(CaptureSession.current, didChange: status)
        }
    }

    func handleAsync(error: Error, action: (() -> Void)?) {
        DispatchQueue.main.async {
            self.delegate?.capture(CaptureSession.current, error: error, action: action)
        }
    }

    func handleAsync(error: Error) {
        handleAsync(error: error, action: nil)
    }

    func waitUntilCompleted() {
        imageProcessor.waitUntilCompleted()
        StorageManager.waitUntilCompleted()
    }

    func combine() throws {
        waitUntilCompleted()
        try imageProcessor.combine()
    }

    // MARK: - ARSessionDelegate (shared frame-processing logic)

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        ARTrackingObject.shared.update(state: camera.trackingState)
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {

        defer {
            lastFrameTime = frame.timestamp
        }

        switch frame.camera.trackingState {
        case .normal:
            break
        default:
            return
        }

        ready(true)

        CaptureSession.current?.livePreviewContext?.update(frame.camera.transform, frame.camera.eulerAngles)

        guard status == .running,
              !isProcessing.value,
              !imageProcessor.isLimited
        else { return }

        isProcessing.value = true

        let fps = 1 / (frame.timestamp - lastFrameTime)

        queue.async {

            guard let captureSession = CaptureSession.current else {
                self.isProcessing.value = false
                return
            }

            let overlapRate = Float(captureSession.overlapRate)
            let ratioRate = Float(captureSession.ratioRate)
            let smoothingFrames = captureSession.maxSmoothingFrames

            guard frame.sceneDepth != nil else {
                self.isProcessing.value = false
                return
            }

            let (distance, overlapRatio) = self.overlapCalculator.calculateFromFov(frame, ratioRate, smoothingFrames)

            DispatchQueue.main.async {
                self.delegate?.capture(
                    captureSession,
                    didCalculateOverlap: Float(overlapRatio),
                    zDistance: distance
                )
            }

            if overlapRatio > overlapRate {
                self.isProcessing.value = false
                return
            }

            if #available(iOS 16.0, *), self.resolution == .maximum {
                session.captureHighResolutionFrame { frame, error in
                    if let f = frame {
                        self.process(captureSession, frame: f, fps: fps)
                    } else {
                        self.isProcessing.value = false
                    }
                }
            } else {
                self.process(captureSession, frame: frame, fps: fps)
            }
        }
    }

    func process(_ captureSession: CaptureSession, frame: ARFrame, fps: Double) {
        defer {
            self.isProcessing.value = false
        }

        guard let depthData = frame.sceneDepth else { return }

        applyDepthFilter(depthBuffer: depthData.depthMap,
                         confidenceBuffer: depthData.confidenceMap!)

        let index = (self.overlapCalculator.lastFrame?.index ?? 0) + 1

        if let frameData = try? FrameData(frame: frame, index: index, fps: fps) {
            self.overlapCalculator.lastFrame = FrameMetadata(frameData)

            self.imageProcessor.process(captureSession, frame: frameData) {
                DispatchQueue.main.async {
                    self.delegate?.capture(captureSession, didCapture: index)
                }
            } onError: { error in
                self.changeStatus(.pausing)
                self.handleAsync(error: error) {
                    self.discard()
                    self.changeStatus(.stopped)
                }
            }
        }
    }

    func applyDepthFilter(depthBuffer: CVPixelBuffer, confidenceBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(depthBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(confidenceBuffer, .readOnly)

        defer {
            CVPixelBufferUnlockBaseAddress(depthBuffer, .readOnly)
            CVPixelBufferUnlockBaseAddress(confidenceBuffer, .readOnly)
        }

        guard let depthAddr = CVPixelBufferGetBaseAddress(depthBuffer),
              let confAddr = CVPixelBufferGetBaseAddress(confidenceBuffer) else { return }

        let width = CVPixelBufferGetWidth(depthBuffer)
        let height = CVPixelBufferGetHeight(depthBuffer)
        let totalPixels = width * height

        let depthPtr = depthAddr.assumingMemoryBound(to: Float32.self)
        let confPtr = confAddr.assumingMemoryBound(to: UInt8.self)

        for i in 0..<totalPixels {
            let d = depthPtr[i]
            if d > 18.0 || d != d {
                confPtr[i] = 0
            }
        }
    }
}
