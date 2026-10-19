//
//  CatchLog.swift
//  Quick3D
//
//  Refactored for performance and type safety.
//

import Foundation
import SwiftUI
import ARKit

// MARK: - Models

struct CatchLogInfo: Codable {
    let appVersion: String
    var arType: String = "ARKit"
    var branch: String = "AR-5610-release-2-1-1"
    var commit: String = "b1df0d7bb"
    let deviceModel: String
    var logVersion: String = "3.14.0"
    var os: String = "iOS"
    let osVersion: String
    let time: Double
    
    init() {
        self.appVersion = CatchLog.pix4DAppVersion
        self.deviceModel = UIDevice.modelName
        self.osVersion = UIDevice.current.systemVersion
        self.time = CatchLog.currentTimeStamp()
    }
}

struct ViewSettings: Codable {
    let cameraObjects: Bool
    let depthPoints: ViewSettingsDepthPoints
    let featurePoints: Bool
    let mesh: ViewSettingsMesh
    let time: Double
}

struct ViewSettingsDepthPoints: Codable {
    let enabled: Bool
    let pointsPerFrame: Int
}

struct ViewSettingsMesh: Codable {
    let enabled: Bool
    let wireframe: Bool
}

struct GPSOriginUpdate: Codable {
    let altitude: Double
    let latitude: Double
    let longitude: Double
    let time: Double
    let x: Float
    let y: Float
    let z: Float
}

struct GPSConfiguration: Codable {
    let activeConstellations: [String]
    let antennaOffset: GPSConfigurationAntennaOffset
    let isRTK: Bool
    let minimumElevationAngle: Int
    let source: String
    let supportType: String
}

struct GPSConfigurationAntennaOffset: Codable {
    let x: Double
    let y: Double
    let z: Double
}

struct TriggerSettings: Codable {
    let angle: Float
    let distance: Float
    let imageResolution: String
    let overlap: Double
    let time: Double
    let type: String
}

struct PhotoTaken: Codable {
    let fps: Double
    let gps: PhotoGPS
    let imageName: String
    let imageQuality: ImageQuality
    let intrinsicMatrix: [Float]
    let rotation: PhotoRotation
    let time: Double
    let transformMatrix: [Float]
}

struct PhotoGPS: Codable {
    let altitude: Double
    let latitude: Double
    let longitude: Double
    
    init(_ location: LocationModel) {
        self.altitude = location.altitude
        self.latitude = location.latitude
        self.longitude = location.longitude
    }
}

struct PhotoRotation: Codable {
    let yaw: Double
    let pitch: Double
    let roll: Double
    
    init(_ model: EulerAnglesModel) {
        self.yaw = model.yaw
        self.pitch = model.pitch
        self.roll = model.roll
    }
    
    init(_ model: EulerAngles) {
        self.yaw = model.yaw.degrees
        self.pitch = model.pitch.degrees
        self.roll = model.roll.degrees
    }
}

struct ImageQuality: Codable {
    let exposureDuration: Double
    let exposureOffset: Float
    let grainIntensity: Float
    let medianPixelMovement: Int
}

struct PhotoUpdated: Codable {
    let gps: PhotoGPS
    let imageName: String
    let rotation: PhotoRotation
    let time: Double
    let transformMatrix: [Float]
}

// MARK: - Logger Class

class CatchLog {
    
    // MARK: - Constants & Static
    static let pix4DAppVersion = "2.4.1 (1256)"
    
    static func currentTimeStamp() -> Double {
        // Sử dụng timeIntervalSince1970 trực tiếp
        return (Date().timeIntervalSince1970 * 10_000_000).rounded() / 10_000_000
    }
    
    // MARK: - Properties
    private let fileUrl: URL
    private var buffer: [String] = []
    private let maxRow = 1000
    
    private var isStart = false
    private var previousIsRTK: Bool? = nil
    
    var onError: ((Error) -> Void)? = nil
    
    private let lock = NSLock()
    
