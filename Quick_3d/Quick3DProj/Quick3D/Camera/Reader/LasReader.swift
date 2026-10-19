//
//  LasReader.swift
//  Quick3D
//
//  Created by HaNST on 26/4/25.
//

import Foundation
import simd
import SceneKit

class LasByteReader {
    
    private let data: Data
    
    private var _offset: Int
    
    var offset: Int {
        set(value) {
            _offset = value
        }
        get {
            _offset
        }
    }
    
    init(_ data: Data, offset: Int = 0) {
        self.data = data
        self._offset = Int(offset)
    }
    
    public func findStartOffset() -> Int {
        var offset: Int = 0
        while offset < data.count - 4 {
            
            if data[offset] == 0x4C
                && data[offset + 1] == 0x41
                && data[offset + 2] == 0x53
                && data[offset + 3] == 0x46 {
                break
            }
            offset += 1
        }
        return offset
    }
    
    public func ignore(_ size: Int) {
        _offset = _offset + size
    }
    
    private func readBytes<T>(_ size: Int, _ type: T.Type) -> T {
        let nextOffset = _offset + size
        let bytes = data[_offset..<nextOffset]
        let _data = Data(bytes)
        let value = _data.withUnsafeBytes {
            $0.load(as: type)
        }
        _offset = nextOffset
        return value;
    }
    
    public func readByte(_ size: Int) -> UInt8 {
        if size > 1 {
            ignore(size - 1)
        }
        let byte: UInt8 = data[_offset]
        _offset = _offset + 1
        return byte
    }
    
    public func readUnsignedChar() -> String {
        return "\(readByte(1))"
    }
    
    public func readUnsignedChars(_ size: Int) -> String {
        var string = ""
        for _ in 0..<size {
            let _value = self.readUnsignedChar()
            string = "\(string)\(_value)"
        }
        return string
    }
    
    public func readColor() -> Int {
        return (Int(readByte(2)))
    }
    
    public func readDouble() -> Double {
        return readBytes(8, Double.self)
    }
    
    public func readLong() -> Int {
        return Int(readBytes(4, Int32.self))
    }
    
    public func readUnsignedShort() -> UInt16 {
        return readBytes(2, UInt16.self)
    }
    
    public func readUnsignedLong() -> UInt32 {
        return readBytes(4, UInt32.self)
    }
    
    public func readUnsignedLongs(_ size: Int) -> [UInt32] {
        var array: [UInt32] = []
        for _ in 0..<size {
            let _value = self.readUnsignedLong()
            array.append(_value)
        }
        return array
    }
    
    public func readString(_ size: Int) -> String {
        let nextOffset = _offset + size
        let bytes = data[_offset..<nextOffset]
        let value = String(bytes: bytes, encoding: .ascii) ?? "N/A"
        _offset = nextOffset
        return value
    }
    
    public func readPointCloud(_ format: String, _ scale: SIMD3<Double>,  _ center: SIMD3<Double>) -> (position: SIMD3<Float>, color: SIMD3<Float>) {
        let ignoreBytes: Int = format == "2" ? 8 : format == "3" ? 16 : 0
        
        let x = readLong()
        let y = readLong()
        let z = readLong()
        
        ignore(ignoreBytes)
        
        let r = readColor()
        let g = readColor()
        let b = readColor()
        
        let _x = Double(x) * scale.x
        let _y = Double(y) * scale.y
        let _z = Double(z) * scale.z
        
        let position = convertPosition([_x, _y, _z]) - center
        
        let color: SIMD3<Float> = [ Float(r) / 255.0, Float(g) / 255.0, Float(b) / 255.0]
        
        return ([Float(position.x), Float(position.y), Float(position.z)], color)
    }
    
    public func convertPosition(_ position: SIMD3<Float>) -> SIMD3<Float> {
        let _x = position.x
        let _y = position.z
        let _z = -position.y
        return [_x, _y, _z]
    }
    
    public func convertPosition(_ position: SIMD3<Double>) -> SIMD3<Double> {
        let _x = position.x
        let _y = position.z
        let _z = -position.y
        return [_x, _y, _z]
    }
    
}

class LasHeaderReader {
    
    private let reader: LasByteReader
    
