//
//  TiffImage.swift
//  Quick3D
//
//  Created by Admin on 20/3/26.
//

import Foundation
import ImageIO
import CoreImage
import UniformTypeIdentifiers

protocol TiffImage {
    var colorSpace: CGColorSpace { get }
    
    var bitmapInfo: CGBitmapInfo { get }
    
    var options: CFDictionary { get }
    
    var bitsPerComponent: Int { get }
    
    func write(from pixelBuffer: CVPixelBuffer, to url: URL, imgId: String) throws
    
    func createMetadata(imgId: String) -> CGMutableImageMetadata
}

class TiffImageTemplate: TiffImage {
    
    var colorSpace: CGColorSpace {
        CGColorSpace(name: CGColorSpace.linearGray)!
    }
    
    var bitmapInfo: CGBitmapInfo {
        CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
    }
    
    var options: CFDictionary {
        [:] as CFDictionary
    }
    
    var bitsPerComponent: Int {
        8
    }
    
    let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df
    }()
    
    init(
        _ session: CaptureSession,
        fileName: String,
        data: CVPixelBuffer?,
        imgId: String,
    ) throws {
        guard let pixelBuffer = data else { return }

        let fileUrl = session.url.appendingPathComponent(fileName)
        
        try write(from: pixelBuffer, to: fileUrl, imgId: imgId)
    }
    
    func createCGImage(pixelBuffer: CVPixelBuffer) -> CGImage? {
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        let base = CVPixelBufferGetBaseAddress(pixelBuffer)!
        let dataSize = CVPixelBufferGetDataSize(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let provider = CGDataProvider(dataInfo: nil, data: base, size: dataSize, releaseData: { _, _, _ in }) else { return nil}

        let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
        
        return cgImage
    }
    
    func write(from pixelBuffer: CVPixelBuffer, to url: URL, imgId: String) throws {
        
        guard let cgImage = createCGImage(pixelBuffer: pixelBuffer) else {
            throw NSError(domain: "TiffImageTemplate", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create CGImage"])
        }
        
//        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.tiff.identifier as CFString, 1, nil) else {
//            throw NSError(domain: "TiffImageTemplate", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot create image destination"])
//        }
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.tiff.identifier as CFString, 1, nil) else {
            throw NSError(domain: "TiffImageTemplate", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot create image destination"])
        }
        
        let metadata = createMetadata(imgId: imgId)
        
        CGImageDestinationAddImageAndMetadata(destination, cgImage, metadata, options)
        
        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "TiffImageTemplate", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to write TIFF file"])
        }
        
        StorageManager.write(url, data: mutableData as Data)
    }
    
    func createMetadata(imgId: String) -> CGMutableImageMetadata {
        let metadata = CGImageMetadataCreateMutable()
        
        registerNamespace(metadata)
        
        setMetadata(metadata, XMP_CAMERA_CAPTURE_UUID as CFString, imgId as CFString)
        
        return metadata
    }
    
    func setMetadata(_ metadata: CGMutableImageMetadata, _ path: CFString, _ value: CFString) {
        CGImageMetadataSetValueWithPath(metadata, nil, path, value)
    }
    
    func setMetadata(_ metadata: CGMutableImageMetadata, _ path: String, _ value: String) {
        setMetadata(metadata, path as CFString, value as CFString)
    }
    
    func registerNamespace(_ metadata: CGMutableImageMetadata) {
        CGImageMetadataRegisterNamespaceForPrefix(metadata, CAMERA_NAMESPACE, XMP_CAMERA_PREFIX, nil)
    }
    
}
