//
//  ImageCompressionProcessor.swift
//  Quick3D
//
//  Created by HaNST on 20/3/26.
//

import Foundation
import VideoToolbox

enum CompressionType {
    case jpeg
    case tiff
}

class CompressionInfo {
    let path: URL
    
    init(path: URL) {
        self.path = path
    }
}

class ImageCompressionProcessor {
    
    public static let current = ImageCompressionProcessor()
    
    private var sessions: [String : VTCompressionSession] = [:]
    
    private let lock = NSLock()
    
    private let callback: VTCompressionOutputCallback = { (
        outputCallbackRefCon,
        sourceFrameRefCon,
        status,
        infoFlags,
        sampleBuffer
    ) in
        guard let sampleBuffer = sampleBuffer,
              let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer),
              let sourceFrameRefCon = sourceFrameRefCon
        else { return }

        let info = Unmanaged<CompressionInfo>
                .fromOpaque(sourceFrameRefCon)
                .takeRetainedValue()
        
        var length: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?

        CMBlockBufferGetDataPointer(
            dataBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )

        let data = Data(bytes: dataPointer!, count: length)
        StorageManager.write(info.path, data: data)
    }

    func clearAll() {
        sessions.forEach { key, session in
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
        }
        sessions.removeAll()
    }
    
    func getSession(_ type: CompressionType, width: Int, height: Int) -> VTCompressionSession {
        lock.lock()
        
        defer {
            lock.unlock()
        }
        
        let key = "\(type)-\(width)-\(height)"
        
        if let session = sessions[key] {
            return session
        }
        
        var session: VTCompressionSession?

        VTCompressionSessionCreate(
            allocator: nil,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_JPEG,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: callback,
            refcon: nil,
            compressionSessionOut: &session
        )
        
        VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_Quality, value: 0.9 as CFTypeRef)
        
        sessions[key] = session!
        
        return session!
    }
    
    static func addFrame(_ path: URL, data: CVPixelBuffer) throws {
        try autoreleasepool {
            let width = CVPixelBufferGetWidth(data)
            let height = CVPixelBufferGetHeight(data)
            let session = Self.current.getSession(.jpeg, width: width, height: height)
            let status = VTCompressionSessionEncodeFrame(
                session,
                imageBuffer: data,
                presentationTimeStamp: .zero,
                duration: .invalid,
                frameProperties: nil,
                sourceFrameRefcon: UnsafeMutableRawPointer(Unmanaged.passRetained(CompressionInfo(path: path)).toOpaque()),
                infoFlagsOut: nil
            )
            if status != noErr {
                throw NSError(domain: "JpegImage", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to write JPEG file - status \(status)"])
            }
        }
    }
}
