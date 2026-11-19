//
//  CaptureSession.swift
//  Quick3D
//
//  Created by HaNST on 16/10/25.
//

import Foundation
import ARKit
import ZIPFoundation
import SceneKit

// MARK: - Helpers & Static Formatters
fileprivate func getCameraDirectory() throws -> URL {
    let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let directoryUrl = documentDirectory.appendingPathComponent("Camera")
    if !FileManager.default.fileExists(atPath: directoryUrl.path) {
        try FileManager.default.createDirectory(at: directoryUrl, withIntermediateDirectories: true, attributes: nil)
    }
    return directoryUrl
}

fileprivate let SESSION_FOLDER_NAME = "_session"

// Tối ưu CPU: Tránh tạo DateFormatter liên tục (ngốn CPU rất lớn)
fileprivate enum SharedFormatter {
    static let sessionDate: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        df.timeZone = TimeZone(identifier: "UTC")
        return df
    }()
}

// MARK: - Capture Session
class CaptureSession {
    
    static var current: CaptureSession?
    
    static func start(_ isRTK: Bool = false,
                      pointCloudsSettings: (spacing: Int, pointSize: Int) = (20, 4),
                      isSaveMesh: Bool = true,
                      onFileError: ((Error) -> Void)? = nil) throws {
        if let session = current {
            session.clear()
        }
        let session = try CaptureSession(isRTK, pointCloudsSettings: pointCloudsSettings, isSaveMesh: isSaveMesh, onFileError: onFileError)
        session.imageResolution = UserSession.shared.imageResolution
        session.overlapRate = UserSession.shared.overlapValue
        session.ratioRate = UserSession.shared.ratioValue
        session.maxSmoothingFrames = UserSession.shared.smoothValue
        session.pointClouds.session = session
        session.cameras.session = session
        current = session
        RTKManager.shared.id = String.randomHexNumber(length: 64)
        AccurateClock.shared.reset()

        session.sessionLogger.logOperation("cameraStarted", [
            "isRTK": isRTK,
            "imageResolution": "\(session.imageResolution)",
            "overlapRate": session.overlapRate,
            "isSaveMesh": isSaveMesh
        ])
    }
    
    static func stop() {
        current?.clear()
        current = nil
    }
    
