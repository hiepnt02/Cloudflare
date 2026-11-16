//
//  ViewARIFCOpacityEvent.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import Foundation

class ViewARDesignOpacityEvent: EventIdentity, ViewAREvent {
    let design: ARDesignType
    let layerNode: LayerNode?
    let opacity: Double
    
    init(_ design: ARDesignType, _ layerNode: LayerNode?, _ opacity: Double) {
        self.design = design
        self.layerNode = layerNode
        self.opacity = opacity
    }
    
    func call(_ context: ViewARContext) {
        context.updateOpacity(design: design, for: layerNode, opacity: opacity)
    }
}
