//
//  ARCameraView.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import SwiftUI
import ARKit

struct ARCameraView<C: CameraContext>: UIViewRepresentable {

    typealias Content = C.Content
    
    @Binding
    var context : C
    
    func makeUIView(context: Context) -> Content {
        let arView = Content.init(frame: .zero)
        
        let wrapper = context.coordinator

        wrapper.setup(arView)

        return arView
    }

    func updateUIView(_ uiView: Content, context: Context) {
    }

    static func dismantleUIView(_ uiView: Content, coordinator: CameraContextWrapper<C>) {
        coordinator.clear()
        uiView.clearDelegate()
        uiView.session.pause()
        uiView.removeView()
    }

    func makeCoordinator() -> CameraContextWrapper<C> {
        return CameraContextWrapper(context: context)
    }
}
