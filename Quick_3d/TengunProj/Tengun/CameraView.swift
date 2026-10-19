//
//  CameraView.swift
//  UI
//
//  Created by 木皿直規 on 2022/02/13.
//

import SwiftUI
import AVFoundation

enum RecordingStatus: String {
    case ready
    case start
    case stop
}

public protocol CameraViewDelegate: AnyObject {
    func didFinishRecording(outputFileURL: URL)
}

extension UICameraView: AVCaptureFileOutputRecordingDelegate {
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        delegate?.didFinishRecording(outputFileURL: outputFileURL)
    }
}

//----------------------------------------------------------
// CameraView
//----------------------------------------------------------
struct CameraView: UIViewRepresentable {
    @Binding var recordingStatus: RecordingStatus
    
    let didFinishRecording: (_ outputFileURL: URL) -> Void
    
    final public class Coordinator: NSObject, CameraViewDelegate {
        private var cameraView: CameraView
        let didFinishRecording: (_ outputFileURL: URL) -> Void
        
        init(_ cameraView: CameraView, didFinishRecording: @escaping (_ outputFileURL:URL) -> Void) {
            self.cameraView = cameraView
            self.didFinishRecording = didFinishRecording
        }
        
        func didFinishRecording(outputFileURL: URL) {
            didFinishRecording(outputFileURL)
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self, didFinishRecording: didFinishRecording)
    }
    
    func makeUIView(context: Context) -> UICameraView {
        let uiCameraView = UICameraView()
        uiCameraView.delegate = context.coordinator
        return uiCameraView
    }
    
    func updateUIView(_ uiView: UICameraView, context: Context) {
        switch recordingStatus {
        case .ready:
            return
        case .start:
            uiView.startRecording()
        case .stop:
            uiView.stopRecording()
        }
    }
}

/*
struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView(recordingStatus: RecordingStatus.ready, didFinishRecording: <#(URL) -> Void#>)
    }
}
*/

//----------------------------------------------------------
// UICameraView
//----------------------------------------------------------
public class UICameraView: UIView {
    private var videoDevice: AVCaptureDevice?
    private let fileOutput = AVCaptureMovieFileOutput()
    private var videoLayer : AVCaptureVideoPreviewLayer!
    public weak var delegate: CameraViewDelegate?
        
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let captureSession: AVCaptureSession = AVCaptureSession()
        videoDevice = defaultCamera()
        let audioDevice: AVCaptureDevice? = AVCaptureDevice.default(for: AVMediaType.audio)

        // video input setting
        let videoInput: AVCaptureDeviceInput = try! AVCaptureDeviceInput(device: videoDevice!)
        captureSession.addInput(videoInput)

        // audio input setting
        let audioInput = try! AVCaptureDeviceInput(device: audioDevice!)
        captureSession.addInput(audioInput)

        // max duration setting
        fileOutput.maxRecordedDuration = CMTimeMake(value: 60, timescale: 1)

        captureSession.addOutput(fileOutput)

        // video quality setting
        captureSession.beginConfiguration()
        if captureSession.canSetSessionPreset(.hd4K3840x2160) {
            captureSession.sessionPreset = .hd4K3840x2160
        } else if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }
        captureSession.commitConfiguration()

        captureSession.startRunning()

        // video preview layer
        videoLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        videoLayer.connection?.videoOrientation = .landscapeRight

        layer.addSublayer(videoLayer)
    }
    
    public override func layoutSubviews() {
        videoLayer.frame = bounds
    }
    
    func startRecording() {
        // start recording
        let tempDirectory: URL = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL: URL = tempDirectory.appendingPathComponent("mytemp1.mov")
        fileOutput.startRecording(to: fileURL, recordingDelegate: self)
    }
    
    func stopRecording() {
        // stop recording
        fileOutput.stopRecording()
    }
    
    private func defaultCamera() -> AVCaptureDevice? {
        if let device = AVCaptureDevice.default(.builtInDualCamera, for: AVMediaType.video, position: .back) {
            return device
        } else if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back) {
            return device
        } else {
            return nil
        }
    }
}