    static func clear() {
        guard let url = try? getCameraDirectory().appendingPathComponent(SESSION_FOLDER_NAME) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    static var isSessionError: Bool {
        guard let url = try? getCameraDirectory().appendingPathComponent(SESSION_FOLDER_NAME) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    // MARK: Properties
    let id = UUID()
    var name: String
    let url: URL
    var tempUrl: URL?
    let isRTK: Bool
    var hasConnectedToRTK: Bool = false
    let isSaveMesh: Bool
    
    private var _locationLogger: LocationLogger?
    private var _gpsLogger: CSVLogger?
    private var _rtkLogger: RTKLogger?
    private var _catchLogger: CatchLog?
    private var _sessionLogger: SessionLogger?
    private var _pointGLTFWriter: GLTFWriter?
    private var _meshGLTFWriter: GLTFWriter?
    
    private let _meshReader: MeshReader = .init()
    let onFileError: ((Error) -> Void)?
    
    var isProcessing: Bool = false
    var imageResolution: ImageResolutionEnum = .normal
    var overlapRate = 0.8
    var ratioRate = 0.9
    var maxSmoothingFrames = 5
    
    let pointClouds: MetalPointClouds
    let cameras: MetalCameras
    
    var livePreviewContext: CapturePreviewContext?
    
    var frames: [FrameMetadata] = []
    var metas: [JpegMetadataCache] = []

    private(set) var correctedRoot: LocationModel?
    private(set) var correctedLocations: [ImageLocation] = []

    func setCorrectedLocations(root: LocationModel, locations: [ImageLocation]) {
        correctedRoot = root
        correctedLocations = locations
    }

    private let lock = NSLock()
    
    // MARK: Getters for Loggers
    var locationLogger: LocationLogger {
        if _locationLogger == nil { _locationLogger = LocationLogger(self) }
        return _locationLogger!
    }
    
    var gpsLogger: CSVLogger {
        if _gpsLogger == nil {
            _gpsLogger = CSVLogger(["Timestamp","GPSLatitude","GPSLongitude","GPSAltitude","HorizontalAccuracy","VerticalAccuracy","Course","CourseAccuracy"], fileUrl: self.url.appendingPathComponent("gps_positions.csv"))
            _gpsLogger?.onError = { [weak self] error in
                self?.sessionLogger.logProcessing("gps", "writeError", level: .error, ["error": "\(error)"])
                self?.onFileError?(error)
            }
        }
        return _gpsLogger!
    }

    var rtkLogger: RTKLogger? {
        if _rtkLogger == nil {
            _rtkLogger = RTKLogger(self)
            _rtkLogger?.onError = { [weak self] error in
                self?.sessionLogger.logProcessing("rtk", "writeError", level: .error, ["error": "\(error)"])
                self?.onFileError?(error)
            }
        }
        return _rtkLogger
    }

    var catchLogger: CatchLog {
        if _catchLogger == nil {
            _catchLogger = CatchLog(url.appendingPathComponent("catchLog.ndjson"))
            _catchLogger?.onError = { [weak self] error in
                self?.sessionLogger.logProcessing("storage", "catchLogWriteError", level: .error, ["error": "\(error)"])
                self?.onFileError?(error)
            }
        }
        return _catchLogger!
    }

    var sessionLogger: SessionLogger {
        if _sessionLogger == nil {
            _sessionLogger = SessionLogger(
                operationURL: url.appendingPathComponent("logs/operation.log"),
                processingURL: url.appendingPathComponent("logs/processing.log"),
                isEnabled: UserSession.shared.isEnableLog
            )
        }
        return _sessionLogger!
    }
    
    var pointGLTFWriter: GLTFWriter {
        if _pointGLTFWriter == nil {
            _pointGLTFWriter = .init(url, name: "pointcloud", mode: 0, includeRGB: true)
            _pointGLTFWriter?.onError = onFileError
        }
        return _pointGLTFWriter!
    }
    
    var meshGLTFWriter: GLTFWriter {
        if _meshGLTFWriter == nil {
            let folderName = "\(SharedFormatter.sessionDate.string(from: Date()))_mesh"
            let folder = url.appendingPathComponent(folderName)
            if !FileManager.default.fileExists(atPath: folder.path) {
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
            }
            _meshGLTFWriter = .init(folder, name: "mesh", mode: 4, includeRGB: false)
            _meshGLTFWriter?.onError = onFileError
        }
        return _meshGLTFWriter!
    }
    
    init(_ isRTK: Bool,
         pointCloudsSettings: (spacing: Int, pointSize: Int) = (20, 4),
         isSaveMesh: Bool = true,
         onFileError: ((Error) -> Void)? = nil
    ) throws {
        self.isRTK = isRTK
        self.hasConnectedToRTK = isRTK
        self.isSaveMesh = isSaveMesh
        self.onFileError = onFileError
        self.name = SharedFormatter.sessionDate.string(from: Date())
        self.url = try getCameraDirectory().appendingPathComponent(SESSION_FOLDER_NAME)
        self.tempUrl = self.url
        
        if FileManager.default.fileExists(atPath: self.url.path) {
            try FileManager.default.removeItem(at: self.url)
        }
        try FileManager.default.createDirectory(at: self.url, withIntermediateDirectories: true, attributes: nil)
        
        self.pointClouds = .init(spacing: pointCloudsSettings.spacing, pointSize: pointCloudsSettings.pointSize)
        self.cameras = .init(bufferSize: 1_000)
    }
    
    func add(_ frame: FrameMetadata, meta: JpegMetadataCache) {
        lock.lock()
        defer {
            lock.unlock()
        }
        if frame.isRTK { self.hasConnectedToRTK = true }
        self.frames.append(frame)
        self.metas.append(meta)

        sessionLogger.logOperation("photoCaptured", [
            "index": self.frames.count,
            "isRTK": frame.isRTK
        ])
    }
    
    func appendMesh(_ mesh: ARMeshAnchor) {
        if isSaveMesh { _meshReader.append(mesh) }
    }
    
    func removeMesh(_ mesh: ARMeshAnchor) {
        _meshReader.remove(mesh)
    }
    
    func removeAllMesh() {
        _meshReader.removeAll()
    }
    
    func getGPSFolderURL() -> URL {
        let folderUrl = url.appendingPathComponent("_gps")
        if !FileManager.default.fileExists(atPath: folderUrl.path) {
            try? FileManager.default.createDirectory(at: folderUrl, withIntermediateDirectories: true, attributes: nil)
        }
        return folderUrl
    }
    
    func flushLocation(_ location: LocationModel) {
        _gpsLogger?.write()
        _rtkLogger?.write()
        _locationLogger?.write(location: location)
    }
    
    func clear() {
        removeAllMesh()
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        cameras.resetHasConnectedRtk()
        
        _locationLogger = nil
        _gpsLogger = nil
        _rtkLogger = nil
        _catchLogger = nil
        _sessionLogger = nil
        _pointGLTFWriter = nil
        _meshGLTFWriter = nil
        
        pointClouds.data = []
    }
    
    var isEligibleForGlobalCorrection: Bool {
        frames.filter { ImageCalculator.checkCriteriaAccuracy($0.location) }.count >= GlobalRigidCorrection.minimumFitPointCount
    }

    func logPhotoUpdatedEvents(correction: simd_float4x4?) {
        guard correctedRoot != nil, correctedLocations.count == frames.count, !frames.isEmpty else {
            return
        }
        for (index, frame) in frames.enumerated() {
            let corrected = correctedLocations[index]
            let transform = correction.map { $0 * frame.transform } ?? frame.transform
            catchLogger.appendPhotoUpdated(
                imageName: frame.imageNameWithoutExtension,
                transform: transform,
                gps: corrected.location,
                eulerAngles: corrected.eulerAngles
            )
        }
    }

    func exportPointClouds(correction: simd_float4x4?) {
        pointGLTFWriter.exportTransform = correction
        // Writer chỉ được gắn ở đây, không gắn từ init: buffer đầy bị flush ngay trong lúc
        // capture, thời điểm đó chưa biết correction nên những điểm đã flush sẽ không được
        // hiệu chỉnh. Gắn muộn → mọi điểm đi qua append một lần duy nhất, sau khi có transform.
        pointClouds.writer = pointGLTFWriter

        // Kiểm chứng: preFlushed phải luôn = 0 — buffer nào có writeCount > 0 nghĩa là điểm của
        // nó đã bị ghi ra file trước khi exportTransform được set, tức không được hiệu chỉnh.
        var detail: [String: Any] = [
            "buffers": pointClouds.data.count,
            "preFlushed": pointClouds.data.filter { $0.writeCount > 0 }.count,
            "points": pointClouds.data.reduce(0) { $0 + $1.count },
            "corrected": correction != nil
        ]
        if let correction {
            let t = correction.columns.3
            detail["tMeters"] = String(format: "%.3f", sqrt(t.x * t.x + t.y * t.y + t.z * t.z))
            detail["yawDegrees"] = String(format: "%.3f", atan2(correction.columns.0.z, correction.columns.0.x) * 180 / Float.pi)
        }
        sessionLogger.logProcessing("export", "pointCloudWrite", detail)

        pointClouds.write()
        pointClouds.group.wait()
        pointGLTFWriter.write()
    }
    
    func exportMeshes() {
        _meshReader.readBuffer(size: meshGLTFWriter.buffer) { [weak self] vertices in
            self?.meshGLTFWriter.append(vertices)
        } completion: { [weak self] in
            
            self?.meshGLTFWriter.write()
        }
        if !meshGLTFWriter.isWritten {
            try? FileManager.default.removeItem(at: meshGLTFWriter.folder)
        }
    }
    
    func export(onProgress: @escaping (Double) -> Void) async throws -> URL {
        let deferPhotoUpdated = isEligibleForGlobalCorrection

        let correction = deferPhotoUpdated ? correctedRoot.flatMap { GlobalRigidCorrection.compute(frames: frames, root: $0) } : nil
        
        sessionLogger.logOperation("saveRequested", ["photoCount": frames.count])
        if !deferPhotoUpdated {
            // Flow cũ, giữ nguyên cho phiên không đủ điểm fix chuẩn (BR-2).
            catchLogger.projectSaveFinalised()
        }
        exportMeshes()
        exportPointClouds(correction: correction?.transform)

        if deferPhotoUpdated {
            logPhotoUpdatedEvents(correction: correction?.transform)
            catchLogger.projectSaveFinalised()
            StorageManager.waitUntilCompleted()
        }

        let manifest = ManifestWriter(self)
        try manifest.write()

        // Verify manifest.json tồn tại trên disk sau khi ghi
        let manifestURL = url.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            let error = NSError(
                domain: "ManifestWriter",
                code: 999,
                userInfo: [NSLocalizedDescriptionKey: "File manifest.json was not created.\nPath: \(manifestURL.path)"]
            )
            sessionLogger.logProcessing("export", "manifestMissing", level: .error, ["path": manifestURL.path])
            throw error
        }

        // Đảm bảo toàn bộ log (operation/processing) đã được flush và các job ghi file
        // đang chờ (catchLog, gps, rtk...) đã hoàn tất trước khi đóng gói ZIP.
        sessionLogger.write()
        StorageManager.waitUntilCompleted()

        if UserSession.shared.isEnableLog {
            do {
                let debugZipURL = try buildDebugLogZip()
                sessionLogger.logProcessing("export", "debugLogZipCreated", ["path": debugZipURL.lastPathComponent])
            } catch {
                sessionLogger.logProcessing("export", "debugLogZipFailed", level: .error, ["error": "\(error)"])
            }
        }
        sessionLogger.write()

        // Chạy Zip ở luồng background hoàn toàn để không treo UI
        return try await Task.detached(priority: .userInitiated) {
            try self.zipWithProgress(onProgress: onProgress)
        }.value
    }
}

// MARK: - Zip & Accuracy Optimization
extension CaptureSession {
    func zip() throws -> URL {
        var destinationURL = try getCameraDirectory()
        destinationURL.appendPathComponent("\(name)-save.zip")
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.zipItem(at: url, to: destinationURL, shouldKeepParent: false)
            try FileManager.default.removeItem(at: url)
        } else {
            throw NSError(domain: "CaptureSession", code: 0, userInfo: [NSLocalizedDescriptionKey: "Session folder not found."])
        }
        return destinationURL
    }
    
