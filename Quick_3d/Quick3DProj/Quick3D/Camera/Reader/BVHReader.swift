//
//  BinReader.swift
//  Quick3D
//
//  Created by HaNST on 26/4/25.
//

import Foundation
import simd
import SceneKit
import Alamofire

class BVHReader: ARProjectHelper {
    
    let concurrentLimit: Int
    
    private let lasReader: LasReader
    
    private var rawOffset: SIMD3<Double> = .zero
    
    private var node: SCNNode?
    
    private var lasDownloader: Task<Void, Error>?
    
    init(projectId: String, concurrentLimit: Int = 2, isAR: Bool = false) {
        self.concurrentLimit = concurrentLimit
        self.lasReader = LasReader(projectId: projectId, isAR: isAR)
        super.init(projectId: projectId)
    }
    
    override func update(min: SIMD3<Float>, max: SIMD3<Float>) {
        super.update(min: min, max: max)
        self.update(offset: self.rawOffset + SIMD3<Double>(self.center))
        self.node?.simdPosition = -self.center
    }
    
    override func setError(_ error: Error) {
        setError(error, program: nil)
    }
    
    func setError(_ error: Error, program: MetalViewARProgram?) {
        isError = true
        lasReader.delegate = delegate
        lasDownloader = Task {
            await lasReader.fetch(program: program)
        }
    }
    
    override func cancel() {
        lasDownloader?.cancel()
        lasDownloader = nil
    }
    
    func fetch(level: Int, program: MetalViewARProgram? = nil, onProgress: ((Double) -> Void)? = nil) async {
        
        let resp: BVHDataResp
        let meta: BVHMetadataResp
        
        do {
            resp = try await getBVH(level)
            meta = try await fetchMetadata(resp.meta)
        } catch {
            self.setError(error, program: program)
            return
        }
        
        rawOffset = -meta.getOffset()
        
        node = SCNNode()
        
        delegate?.onCreateNode(node!)
        
        // Calculate total items for progress tracking
        let totalItems = resp.levels.reduce(0) { $0 + $1.count }
        if totalItems == 0 {
            await MainActor.run {
                onProgress?(1.0)
            }
            return
        }
        
        let semaphore = AsyncSemaphore(value: concurrentLimit)
        
        actor ProgressTracker {
            private var completedItems: Int = 0
            private let totalItems: Int
            private let onProgress: ((Double) -> Void)?
            
            init(totalItems: Int, onProgress: ((Double) -> Void)?) {
                self.totalItems = totalItems
                self.onProgress = onProgress
            }
            
            func incrementProgress() async {
                completedItems += 1
                let progress = Double(completedItems) / Double(totalItems)
                
                await MainActor.run {
                    onProgress?(progress)
                }
            }
        }
        
        let progressTracker = ProgressTracker(totalItems: totalItems, onProgress: onProgress)
        
        await withTaskGroup(of: Void.self) { group in
            var index = 0
            for level in resp.levels {
                for data in level {
                    
                    let globalIndex = index
                    
                    group.addTask {
                        await semaphore.wait()

                        guard !self.isError else {
                            await semaphore.signal()
                            await progressTracker.incrementProgress()
                            return
                        }
                        
                        do {
                            let result = try await self.readBin(globalIndex, data.point, data.color)
                            
                            await MainActor.run {
                                let n = self.createNode(positions: result.positions, colors: result.colors, program: program)
                                self.node?.addChildNode(n)
                            }
                            
                            self.update(min: result.min, max: result.max)
                            await progressTracker.incrementProgress()
                        } catch {
                            self.setError(error, program: program)
                            await progressTracker.incrementProgress()
                        }
                        
                        await semaphore.signal()
                    }
                    
                    index += 1
                }
            }
        }
        
        if !isError {
            await MainActor.run {
                onProgress?(1.0)
            }
            delegate?.onComplete()
        }
    }
    
    func getInt(_ data: Data, offset: Int) -> Int {
            let bytes : [UInt8] = [0, 0, 0, data[offset]]
            let _data = Data(bytes)
            let value = UInt32(bigEndian: _data.withUnsafeBytes { $0.load(as: UInt32.self) })
            return Int(value)
    }
    
    func getFloat(_ data: Data, offset: Int) -> Float {
        let bytes = Data(data[offset...offset+3].reversed())
        let floatValue: Float = Float(bitPattern: UInt32(bigEndian: bytes.withUnsafeBytes { $0.load(as: UInt32.self) }))
        return floatValue
    }
    
    func readColors(_ url: URL) -> [SIMD3<Float>] {
        var result : [SIMD3<Float>] = []
        let data = try! Data(contentsOf: url)
        var offset = 0
        while offset < data.count {
            let r = getFloat(data, offset: offset)
            offset += 4
            let g = getFloat(data, offset: offset)
            offset += 4
            let b = getFloat(data, offset: offset)
            offset += 4
            result.append([r, g, b])
        }
        
        return result
    }
    
    func readPositions(_ points: URL, _ colors: URL) -> (positions: [SIMD3<Float>], colors: [SIMD3<Float>], min: SIMD3<Float>, max: SIMD3<Float>) {
        
        let colorsData = readColors(colors)
        
        let data = try! Data(contentsOf: points)
        
        var positionsData: [SIMD3<Float>] = []
        
        var offset = 0
        
        var minX = Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        
        while offset < data.count {
            let x = getFloat(data, offset: offset)
            offset += 4
            let y = getFloat(data, offset: offset)
            offset += 4
            let z = getFloat(data, offset: offset)
            offset += 4
            
            let _x = x
            let _y = z
            let _z = -y
            
            minX = Swift.min(minX, _x)
            minY = Swift.min(minY, _y)
            minZ = Swift.min(minZ, _z)
            maxX = Swift.max(maxX, _x)
            maxY = Swift.max(maxY, _y)
            maxZ = Swift.max(maxZ, _z)
            
            positionsData.append([_x, _y, _z])
        }
        
        return (positionsData, colorsData, [minX, minY, minZ], [maxX, maxY, maxZ])
    }
    
    func readBin(_ index: Int, _ points: String, _ colors: String) async throws -> (positions: [SIMD3<Float>], colors: [SIMD3<Float>], min: SIMD3<Float>, max: SIMD3<Float>) {
        guard let pointsUrl = URL(string: points), let colorsUrl = URL(string: colors) else {
            throw AFError.responseValidationFailed(reason: .dataFileNil)
        }
        let pointsFile = try await downloadFile(pointsUrl, fileName: "points_\(index).bin")
        let colorsFile = try await downloadFile(colorsUrl, fileName: "colors_\(index).bin")
        return readPositions(pointsFile, colorsFile)
    }
    
    func fetchMetadata(_ meta: String) async throws -> BVHMetadataResp {
        guard let metaUrl = URL(string: meta) else {
            throw AFError.responseValidationFailed(reason: .dataFileNil)
        }
        
        return try await session.request(metaUrl, method: .get)
                    .validate()
                    .serializingDecodable(BVHMetadataResp.self)
                    .value
    }
    
    func getBVH(_ level: Int) async throws -> BVHDataResp {
        let url = URL(string: Constant.baseUrl + "api/v1/project/\(projectId)/GetBVHData/\(level)/GROUP")!
        
        return try await session.request(url, method: .get)
                    .validate()
                    .serializingDecodable(BVHDataResp.self)
                    .value
    }
}
