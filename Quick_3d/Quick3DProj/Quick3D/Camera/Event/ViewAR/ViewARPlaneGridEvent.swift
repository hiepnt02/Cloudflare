//
//  ViewARPlaneGridEvent.swift
//  Quick3D
//

import Foundation

class ViewARPlaneGridEvent: EventIdentity, ViewAREvent {
    let isOn: Bool
    init(_ isOn: Bool) { self.isOn = isOn }
    
    func call(_ context: ViewARContext) {
        context.togglePlaneGrid(isEnabled: isOn)
    }
}
