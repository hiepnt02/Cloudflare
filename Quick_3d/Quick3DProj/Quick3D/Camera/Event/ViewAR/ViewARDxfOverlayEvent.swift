//
//  ViewARDxfOverlayEvent.swift
//  Quick3D
//

import Foundation

class ViewARDxfOverlayEvent: EventIdentity, ViewAREvent {
    let isOn: Bool
    init(_ isOn: Bool) { self.isOn = isOn }

    func call(_ context: ViewARContext) {
        context.setDxfOverlay(isOn: isOn)
    }
}
