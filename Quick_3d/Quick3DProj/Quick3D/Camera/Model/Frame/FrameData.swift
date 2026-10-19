//
//  FrameData.swift
//  Quick3D
//
//  Created by HaNST on 1/10/25.
//

import Foundation
import ARKit
import simd
import Metal

protocol FrameCalculationData {
    var transform: simd_float4x4 { get }
    
    var projection: simd_float4x4 { get }
    
    var intrinsics: simd_float3x3 { get }
    
    var eulerAngles: simd_float3 { get }
    
    var imageResolution: CGSize { get }
    
    var depthMap: CVPixelBuffer? { get }
    
    var confidenceMap: CVPixelBuffer? { get }
}

extension FrameCalculationData {
    func fieldOfView(for imageResolution: CGSize) -> (horizontal: Float, vertical: Float) {
        let intrinsics = self.intrinsics

        // fx, fy là độ dài tiêu cự tính bằng pixel
        let fx = intrinsics[0, 0]
        let fy = intrinsics[1, 1]

        // imageResolution.width, imageResolution.height là kích thước ảnh (pixel)
        let imageWidth = Float(imageResolution.width)
        let imageHeight = Float(imageResolution.height)

        // Tính FOV ngang và dọc
        let horizontalFOV = 2 * atan(imageWidth / (2 * fx))
        let verticalFOV = 2 * atan(imageHeight / (2 * fy))

        return (horizontal: horizontalFOV, vertical: verticalFOV)
    }
}

extension ARFrame: FrameCalculationData {
    var transform: simd_float4x4 {
        camera.transform
    }
    
    var projection: simd_float4x4 {
        camera.projectionMatrix
    }
    
    var intrinsics: simd_float3x3 {
        camera.intrinsics
    }
    
    var eulerAngles: simd_float3 {
        camera.eulerAngles
    }
    
    var imageResolution: CGSize {
        camera.imageResolution
    }
    
    var depthMap: CVPixelBuffer? {
        sceneDepth?.depthMap
    }
    
    var confidenceMap: CVPixelBuffer? {
        sceneDepth?.confidenceMap
    }
}

class FrameMetadata {
    let id: String = String.randomHexNumber(length: 16)
    let index: Int
    let timestamp: Date
    // Sử dụng bộ lưu trữ dạng value type cho các ma trận
    let transform: simd_float4x4
    let projection: simd_float4x4
    let intrinsics: simd_float3x3
    let eulerAngles: simd_float3
    
    let exif: [String: Any]
    let imageResolution: CGSize
    let width: Double
    let height: Double
    let exposureDuration: TimeInterval
    let exposureOffset: Float
    let grainIntensity: Float
    
    let gpsLocation: LocationModel
    var rtkLocation: LocationModel?
    let rtkId: String?
    let rtkSerialNumber: String?
    
    let viewMatrix: simd_float4x4
    let projectionMatrix: simd_float4x4
    let rotateMatrix: simd_float4x4
    
    let fps: Double
    let distance: Float = 1.0
    let angle: Float = 20
    
    // Computed properties giữ nguyên logic
    var location: LocationModel { rtkLocation ?? gpsLocation }
    var isRTK: Bool { location.isRTK }
    var position: simd_float3 { transform.columns.3.xyz } // Sử dụng swizzling nhanh hơn

    // Copy initializer tối ưu
    init(_ data: FrameMetadata, index: Int = 0) {
        self.index = index == 0 ? data.index : index
        self.timestamp = data.timestamp
        self.projection = data.projection
        self.transform = data.transform
        self.intrinsics = data.intrinsics
        self.eulerAngles = data.eulerAngles
        self.imageResolution = data.imageResolution
        self.width = data.width
        self.height = data.height
        self.exposureDuration = data.exposureDuration
        self.exposureOffset = data.exposureOffset
        self.grainIntensity = data.grainIntensity
        self.exif = data.exif
        self.gpsLocation = data.gpsLocation
        self.rtkLocation = data.rtkLocation
        self.rtkId = data.rtkId
        self.rtkSerialNumber = data.rtkSerialNumber
        self.rotateMatrix = data.rotateMatrix
        self.viewMatrix = data.viewMatrix
        self.projectionMatrix = data.projectionMatrix
        self.fps = data.fps
    }
    
