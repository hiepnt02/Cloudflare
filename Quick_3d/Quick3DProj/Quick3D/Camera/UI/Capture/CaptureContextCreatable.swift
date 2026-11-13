//
//  CaptureContextCreatable.swift
//  Quick3D
//
//  Created by HaNST on 6/7/26.
//

import Foundation

protocol CaptureContextCreatable: AnyObject, CameraContext, CaptureEventContext where Delegate == CaptureDelegate, E == any Event {
    init()
}

extension CaptureContext: CaptureContextCreatable {}

@available(iOS 18.0, *)
extension ARCaptureContext: CaptureContextCreatable {}
