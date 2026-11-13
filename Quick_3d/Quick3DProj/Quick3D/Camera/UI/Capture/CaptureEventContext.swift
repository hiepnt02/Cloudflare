//
//  CaptureEventContext.swift
//  Quick3D
//
//  Created by HaNST on 1/7/26.
//

import Foundation

protocol CaptureEventContext {
    
    var delegate: CaptureDelegate? { get }
    
    var status: ARStatus { get }
    
    func changeStatus(_ status: ARStatus)
    
    func handleAsync(error: Error, action: (() -> Void)?)
    
    func handleAsync(error: Error)
    
    func preCapture()
    
    func waitUntilCompleted()
    
    func start()
    
    func restart()
    
    func discard()
    
    func combine() throws
    
    func applySettings()
}
