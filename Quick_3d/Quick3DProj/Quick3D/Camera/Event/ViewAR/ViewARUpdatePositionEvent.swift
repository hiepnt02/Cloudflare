//
//  ViewARUpdatePositionEvent.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import Foundation

class ViewARUpdatePositionEvent: EventIdentity, ViewAREvent {
    
    let position: SIMD3<Float>
    
    let eulerAngles: SIMD3<Float>
    
    let scale: Float
    
    init(_ position: SIMD3<Float>, _ eulerAngles: SIMD3<Float>, _ scale: Float) {
        self.position = position
        self.eulerAngles = eulerAngles
        self.scale = scale
    }
    
    func call(_ context: ViewARContext) {
        context.updateARPosition(position: position, eulerAngles: eulerAngles, scale: scale)
    }
}
