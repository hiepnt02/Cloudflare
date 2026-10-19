//
//  ARSCNCameraView.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import SwiftUI
import ARKit

struct ARSCNCameraView<C: CameraContext>: UIViewRepresentable {

    @Binding
    var context : C
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        
        let wrapper = context.coordinator

        wrapper.setup(arView)

        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
    }

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: CameraContextWrapper<C>) {
        coordinator.clear()
        uiView.delegate = nil
        uiView.session.delegate = nil
        uiView.session.pause()
        uiView.scene.rootNode.enumerateChildNodes { (node, stop) in
            node.removeFromParentNode()
        }
    }

    func makeCoordinator() -> CameraContextWrapper<C> {
        return CameraContextWrapper(context: context)
    }
}