    init(_ frame: ARFrame, index: Int, fps: Double = 0) {
        self.index = index
        self.timestamp = frame.time
        let camera = frame.camera
        
        // Cache camera properties để tránh truy cập nhiều lần vào bridge C++/Swift
        self.projection = camera.projectionMatrix
        self.transform = camera.transform
        self.intrinsics = camera.intrinsics
        self.eulerAngles = camera.eulerAngles
        self.imageResolution = camera.imageResolution
        self.width = Double(camera.imageResolution.width)
        self.height = Double(camera.imageResolution.height)
        self.exposureDuration = camera.exposureDuration
        self.exposureOffset = camera.exposureOffset
        self.grainIntensity = frame.cameraGrainIntensity
        
        if #available(iOS 16.0, *) {
            self.exif = frame.exifData
        } else {
            self.exif = [:]
        }
        
        // Singleton access
        let locManager = LocationManager.shared
        
        self.gpsLocation = locManager.gpsLocation
        self.rtkLocation = locManager.rtkLocation
        self.rtkId = locManager.rtkId
        self.rtkSerialNumber = locManager.rtkSerialNumber
        
        let orientation: UIInterfaceOrientation = AppDelegate.orientationLock == .portrait ? .portrait : .landscapeRight
        
        self.rotateMatrix = Self.makeRotateToARCameraMatrix(orientation: orientation)
        self.viewMatrix = camera.viewMatrix(for: orientation)
        self.projectionMatrix = camera.projectionMatrix(for: orientation, viewportSize: .zero, zNear: 0.001, zFar: 0)
        
        self.fps = fps
    }

    static func makeRotateToARCameraMatrix(orientation: UIInterfaceOrientation) -> simd_float4x4 {
        let flipYZ = simd_float4x4(
            [1, 0, 0, 0],
            [0, -1, 0, 0],
            [0, 0, -1, 0],
            [0, 0, 0, 1])
        let rotationAngle = Float(cameraToDisplayRotation(orientation: orientation)) * .pi / 180
        return flipYZ * simd_float4x4(simd_quaternion(rotationAngle, SIMD3<Float>(0, 0, 1)))
    }
    
    static func cameraToDisplayRotation(orientation: UIInterfaceOrientation) -> Int {
        switch orientation {
        case .landscapeLeft: return 180
        case .portrait: return 90
        case .portraitUpsideDown: return -90
        default: return 0
        }
    }
}

// Sử dụng bộ nhớ đệm (Cache) cho texture RGB để tránh leak RAM khi truy cập nhiều lần
class FrameData: FrameMetadata {
    let capturedImage: CVPixelBuffer
    let depthMap: CVPixelBuffer
    let confidenceMap: CVPixelBuffer
    
//    init(frame: ARFrame, fps: Int = 0) throws {
//        
//        guard let depthMap = frame.sceneDepth?.depthMap,
//              let confidenceMap = frame.sceneDepth?.confidenceMap else {
//            throw NSError(domain: "FrameData", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create pixel buffers for frame"])
//        }
//        
//        self.capturedImage = frame.capturedImage
//        self.depthMap = depthMap
//        self.confidenceMap = confidenceMap
//        
//        super.init(frame, index: 0, fps: fps)
//    }
    
    init(frame: ARFrame, index: Int, fps: Double = 0) throws {
        
        guard let capturedImage = frame.capturedImage.deepCopy(),
              let depthMap = frame.sceneDepth?.depthMap.deepCopy(),
              let confidenceMap = frame.sceneDepth?.confidenceMap?.deepCopy() else {
            throw NSError(domain: "FrameData", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create pixel buffers for frame"])
        }

        self.capturedImage = capturedImage
        self.depthMap = depthMap
        self.confidenceMap = confidenceMap

        super.init(frame, index: index, fps: fps)
    }

}

// Helper để lấy xyz từ matrix nhanh hơn
extension simd_float4 {
    var xyz: simd_float3 {
        return simd_float3(x, y, z)
    }
}

extension FrameMetadata {
    var imageName: String {
        String(format: "Image_%06d.jpg", index)
    }
    
    var imageNameWithoutExtension: String {
        String(format: "Image_%06d", index)
    }
    
    var depthMapImageName: String {
        String(format: "DepthMap_%06d.tiff", index)
    }
    
    var confidenceMapImageName: String {
        String(format: "Confidence_%06d.tiff", index)
    }
}
