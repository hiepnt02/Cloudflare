//
//  ViewAROcclusionEvent.swift
//  Quick3D
//
//  Created by HungNT on 5/5/26.
//

import Foundation

class ViewAROcclusionEvent: EventIdentity, ViewAREvent {
    let isOn: Bool
    init(_ isOn: Bool) { self.isOn = isOn }
    
    func call(_ context: ViewARContext) {
        context.toggleOcclusion(isEnabled: isOn)
    }
}