    func zipWithProgress(onProgress: @escaping (Double) -> Void) throws -> URL {
        let destinationURL = try getCameraDirectory().appendingPathComponent("\(name).zip")
        let fileManager = FileManager.default
        
        // Xóa file cũ nếu có
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        // ZipFoundation thực chất có hàm nén nguyên folder rất nhanh
        // Sử dụng Progress object của hệ thống để theo dõi
        let progress = Progress(totalUnitCount: 1)
        let observation = progress.observe(\.fractionCompleted) { p, _ in
            DispatchQueue.main.async { onProgress(p.fractionCompleted) }
        }

        try fileManager.zipItem(at: self.url, to: destinationURL, shouldKeepParent: false, progress: progress)

        observation.invalidate()
        return destinationURL
    }

    // Zip nhẹ chỉ chứa các file log (operation/processing/GPS/RTK/catchLog/manifest),
    // tách biệt với zip project (ảnh + point cloud + mesh) để tiện chia sẻ cho dev debug.
    func buildDebugLogZip() throws -> URL {
        let destinationURL = try getCameraDirectory().appendingPathComponent("\(name)-logs.zip")
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        let archive = try Archive(url: destinationURL, accessMode: .create)

        let relativeLogPaths = [
            "logs/operation.log",
            "logs/processing.log",
            "catchLog.ndjson",
            "gps_positions.csv",
            "rtkGPS.csv",
            "rtkNMEA.csv",
            "manifest.json"
        ]
        for relativePath in relativeLogPaths {
            guard fileManager.fileExists(atPath: url.appendingPathComponent(relativePath).path) else { continue }
            try archive.addEntry(with: relativePath, relativeTo: url, compressionMethod: .deflate)
        }

        let gpsFolder = url.appendingPathComponent("_gps")
        if let gpsFiles = try? fileManager.contentsOfDirectory(at: gpsFolder, includingPropertiesForKeys: nil) {
            for fileURL in gpsFiles {
                try archive.addEntry(with: "_gps/\(fileURL.lastPathComponent)", relativeTo: url, compressionMethod: .deflate)
            }
        }

        // rtk.log là log toàn cục (không thuộc riêng session này), nhưng vẫn hữu ích để dev đối chiếu.
        let globalRtkLog = StorageManager.shared.getCameraFileURL("rtk.log")
        if fileManager.fileExists(atPath: globalRtkLog.path) {
            try archive.addEntry(with: "rtk_debug_global.log", fileURL: globalRtkLog, compressionMethod: .deflate)
        }

        return destinationURL
    }

