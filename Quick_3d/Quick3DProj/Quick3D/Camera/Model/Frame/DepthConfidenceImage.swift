//
//  DepthConfidenceImage.swift
//  Quick3D
//
//  Created by HungNT on 25/11/25.
//

import Foundation
import ImageIO
import CoreImage
import UniformTypeIdentifiers
import UIKit

class DepthConfidenceImage: TiffImageTemplate {
    
    // Define Custom Errors
    enum DepthError: Error {
        case missingData
        case cannotCreateDestination
        case cannotCreateImage
        case saveFailed
    }

    private static let _colorSpace = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!
    
    private static let _bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
    
    override var colorSpace: CGColorSpace {
        Self._colorSpace
    }
    
    override var bitmapInfo: CGBitmapInfo {
        Self._bitmapInfo
    }
    
    override var bitsPerComponent: Int {
        8
    }
    
    override var options: CFDictionary {
        [
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFCompression as String: 5,
                kCGImagePropertyTIFFOrientation: 1,
                kCGImagePropertyTIFFPhotometricInterpretation as String: 1, // BlackIsZero
                kCGImagePropertyTIFFResolutionUnit as String: 2,
                kCGImageDestinationLossyCompressionQuality as String: 1.0,
            ]
        ] as CFDictionary
    }
    
    override func createMetadata(imgId: String) -> CGMutableImageMetadata {
        let metadata = CGImageMetadataCreateMutable()
        
        // Đăng ký Namespace (Giả sử các hằng số này bạn đã có global)
        // Lưu ý: Nếu namespace chưa có, bạn cần định nghĩa lại hoặc bỏ qua nếu ImageIO tự handle
        registerNamespace(metadata)
        
        let dateString = dateFormatter.string(from: Date()) as CFString
        
        // Pix4D / Camera Specific
        setMetadata(metadata, XMP_MODEL, "Pix4Dcatch.\(UIDevice.current.identifier)")
        setMetadata(metadata, XMP_MAKE, "Apple")
        setMetadata(metadata, XMP_CAMERA_BRAND_NAME, "DepthConfidence")
        setMetadata(metadata, XMP_CAMERA_DEPTH_CONFIDENCE_RANGE_MIN, "0")
        setMetadata(metadata, XMP_CAMERA_DEPTH_CONFIDENCE_RANGE_MAX, "2")
        setMetadata(metadata, XMP_CAMERA_DEPTH_CONFIDENCE_UNIT, "int")
        setMetadata(metadata, XMP_CAMERA_CAPTURE_UUID, imgId)
        
        // Date Times
        setMetadata(metadata, XMP_DATE_TIME_ORIGINAL, dateString as String)
        setMetadata(metadata, XMP_PHOTOSHOP_CREATED_DATE, dateString as String)
        setMetadata(metadata, XMP_PHOTOSHOP_CREATED_DATE_TIME, dateString as String)
        
        // Technical Specs
        setMetadata(metadata, XMP_ORIENTATION, "1")
        setMetadata(metadata, XMP_PHOTOMETRIC_INTERPRETATION, "1")
        setMetadata(metadata, XMP_COMPRESSION, "5")
        setMetadata(metadata, XMP_RESOLUTION_UNIT, "2")
        
        return metadata
    }
    
}
