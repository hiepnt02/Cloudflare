//
//  ViewARPointcloudVisibleEvent.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import Foundation

class ViewARPointcloudVisibleEvent: EventIdentity, ViewAREvent {
    let visible: Bool
    
    init(_ visible: Bool) {
        self.visible = visible
    }
    
    func call(_ context: ViewARContext) {
        context.pointCloudNode?.isHidden = !visible
        context.previewContext?.updateNode(context.pointCloudNode)
    }
}

/// Shows or hides the Gaussian splat layer (SC_QUICK-2238).
class ViewARSplatVisibleEvent: EventIdentity, ViewAREvent {
    let visible: Bool

    init(_ visible: Bool) {
        self.visible = visible
    }

    func call(_ context: ViewARContext) {
        context.setSplatVisible(visible)
    }
}
