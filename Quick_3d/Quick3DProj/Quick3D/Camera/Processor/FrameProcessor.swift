//
//  FrameProcessor.swift
//  Quick3D
//
//  Created by HaNST on 3/2/26.
//

import Foundation

protocol FrameProcessor {
    
    var isLimited: Bool { get }
    
    func process(_ session: CaptureSession,  frame: FrameData, onCompleted: (() -> Void)?, onError: ((Error) -> Void)?)
    
    func waitUntilCompleted()
    
    func cancel()
}

extension FrameProcessor {
    var maxQueueSize: Int { 10 }
}
