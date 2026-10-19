//
//  SCNPreviewView.swift
//  Quick3D
//
//  Created by HaNST on 10/09/25.
//

import SwiftUI
import SceneKit
import RealityKit
import simd

struct SCNPreviewView<C: PreviewContext> : UIViewRepresentable {
    
    @Binding var context : C
    
    func makeUIView(context: Context) -> SCNView {
        
        let delegate = context.coordinator
        
        let scnView = SCNView(frame: .zero)
        
        delegate.setup(scnView)
        
        // Prevent double clicks to reset camera angle.
        if let recognizers = scnView.gestureRecognizers {
            for gestureRecognizer in recognizers {
                if let tapGesture = gestureRecognizer as? UITapGestureRecognizer,
                   tapGesture.numberOfTapsRequired == 2 {
                    
                    // Remove the gesture recognizer completely
                    scnView.removeGestureRecognizer(tapGesture)
                }
            }
        }

        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
    }
    
    func makeCoordinator() -> PreviewContextWrapper<C> {
        PreviewContextWrapper(context: context)
    }
    
    static func dismantleUIView(_ uiView: SCNView, coordinator: PreviewContextWrapper<C>) {
        coordinator.clear()
        uiView.delegate = nil
        uiView.scene?.rootNode.enumerateChildNodes { (node, stop) in
            node.removeFromParentNode()
        }
    }
}

