//
//  ViewARAllowCalculateEvent.swift
//  Quick3D
//
//  Created by HaNST on 02/02/26.
//

import Foundation

class ViewARAllowCalculateEvent: EventIdentity, ViewAREvent {

    let isAllow: Bool
    
    init(_ isAllow: Bool) {
        self.isAllow = isAllow
    }
    
    func call(_ context: ViewARContext) {
        context.isAllowARUpdatePosition = isAllow
    }
    
}
