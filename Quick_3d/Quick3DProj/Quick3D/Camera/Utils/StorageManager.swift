//
//  StorageManager.swift
//  Quick3D
//
//  Created by HaNST on 14/11/24.
//

import Foundation
import SwiftUI
import tiff_ios
import ZIPFoundation
import UniformTypeIdentifiers

final class StorageManager {
    
    static let shared = StorageManager()
    
    static let jobManager = JobManager(maxCount: Int.max)
    
    static func write(_ path: URL, data: Data) {
        jobManager.addTask(DataWriteJob(path, data: data))
    }
    
    static func write(_ path: URL, data: Data, start offset: Int) {
        jobManager.addTask(DataWriteJob(path, data: data, start: offset))
    }
    
    static func write(_ path: URL, text: String, canAppend: Bool = false) {
        jobManager.addTask(TextWriteJob(path, text: text, canAppend: canAppend))
    }
    
    static func cancel() {
        jobManager.cancel()
    }
    
    static func waitUntilCompleted() {
        jobManager.waitUntilCompleted()
    }
    
    // Sử dụng lazy var để đảm bảo chỉ khởi tạo và dọn dẹp 1 lần duy nhất, tránh Data Race
    lazy var temporaryURL: URL = {
        let url = getDirectory().appendingPathComponent("tmp")
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        return url
    }()
    
    private func getDirectory() -> URL {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directoryUrl = documentDirectory.appendingPathComponent("Camera")
        
        if !FileManager.default.fileExists(atPath: directoryUrl.path) {
            try? FileManager.default.createDirectory(at: directoryUrl, withIntermediateDirectories: true, attributes: nil)
        }
        return directoryUrl
    }
    
    func getTemporaryFileURL(_ name: String) -> URL {
        return temporaryURL.appendingPathComponent(name)
    }
    
    func getCameraFileURL(_ name: String) -> URL {
        return getDirectory().appendingPathComponent(name)
    }
    
    func minifyJSON(_ jsonObject: Any) -> String {
        // Lược bỏ options: [] thừa thãi và dùng guard let cho gọn
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }

    func write(_ url: URL, data: Data) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            // Sử dụng API mới an toàn hơn
            let fileHandle = try FileHandle(forUpdating: url)
            defer { try? fileHandle.close() } // Đảm bảo luôn đóng file dù thành công hay lỗi
            
            try fileHandle.seekToEnd()
            try fileHandle.write(contentsOf: data)
        } else {
            try data.write(to: url)
        }
    }
    
    func write(_ url: URL, text: String) throws {
        guard let data = text.data(using: .utf8) else { return }
        try write(url, data: data)
    }

    func isDuplicateZipFileName(_ fileName: String) -> Bool {
        let targetFileName = "\(fileName.lowercased()).zip"
        let targetURL = getDirectory().appendingPathComponent(targetFileName)
        
        // Tối ưu: Chỉ cần check trực tiếp file đó thay vì load toàn bộ directory contents
        return FileManager.default.fileExists(atPath: targetURL.path)
    }
}

// Giữ nguyên struct Vertex vì nó đã ổn, chỉ gom nhóm các property init cho gọn
struct Vertex {
    let x: Float, y: Float, z: Float
    let r: Float, g: Float, b: Float
    
    init(x: Float, y: Float, z: Float, r: Float, g: Float, b: Float) {
        self.x = x; self.y = y; self.z = z
        self.r = r; self.g = g; self.b = b
    }
    
    init(_ simdVertex: SIMD3<Float>) {
        self.x = simdVertex.x; self.y = simdVertex.y; self.z = simdVertex.z
        self.r = 0; self.g = 0; self.b = 0
    }
    
    init(_ point: ParticleUniforms) {
        self.x = point.position.x; self.y = point.position.y; self.z = point.position.z
        self.r = point.color.x; self.g = point.color.y; self.b = point.color.z
    }
    
    var position: SIMD3<Float> { [x, y, z] }
    var color: SIMD3<Float> { [r, g, b] }
    var zUpPosition: SIMD3<Float> { [x, -z, y] }
    
    var zUp: Vertex {
        let pos = zUpPosition
        return .init(x: pos.x, y: pos.y, z: pos.z, r: r, g: g, b: b)
    }
}

class DataWriteJob: Job {
    
    private var path: URL?
    private var data: Data?
    private var offset: Int = 0
    private var canAppend: Bool = false
    
    init(_ path: URL, data: Data) {
        self.path = path
        self.data = data
    }
    
    init(_ path: URL, data: Data, start offset: Int) {
        self.path = path
        self.data = data
        self.canAppend = true
        self.offset = offset
    }
    
    override func clear() {
        path = nil
        data = nil
    }
    
    override func process() {
        guard let _path = path, let _data = data else { return }
        do {
            if canAppend && FileManager.default.fileExists(atPath: _path.path) {
                let fileHandle = try FileHandle(forUpdating: _path)
                
                // Tránh kẹt file resource khi try write throw lỗi
                defer {
                    try? fileHandle.synchronize()
                    try? fileHandle.close()
                }
                
                if offset == 0 {
                    try fileHandle.seekToEnd()
                } else {
                    try fileHandle.seek(toOffset: UInt64(offset))
                }
                try fileHandle.write(contentsOf: _data)
            } else {
                try _data.write(to: _path)
            }
        } catch {
            print("Write \(_path.path) error\n\(error.localizedDescription)")
        }
    }
}

class TextWriteJob: Job {
    
    private var path: URL?
    private var text: String?
    private var canAppend: Bool
    
    init(_ path: URL, text: String, canAppend: Bool = false) {
        self.path = path
        self.text = text
        self.canAppend = canAppend
    }
    
    override func clear() {
        path = nil
        text = nil
    }
    
    override func process() {
        guard let _path = path, let _text = text else { return }
        do {
            if canAppend && FileManager.default.fileExists(atPath: _path.path) {
                // Đã chuyển sang API mới (forUpdating)
                let fileHandle = try FileHandle(forUpdating: _path)
                
                // Đảm bảo đóng file an toàn
                defer {
                    try? fileHandle.synchronize()
                    try? fileHandle.close()
                }
                
                try fileHandle.seekToEnd()
                if let data = _text.data(using: .utf8) {
                    try fileHandle.write(contentsOf: data)
                }
            } else {
                try _text.write(to: _path, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Write text error\n\(error.localizedDescription)")
        }
    }
}
