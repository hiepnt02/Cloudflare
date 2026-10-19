//
//  GLTFWriter.swift
//  Quick3D
//
//  Created by HaNST on 16/10/25.
//

import Foundation
import simd

class GLTFWriter {
    
    private let name: String
    private var _min: SIMD3<Float> = .init(repeating: .greatestFiniteMagnitude)
    private var _max: SIMD3<Float> = .init(repeating: -.greatestFiniteMagnitude)
    
    let folder: URL
    let binFile: URL
    let jsonFile: URL
    
    private let mode: Int
    private let includeRGB: Bool
    
    private var count: Int = 0
    private var data: [Float] = []
    private var dataCount: Int = 0
    
    let buffer: Int
    
    private let lock = NSLock()
    
    var onError: ((Error) -> Void)? = nil

    public private(set) var isWritten: Bool = false

    var exportTransform: simd_float4x4?
    
    init(_ folder: URL, name: String, mode: Int, includeRGB: Bool, bufferSize: Int = 100000) {
        self.name = name
        self.folder = folder
        self.binFile = folder.appendingPathComponent("\(name).bin")
        self.jsonFile = folder.appendingPathComponent("\(name).gltf")
        self.mode = mode
        self.includeRGB = includeRGB
        self.buffer = bufferSize
        
        // Chỉ tạo file bin khi thực sự có nhu cầu hoặc tạo file trống an toàn
        try? FileManager.default.removeItem(at: binFile)
        try? FileManager.default.removeItem(at: jsonFile)
    }
    
    func append(_ vertices: [Vertex]) {
        guard !vertices.isEmpty else { return } // Bảo vệ nếu mảng rỗng
        let positions = vertices.map { SIMD3<Float>($0.x, $0.y, $0.z) }
        let colors = vertices.map { SIMD3<Float>($0.r, $0.g, $0.b) }
        self.append(positions: positions, colors: colors, convertZUp: false)
    }
    
    func append(positions: [SIMD3<Float>], colors: [SIMD3<Float>], convertZUp: Bool = false) {
        
        lock.lock()
        defer {
            lock.unlock()
        }
        
        guard !positions.isEmpty else { return }

        let vertexCount = positions.count
        
        self.dataCount += positions.count
        self.count += vertexCount
        
        let floatsPerVertex = self.includeRGB ? 6 : 3
        self.data.reserveCapacity(self.data.count + (vertexCount * floatsPerVertex))
        
        for i in 0..<vertexCount {
            var pos = positions[i]
            if let exportTransform {
                let moved = exportTransform * SIMD4<Float>(pos, 1)
                pos = SIMD3<Float>(moved.x, moved.y, moved.z)
            }
            if convertZUp {
                pos = [pos.x, -pos.z, pos.y]
            }
            
            self.data.append(pos.x)
            self.data.append(pos.y)
            self.data.append(pos.z)
            
            if self.includeRGB {
                let col = colors[i]
                self.data.append(col.x)
                self.data.append(col.y)
                self.data.append(col.z)
            }
            
            self._min = min(self._min, pos)
            self._max = max(self._max, pos)
        }
        
        if self.data.count >= self.buffer {
            self.flushBufferToDisk()
        }
    }
    
    func write() {
        lock.lock()
        defer {
            lock.unlock()
        }
            
        // 1. Kiểm tra nếu hoàn toàn không có data
        if self.count == 0 {
            print("GLTFWriter: No data to write.")
            // Bạn có thể chọn trả về lỗi hoặc tạo 1 file json rỗng đơn giản
            return
        }
        
        // 2. Ghi nốt phần data còn lại trong RAM
        self.flushBufferToDisk()
        
        // 3. Chỉ ghi file JSON nếu file BIN đã tồn tại và có dung lượng
        if self.dataCount > 0 {
            self.writeJsonFile()
        }
    }
    
    private func flushBufferToDisk() {
        guard !data.isEmpty else { return }
        isWritten = true
        let binaryData = data.withUnsafeBytes { Data($0) }
        StorageManager.write(binFile, data: binaryData, start: 0)
        data.removeAll(keepingCapacity: true)
    }
    
    private func writeJsonFile() {
        // Bảo vệ giá trị min/max nếu chẳng may count > 0 nhưng không có giá trị hợp lệ
        let finalMin = count > 0 ? [_min.x, _min.y, _min.z] : [0, 0, 0]
        let finalMax = count > 0 ? [_max.x, _max.y, _max.z] : [0, 0, 0]
        
        let byteStride = includeRGB ? 24 : 12
        let totalByteLength = byteStride * count
        
        var accessors: [[String: Any]] = [
            [
                "bufferView": 0,
                "byteOffset": 0,
                "componentType": 5126,
                "count": count,
                "type": "VEC3",
                "min": finalMin,
                "max": finalMax
            ]
        ]
        
        if includeRGB {
            accessors.append([
                "bufferView": 0,
                "byteOffset": 12,
                "componentType": 5126,
                "count": count,
                "type": "VEC3"
            ])
        }
        
        let json: [String: Any] = [
            "asset": ["version": "2.0"],
            "scenes": [["nodes": [0]]],
            "nodes": [["mesh": 0]],
            "meshes": [[
                "primitives": [[
                    "attributes": includeRGB ? ["POSITION": 0, "COLOR_0": 1] : ["POSITION": 0],
                    "mode": mode
                ]],
                "name": name
            ]],
            "buffers": [[
                "uri": binFile.lastPathComponent,
                "byteLength": totalByteLength
            ]],
            "bufferViews": [[
                "buffer": 0,
                "byteOffset": 0,
                "byteLength": totalByteLength,
                "byteStride": byteStride,
                "target": 34962
            ]],
            "accessors": accessors,
            "scene": 0
        ]
        
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
            StorageManager.write(jsonFile, data: jsonData)
        } catch {
            onError?(error)
        }
    }
}
