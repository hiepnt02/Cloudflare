//
//  ViewARIFCVisibleEvent.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import Foundation

class ViewARDesignVisibleEvent: EventIdentity, ViewAREvent {
    let design: ARDesignType
    let layerNode: LayerNode?
    let isVisible: Bool
    
    init(_ design: ARDesignType, _ layerNode: LayerNode?, _ isVisible: Bool) {
        self.design = design
        self.layerNode = layerNode
        self.isVisible = isVisible
    }
    
    func call(_ context: ViewARContext) {
        context.setVisibility(design: design, nodeName: layerNode?.name, visible: isVisible)
        layerNode?.isVisible = isVisible
    }
}
