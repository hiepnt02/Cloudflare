//
//  CVPixelBuffer++.swift
//  Quick3D
//
//  Created by HungNT on 8/12/25.
//

import ARKit

extension CVPixelBuffer {
    
    func deepCopy() -> CVPixelBuffer? {
        
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let format = CVPixelBufferGetPixelFormatType(self)
        
        var pixelBufferCopy: CVPixelBuffer?
        
        let pool = CVPixelBufferPoolManager.get(width, height, format)
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBufferCopy)
        
        guard status == kCVReturnSuccess, let copy = pixelBufferCopy else { return nil }
        
        // Copy các thông tin đi kèm (Color space, ARKit metadata)
        CVBufferPropagateAttachments(self, copy)
        
        CVPixelBufferLockBaseAddress(self, .readOnly)
        CVPixelBufferLockBaseAddress(copy, [])
        
        defer {
            CVPixelBufferUnlockBaseAddress(copy, [])
            CVPixelBufferUnlockBaseAddress(self, .readOnly)
        }
        
        if CVPixelBufferIsPlanar(self) {
            let planeCount = CVPixelBufferGetPlaneCount(self)
            for i in 0..<planeCount {
                let destBaseAddr = CVPixelBufferGetBaseAddressOfPlane(copy, i)
                let sourceBaseAddr = CVPixelBufferGetBaseAddressOfPlane(self, i)
                let heightPlane = CVPixelBufferGetHeightOfPlane(self, i)
                let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(self, i)
                
                if let src = sourceBaseAddr, let dst = destBaseAddr {
                    memcpy(dst, src, bytesPerRow * heightPlane)
                }
            }
        } else {
            let destBaseAddr = CVPixelBufferGetBaseAddress(copy)
            let sourceBaseAddr = CVPixelBufferGetBaseAddress(self)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
            
            if let src = sourceBaseAddr, let dst = destBaseAddr {
                memcpy(dst, src, bytesPerRow * height)
            }
        }
        
        return copy
    }
}
