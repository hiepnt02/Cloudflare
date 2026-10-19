//
//  SceneViews.swift
//  Quick3DDemo
//
//  Tầng ② — cầu SwiftUI → UIKit. SwiftUI không vẽ 3D được, phải bọc view UIKit.
//  Tương đương useEffect(() => { viewer = new Viewer(canvas); return () => viewer.dispose() })
//  Trong project thật: Camera/UI/CommonUI/ARCameraView.swift (generic qua CameraContext)
//

import SwiftUI
import SceneKit
import ARKit

struct Demo3DView: UIViewRepresentable {
    let context: Demo3DContext

    func makeCoordinator() -> Demo3DContext { context }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        context.coordinator.setup(view)          // đưa view cho Context
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    static func dismantleUIView(_ uiView: SCNView, coordinator: Demo3DContext) {
        coordinator.clear()                      // = viewer.dispose()
        uiView.scene = nil
    }
}

struct DemoARView: UIViewRepresentable {
    let context: DemoARContext

    func makeCoordinator() -> DemoARContext { context }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        context.coordinator.setup(view)
        context.coordinator.start()              // session.run(configuration)
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: DemoARContext) {
        coordinator.pause()
        coordinator.clear()
    }
}
