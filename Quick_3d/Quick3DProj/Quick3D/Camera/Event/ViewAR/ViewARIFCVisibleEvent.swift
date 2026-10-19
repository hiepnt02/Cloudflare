//
//  ViewARIFCVisibleEvent.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import Foundation

class ViewARIFCVisibleEvent: EventIdentity, ViewAREvent {
    let layerNode: LayerNode?
    let isVisible: Bool
    
    init(_ layerNode: LayerNode?, _ isVisible: Bool) {
        self.layerNode = layerNode
        self.isVisible = isVisible
    }
    
    func call(_ context: ViewARContext) {
        context.setVisibility(nodeName: layerNode?.name, visible: isVisible)
        layerNode?.isVisible = isVisible
    }
}