    // Đóng gói log của session dở dang (folder _session sót lại sau crash) trước khi clear().
    // Chỉ gồm 2 file log operation/processing.
    static func buildCrashLogZip() throws -> URL {
        let sessionURL = try getCameraDirectory().appendingPathComponent(SESSION_FOLDER_NAME)
        let name = SharedFormatter.sessionDate.string(from: Date())
        let destinationURL = try getCameraDirectory().appendingPathComponent("\(name)-crash-logs.zip")
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        let archive = try Archive(url: destinationURL, accessMode: .create)

        for relativePath in ["logs/operation.log", "logs/processing.log"] {
            guard fileManager.fileExists(atPath: sessionURL.appendingPathComponent(relativePath).path) else { continue }
            try archive.addEntry(with: relativePath, relativeTo: sessionURL, compressionMethod: .deflate)
        }

        return destinationURL
    }

    private func distanceSquared(_ p: SIMD2<Double>) -> Double { return p.x * p.x + p.y * p.y }
    
    func getHighAccuracyFrame() -> FrameMetadata? {
        guard hasConnectedToRTK else { return nil }
        var bestFrame: FrameMetadata?
        var minAcc: Double = .greatestFiniteMagnitude
        for frame in frames {
            if let rtk = frame.rtkLocation {
                let acc = distanceSquared(rtk.simdAccuracy)
                if acc < minAcc {
                    minAcc = acc
                    bestFrame = frame
                }
            }
        }
        return bestFrame
    }
}