    var signature: String = ""
    var sourceID: UInt16 = 0
    var globalEncoding: UInt16 = 0
    var guid1: UInt32 = 0
    var guid2: UInt16 = 0
    var guid3: UInt16 = 0
    var guid4: String = ""
    var versionMajor: String = ""
    var versionMinor: String = ""
    var systemIdentifier: String = ""
    var generatingSoftware: String = ""
    var creationDay: UInt16 = 0
    var creationYear: UInt16 = 0
    var headerSize: UInt16 = 0
    var recordOffset: UInt32 = 0
    var variableRecords: UInt32 = 0
    var recordFormat: String = ""
    var recordSize: UInt16 = 0
    var recordCount: UInt32 = 0
    var pointsByReturn: [UInt32] = []
    var scale: SIMD3<Double> = .zero
    var offset: SIMD3<Double> = .zero
    var min: SIMD3<Double> = .zero
    var max: SIMD3<Double> = .zero
    var center: SIMD3<Double> = .zero
    
    init(_ reader: LasByteReader) {
        self.reader = reader
    }
    
    private func log(_ message: String) {
        if (LasReader.debug) {
            print(message)
        }
    }
    
    func read() {
        signature = self.reader.readString(4)
        sourceID = self.reader.readUnsignedShort()
        globalEncoding = self.reader.readUnsignedShort()
        guid1 = self.reader.readUnsignedLong()
        guid2 = self.reader.readUnsignedShort()
        guid3 = self.reader.readUnsignedShort()
        guid4 = self.reader.readUnsignedChars(8)
        versionMajor = self.reader.readUnsignedChar()
        versionMinor = self.reader.readUnsignedChar()
        systemIdentifier = self.reader.readString(32)
        generatingSoftware = self.reader.readString(32)
        creationDay = self.reader.readUnsignedShort()
        creationYear = self.reader.readUnsignedShort()
        headerSize = self.reader.readUnsignedShort()
        recordOffset = self.reader.readUnsignedLong()
        variableRecords = self.reader.readUnsignedLong()
        recordFormat = self.reader.readUnsignedChar()
        recordSize = self.reader.readUnsignedShort()
        recordCount = self.reader.readUnsignedLong()
        pointsByReturn = self.reader.readUnsignedLongs(5)
        scale = [self.reader.readDouble(), self.reader.readDouble(), self.reader.readDouble()]
        offset = [self.reader.readDouble(), self.reader.readDouble(), self.reader.readDouble()]
        
        let maxX = self.reader.readDouble()
        let minX = self.reader.readDouble()
        let maxY = self.reader.readDouble()
        let minY = self.reader.readDouble()
        let maxZ = self.reader.readDouble()
        let minZ = self.reader.readDouble()
        
        max = [maxX, maxY, maxZ]
        min = [minX, minY, minZ]
        max = max - offset
        min = min - offset
        
        center = (max + min) / 2.0
        center = self.reader.convertPosition(center)
        offset = self.reader.convertPosition(offset) + center
        
        log("Signature                            : \(self.signature)")
        log("Source ID                            : \(self.sourceID)")
        log("Global Encoding                      : \(self.globalEncoding)")
        log("Project ID - GUID data 1             : \(self.guid1)")
        log("Project ID - GUID data 2             : \(self.guid2)")
        log("Project ID - GUID data 3             : \(self.guid3)")
        log("Project ID - GUID data 4             : \(self.guid4)")
        log("Version Major                        : \(self.versionMajor)")
        log("Version Minor                        : \(self.versionMinor)")
        log("System Identifier                    : \(self.systemIdentifier)")
        log("Generating Software                  : \(self.generatingSoftware)")
        log("File Creation Day of Year            : \(self.creationDay)")
        log("File Creation Year                   : \(self.creationYear)")
        log("Header Size                          : \(self.headerSize)")
        log("Offset to point data                 : \(self.recordOffset)")
        log("Number of Variable Length Records    : \(self.variableRecords)")
        log("Point Data Format ID (0-99 for spec) : \(self.recordFormat)")
        log("Point Data Record Length             : \(self.recordSize)")
        log("Number of point records              : \(self.recordCount)")
        log("Number of points by return           : \(self.pointsByReturn)")
        log("Scale factor                         : \(self.scale)")
        log("Offset                               : \(self.offset)")
        log("Center                               : \(self.center)")
    }
    
}

class LasReader: ARProjectHelper {
    
    public static var debug: Bool = false
    
    private let url: URL
    private var data: Data?
    private var header: LasHeaderReader?
    
