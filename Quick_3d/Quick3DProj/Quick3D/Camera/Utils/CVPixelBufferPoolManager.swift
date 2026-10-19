//
//  CVPixelBufferPoolManager.swift
//  Quick3D
//
//  Created by HaNST on 19/3/26.
//

import Foundation
import CoreVideo

class CVPixelBufferPoolManager {
    
    private static var pool: [String : CVPixelBufferPool] = [:]
    
    static func get(_ width: Int, _ height: Int, _ pixelFormatType: OSType) -> CVPixelBufferPool {
        let key = "\(width)-\(height)-\(pixelFormatType)"
        
        if let p = pool[key] {
            return p
        }
        
        let attrs: [CFString: Any] = [
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferPixelFormatTypeKey: pixelFormatType,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        
        var p: CVPixelBufferPool?

        CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &p)

        pool[key] = p!
        
        return p!
    }
    
}
