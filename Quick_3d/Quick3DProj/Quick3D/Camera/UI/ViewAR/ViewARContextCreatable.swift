//
//  ViewARContextCreatable.swift
//  Quick3D
//
//  Created by HaNST on 14/7/26.
//

import Foundation

protocol ViewARContextCreatable: AnyObject, CameraContext where Delegate == ViewARDelegate, E == ViewAREvent {
    
    var calculateAccuracy: Double { get }
    
    var positionHistories: [PositionHistory] { get }
    
    var previewContext: ViewARPreviewContext? { set get }
    
    init()
}

extension ViewARContext: ViewARContextCreatable {}

@available(iOS 18.0, *)
extension RealityViewARContext: ViewARContextCreatable {}
