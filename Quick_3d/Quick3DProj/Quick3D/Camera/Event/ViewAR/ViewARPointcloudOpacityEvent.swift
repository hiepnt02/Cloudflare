//
//  ViewARPointcloudOpacityEvent.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import Foundation

class ViewARPointcloudOpacityEvent: EventIdentity, ViewAREvent {
    let opacity: Double
    
    init(_ opacity: Double) {
        self.opacity = opacity
    }
    
    func call(_ context: ViewARContext) {
        if let node = context.pointCloudNode {
            context.updatePointCloudOpacity(for: node, opacity: CGFloat(opacity))
        }
    }
}

/// Opacity of the Gaussian splat layer, 0...1 (SC_QUICK-2238).
class ViewARSplatOpacityEvent: EventIdentity, ViewAREvent {
    let opacity: Double

    init(_ opacity: Double) {
        self.opacity = opacity
    }

    func call(_ context: ViewARContext) {
        context.setSplatOpacity(opacity)
    }
}
