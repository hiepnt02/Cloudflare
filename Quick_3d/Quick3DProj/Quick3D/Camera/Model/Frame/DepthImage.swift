//
//  DepthImage.swift
//  Quick3D
//
//  Created by HaNST on 15/11/24.
//

import Foundation
import ImageIO
import CoreImage
import UniformTypeIdentifiers
import UIKit

class DepthImage: TiffImageTemplate {

    private static let _colorSpace = CGColorSpace(name: CGColorSpace.linearGray)!
    
    private static let _bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.none.rawValue | CGBitmapInfo.floatComponents.rawValue)
    
    override var colorSpace: CGColorSpace {
        Self._colorSpace
    }
    
    override var bitmapInfo: CGBitmapInfo {
        Self._bitmapInfo
    }
    
    override var bitsPerComponent: Int {
        32
    }
    
    override var options: CFDictionary {
        [
           kCGImageDestinationLossyCompressionQuality: 1.0, // Max quality
           kCGImagePropertyTIFFDictionary: [
               kCGImagePropertyTIFFCompression: 1, // 1 = No Compression
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
        
        // Set các giá trị XMP
        // Lưu ý: Đảm bảo các constant XMP_... của bạn là đúng chuẩn Path
        setMetadata(metadata, XMP_MODEL as CFString, "Pix4Dcatch.\(UIDevice.current.identifier)" as CFString)
        setMetadata(metadata, XMP_MAKE as CFString, "Apple" as CFString)
        setMetadata(metadata, XMP_CAMERA_BRAND_NAME as CFString, "Depth" as CFString)
        setMetadata(metadata, XMP_CAMERA_DEPTH_UNIT as CFString, "m" as CFString)
        setMetadata(metadata, XMP_CAMERA_CAPTURE_UUID as CFString, imgId as CFString)
        
        setMetadata(metadata,XMP_DATE_TIME_ORIGINAL as CFString, dateString)
        setMetadata(metadata,XMP_PHOTOSHOP_CREATED_DATE as CFString, dateString)
        setMetadata(metadata,XMP_PHOTOSHOP_CREATED_DATE_TIME as CFString, dateString)
        
        setMetadata(metadata,XMP_ORIENTATION as CFString, "1" as CFString)
        setMetadata(metadata,XMP_PHOTOMETRIC_INTERPRETATION as CFString, "1" as CFString)
        setMetadata(metadata,XMP_COMPRESSION as CFString, "1" as CFString) // 1 = No compression
        setMetadata(metadata,XMP_RESOLUTION_UNIT as CFString, "2" as CFString) // 2 = Inch
        
        return metadata
    }
    
}
