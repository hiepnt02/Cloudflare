//
//  CaptureDelegate.swift
//  Quick3D
//
//  Created by HaNST on 16/3/26.
//

import Foundation

protocol CaptureDelegate {
    
    func capture(_ session: CaptureSession?, didCapture count: Int)
    
    func capture(_ session: CaptureSession?, exportProgress progress: Double)
    
    func capture(_ session: CaptureSession?, didExport url: URL)
    
    func capture(_ session: CaptureSession?, didChange status: ARStatus)
    
    func capture(_ session: CaptureSession?, error: Error, action: (() -> Void)?)
    
    func capture(_ session: CaptureSession?, didCalculateOverlap ratio: Float, zDistance: Float)
 
    func capture(_ session: CaptureSession?, didStart isReady: Bool)
    
}