    var node: SCNNode?
    
    func getOffset() -> SIMD3<Double> {
        if let header = self.header {
            return  header.offset
        } else {
            return .zero
        }
    }
    
    init(projectId: String, isAR: Bool = false) {
        self.url = URL(string: Constant.baseUrl + "api/v1/project/\(projectId)/\(isAR ? "ARdownload/LAS" : "ZipDownloadLasFile")")!
        super.init(projectId: projectId)
    }
    
    func fetch(program: MetalViewARProgram? = nil) async {
        do {
            let presignUrl = try await getPresignUrl(url)
            
            let fileUrl = try await downloadFile(presignUrl, fileName: "point_cloud.las")
            
            let data = try Data(contentsOf: fileUrl)
            
            let header = LasHeaderReader(LasByteReader(data))
            
            self.header = header
            
            header.read()
            
            update(offset: getOffset())
            
            var points: [SIMD3<Float>] = []
            var colors: [SIMD3<Float>] = []
            
            let pointCloudOffset = Int(header.recordOffset)
            let pointCloudCount = Int(header.recordCount)
            let pointCloudBytes = Int(header.recordSize)
            
            let bufferSize = 10000
            let bufferCount = Int((pointCloudCount + bufferSize - 1) / bufferSize)
            
            await withTaskGroup(of: (positions: [SIMD3<Float>], colors: [SIMD3<Float>]).self) { group in
                for i in 0..<bufferCount {
                    let offset = i * bufferSize
                    let count = Swift.min(bufferSize, pointCloudCount - offset)
                    group.addTask(priority: .background) {
                        await self.readBuffer(data, offset: pointCloudOffset + offset * pointCloudBytes, count: count)
                    }
                }
                
                for await result in group {
                    points += result.positions
                    colors += result.colors
                }
            }
            let node = createNode(positions: points, colors: colors, program: program)
            
            self.node = node
            
            delegate?.onCreateNode(node)
            
            delegate?.onComplete()
        } catch {
            setError(error)
        }
    }
    
    private func log(_ message: String) {
        if (LasReader.debug) {
            print(message)
        }
    }

    func buildSCNNode() async -> SCNNode? {
        header?.read();
        return await readPoints()
    }
    
    func render(_ arNode: SCNNode) async throws {
        let presignUrl = try await getPresignUrl(url);
        let fileUrl = try await downloadFile(presignUrl, fileName: "point_cloud.las")
        self.data = try Data(contentsOf: fileUrl)
        self.header = LasHeaderReader(LasByteReader(data!))
        if let node = await buildSCNNode() {
            await MainActor.run {
                arNode.addChildNode(node)
            }
        }
    }
    
    private func readBuffer(_ data: Data, offset: Int, count: Int) async -> (positions: [SIMD3<Float>], colors: [SIMD3<Float>]) {
        guard let header = self.header else {
            return ([], [])
        }
        
        var points: [SIMD3<Float>] = []
        var colors: [SIMD3<Float>] = []
        let r = LasByteReader(data, offset: offset)
        for _ in 0..<count {
            let pointCloud = r.readPointCloud(header.recordFormat, header.scale, header.center)
            points.append(pointCloud.position)
            colors.append(pointCloud.color)
        }
        return (points, colors)
    }
    
    private func readPoints() async -> SCNNode? {
        
        guard let header = self.header, let data = self.data else {
            return nil
        }
        
        var points: [SIMD3<Float>] = []
        var colors: [SIMD3<Float>] = []
        
        let pointCloudOffset = Int(header.recordOffset)
        let pointCloudCount = Int(header.recordCount)
        let pointCloudBytes = Int(header.recordSize)
        
        let bufferSize = 10000;
        let bufferCount = Int((pointCloudCount + bufferSize - 1) / bufferSize)
        
        await withTaskGroup(of: (positions: [SIMD3<Float>], colors: [SIMD3<Float>]).self) { group in
            for i in 0..<bufferCount {
                let offset = i * bufferSize
                let count = Swift.min(bufferSize, pointCloudCount - offset)
                group.addTask(priority: .background) {
                    await self.readBuffer(data, offset: pointCloudOffset + offset * pointCloudBytes, count: count)
                }
            }
            
            for await result in group {
                points += result.positions
                colors += result.colors
            }
        }
        
        return createNode(positions: points, colors: colors)
    }
}