    // Tái sử dụng Encoder để tăng hiệu năng
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return e
    }()
    
    init(_ fileUrl: URL) {
        self.fileUrl = fileUrl
        // Đảm bảo thư mục tồn tại
        try? FileManager.default.createDirectory(at: fileUrl.deletingLastPathComponent(), withIntermediateDirectories: true)
    }
    
    // MARK: - Public Methods
    
    func startCapture(_ frame: FrameMetadata) {
        let currentIsRTK = frame.location.isRTK
        
        if isStart {
            // Chỉ log nếu trạng thái RTK chuyển từ false -> true
            if let prev = previousIsRTK, !prev, currentIsRTK {
                previousIsRTK = true
                storeGPSConfiguration(frame: frame)
            }
            return
        }
        
        isStart = true
        previousIsRTK = currentIsRTK
        
        // Log trình tự khởi tạo
        appendInfo()
        appendViewSettings()
        storeGPSConfiguration(frame: frame)
        
        logEvent("startCapture", body: ["time": CatchLog.currentTimeStamp()])
        
        let triggerSettings = TriggerSettings(
            angle: frame.angle,
            distance: frame.distance,
            imageResolution: "\(frame.width)x\(frame.height)",
            overlap: UserSession.shared.overlapValue,
            time: CatchLog.currentTimeStamp(),
            type: "overlap"
        )
        logEvent("triggerSettings", body: triggerSettings)
    }
    
    func projectSaveFinalised() {
        logEvent("projectSaveFinalised", body: ["time": CatchLog.currentTimeStamp()])
        write() // Force write khi save
    }
    
    func appendNtripInfo(mountpoint: String, serviceProvider: String) {
        logEvent("ntripInfo", body: [
            "mountpoint": mountpoint,
            "serviceProvider": serviceProvider
        ])
    }
    
    func appendRTKDeviceInfo(hardware: String, software: String) {
        logEvent("rtkDeviceInfo", body: [
            "hardware": hardware,
            "software": software
        ])
    }
    
    func appendPhotoTaken(imageName: String, info: FrameMetadata, eulerAngles: EulerAnglesModel) {
        let imageQuality = ImageQuality(
            exposureDuration: info.exposureDuration,
            exposureOffset: info.exposureOffset,
            grainIntensity: info.grainIntensity,
            medianPixelMovement: 0
        )
        
        let photoData = PhotoTaken(
            fps: info.fps,
            gps: PhotoGPS(info.location),
            imageName: imageName,
            imageQuality: imageQuality,
            intrinsicMatrix: info.intrinsics.array,
            rotation: PhotoRotation(eulerAngles),
            time: CatchLog.currentTimeStamp(),
            transformMatrix: info.transform.array
        )
        
        logEvent("photoTaken", body: photoData)
    }
    
    func appendPhotoUpdated(imageName: String, transform: simd_float4x4, gps: LocationModel, eulerAngles: EulerAngles) {
        let updatedData = PhotoUpdated(
            gps: PhotoGPS(gps),
            imageName: imageName,
            rotation: PhotoRotation(eulerAngles),
            time: CatchLog.currentTimeStamp(),
            transformMatrix: transform.array
        )
        logEvent("photoUpdated", body: updatedData)
    }
    
    // MARK: - Private Logic
    
    private func appendViewSettings() {
        let settings = ViewSettings(
            cameraObjects: false,
            depthPoints: ViewSettingsDepthPoints(enabled: false, pointsPerFrame: 7680),
            featurePoints: false,
            mesh: ViewSettingsMesh(enabled: true, wireframe: true),
            time: CatchLog.currentTimeStamp()
        )
        logEvent("viewSettings", body: settings)
    }
    
    private func appendInfo() {
        logEvent("init", body: CatchLogInfo())
    }
    
    private func storeGPSConfiguration(frame: FrameMetadata) {
        // Log Origin Update
        let gpsUpdate = GPSOriginUpdate(
            altitude: frame.location.altitude,
            latitude: frame.location.latitude,
            longitude: frame.location.longitude,
            time: CatchLog.currentTimeStamp(),
            x: frame.position.x,
            y: frame.position.y,
            z: frame.position.z
        )
        logEvent("gpsOriginUpdate", body: gpsUpdate)
        
        // Log GPS Config
        let caseType = UserSession.shared.cameraOffsetSegment.rawValue.lowercased()
        let antennaOffset = RTKManager.shared.mapToAntennaOffset()
        let isRTK = frame.location.isRTK
        
        let config: GPSConfiguration
        if isRTK {
            config = GPSConfiguration(
                activeConstellations: ["GPS","Galileo","SBAS","QZSS","Glonass","Beidou"],
                antennaOffset: GPSConfigurationAntennaOffset(x: antennaOffset.x, y: antennaOffset.y, z: antennaOffset.z),
                isRTK: true,
                minimumElevationAngle: 10,
                source: "viDoc",
                supportType: caseType
            )
        } else {
            config = GPSConfiguration(
                activeConstellations: ["UNKNOWN"],
                antennaOffset: GPSConfigurationAntennaOffset(x: 0, y: 0, z: 0),
                isRTK: false,
                minimumElevationAngle: 0,
                source: "unknown",
                supportType: "none"
            )
        }
        logEvent("gpsConfiguration", body: config)
    }
    
    // Helper để bọc Key-Value JSON
    private func logEvent<T: Codable>(_ key: String, body: T) {
        // Wrap object vào dynamic dictionary để encode
        // Sử dụng Dictionary wrapper tránh việc tạo [String: Any] thủ công
        let wrapper = [key: body]
        appendJson(wrapper)
    }
    
    private func appendJson<T: Codable>(_ data: T) {
        lock.lock()
        defer {
            lock.unlock()
        }
        do {
            let jsonData = try self.encoder.encode(data)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                self.buffer.append(jsonString)
                
                if self.buffer.count >= self.maxRow {
                    self.flushBufferToFile()
                }
            }
        } catch {
            print("JSON Encoding Error: \(error)")
        }
    }
    
    private func flushBufferToFile() {
        guard !buffer.isEmpty else { return }
        let textToWrite = buffer.joined(separator: "\n") + "\n" // Đảm bảo luôn có newline cuối cùng
        buffer.removeAll(keepingCapacity: true) // Giữ capacity để tối ưu bộ nhớ
        StorageManager.write(fileUrl, text: textToWrite, canAppend: true)
    }
    
    // MARK: - Public Control
    
    func write() {
        lock.lock()
        defer {
            lock.unlock()
        }
        flushBufferToFile()
    }
}
