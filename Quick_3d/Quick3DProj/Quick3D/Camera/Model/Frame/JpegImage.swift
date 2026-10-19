//
//  JpegImage.swift
//  Quick3D
//
//  Created by HaNST on 15/11/24.
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI
import ImageIO
import MachO
import VideoToolbox

final class JpegImage {
    
    public private(set) var fileURL: URL
    private var latitude: Double = 0.0
    private var longitude: Double = 0.0
    private var isRTK = false
    
    init(
        _ session: CaptureSession,
        fileName: String,
        data: CVPixelBuffer,
        imgId: String
    ) throws {
        fileURL = session.url.appendingPathComponent(fileName)
        try ImageCompressionProcessor.addFrame(fileURL, data: data)
    }
}
