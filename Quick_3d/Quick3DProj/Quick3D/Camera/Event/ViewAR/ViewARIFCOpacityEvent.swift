//
//  ViewARIFCOpacityEvent.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import Foundation

class ViewARIFCOpacityEvent: EventIdentity, ViewAREvent {
    let layerNode: LayerNode?
    let opacity: Double
    
    init(_ layerNode: LayerNode?, _ opacity: Double) {
        self.layerNode = layerNode
        self.opacity = opacity
    }
    
    func call(_ context: ViewARContext) {
        context.updateOpacity(for: layerNode, opacity: opacity)
    }
}
