//
//  ViewARAxisVisibleEvent.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import Foundation

class ViewARAxisVisibleEvent: EventIdentity, ViewAREvent {
    let visible: Bool
    
    init(_ visible: Bool) {
        self.visible = visible
    }
    
    func call(_ context: ViewARContext) {
        context.axisNode.isHidden = !visible
    }
}
