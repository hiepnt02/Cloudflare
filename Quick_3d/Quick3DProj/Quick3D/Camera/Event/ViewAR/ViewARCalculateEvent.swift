//
//  ViewARCalculateEvent.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import Foundation

class ViewARCalculateEvent: EventIdentity, ViewAREvent {
    
    func call(_ context: ViewARContext) {
        context.arUpdatePosition = true
    }
}
