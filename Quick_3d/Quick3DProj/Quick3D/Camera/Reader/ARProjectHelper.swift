//
//  ARProjectHelper.swift
//  Test4
//
//  Created by HaNST on 13/1/26.
//

import Foundation
import Alamofire
import SceneKit
import simd

protocol ARProjectDelegate {
    func onCreateNode(_ node: SCNNode)
    
    func onUpdateOffset(_ offset: SIMD3<Double>)
    
    func onError(_ error: Error)
    
    func onComplete()
}

class ARProjectDelegateHelper: ARProjectDelegate {
    
    private let _onCreateNode: (SCNNode) -> Void
    private let _onUpdateOffset: (SIMD3<Double>) -> Void
    private let _onError: (Error) -> Void
    private let _onComplete: () -> Void
    
    init(
        onCreateNode: @escaping (SCNNode) -> Void,
        onUpdateOffset: @escaping (SIMD3<Double>) -> Void,
        onError: @escaping (Error) -> Void,
        onComplete: @escaping () -> Void
    ) {
        self._onCreateNode = onCreateNode
        self._onUpdateOffset = onUpdateOffset
        self._onError = onError
        self._onComplete = onComplete
    }
    
    func onCreateNode(_ node: SCNNode) {
        _onCreateNode(node)
    }
    
    func onUpdateOffset(_ offset: SIMD3<Double>) {
        _onUpdateOffset(offset)
    }
    
    func onError(_ error: Error) {
        _onError(error)
    }
    
    func onComplete() {
        _onComplete()
    }
}

class ARProjectHelper {
    internal let session: Session
    
    public static var pointCloudSize: CGFloat = 40
    public static var pointCloudScale: Double = 0.5
    
    let projectId : String
    
    var delegate: ARProjectDelegate?
    
    var min: SIMD3<Float> = [Float.infinity, Float.infinity, Float.infinity]
    
    var max: SIMD3<Float> = [-Float.infinity, -Float.infinity, -Float.infinity]
    
    var center: SIMD3<Float> = .zero
    
    var offset: SIMD3<Double> = .zero
    
    var error: Error? = nil
    
    var isError: Bool = false
    
    init(projectId: String) {
        let configuration = URLSessionConfiguration.af.default
        // Thời gian chờ để thiết lập kết nối (giây)
        // Đây là thời gian chờ giữa các gói tin dữ liệu.
        // Nếu trong vòng 300s mà không có byte dữ liệu nào được truyền, nó sẽ ngắt.
        configuration.timeoutIntervalForRequest = 300
        // Thời gian tối đa để tải xong toàn bộ tài nguyên (Rất quan trọng cho file lớn)
        configuration.timeoutIntervalForResource = 900 // 15 phút
        session = Session(configuration: configuration)
        
        self.projectId = projectId
    }
    
    open func update(min: SIMD3<Float>, max: SIMD3<Float>) {
        let minX = Swift.min(self.min.x, min.x)
        let minY = Swift.min(self.min.y, min.y)
        let minZ = Swift.min(self.min.z, min.z)
        self.min = [minX, minY, minZ]
        
        let maxX = Swift.max(self.max.x, max.x )
        let maxY = Swift.max(self.max.y, max.y )
        let maxZ = Swift.max(self.max.z, max.z )
        self.max = [maxX, maxY, maxZ]
        
        self.center = (self.min + self.max) / 2.0
    }
    
    open func update(offset: SIMD3<Double>) {
        self.offset = offset
        delegate?.onUpdateOffset(self.offset)
    }
    
    open func setError(_ error: Error) {
        self.error = error
        self.isError = true
        delegate?.onError(error)
        delegate?.onComplete()
    }
    
    open func cancel() {
        session.cancelAllRequests()
    }
    
    public func getPresignUrl(_ url: URL) async throws -> URL {
        let data = try await session.request(url, method: .get)
            .validate()
            .serializingString()
            .value
                
        if let url = URL(string: data) {
            return url
        } else {
            throw AFError.responseValidationFailed(reason: .dataFileNil)
        }
    }
    
    public func downloadFile(_ url: URL, fileName: String) async throws -> URL {
        let destination: DownloadRequest.Destination = { _, _ in
            let projectFolder = StorageManager.shared.getTemporaryFileURL(self.projectId)
            let url = projectFolder.appendingPathComponent(fileName)
            return (url, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        let downloadResponse = await session.download(url, to: destination)
            .serializingDownloadedFileURL()
            .response
                
        switch downloadResponse.result {
        case .success(let url):
            return url
        case .failure(let error):
            throw error
        }
    }
    
    public static func makePointCloudMaterial(writesDepth: Bool) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.blendMode = .alpha
        material.readsFromDepthBuffer = true
        material.writesToDepthBuffer = writesDepth
        return material
    }

    public func createNode(positions: [SIMD3<Float>], colors: [SIMD3<Float>], program: MetalViewARProgram? = nil) -> SCNNode {
        let pointSource = SCNGeometrySource(
            data: Data(bytes: positions, count: positions.count * MemoryLayout<SIMD3<Float>>.size),
            semantic: .vertex,
            vectorCount: positions.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float>>.size
        )
        
        let colorSource = SCNGeometrySource(
            data: Data(bytes: colors, count: colors.count * MemoryLayout<SIMD3<Float>>.size),
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float>>.size
        )
        
        var indices = Array(0..<positions.count).map { Int32($0) }
        let indexData = Data(bytes: &indices, count: indices.count * MemoryLayout<Int32>.size)
        
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .point,
            primitiveCount: indices.count,
            bytesPerIndex: MemoryLayout<Int32>.size
        )
        
        let defaultSize = Self.pointCloudSize * Self.pointCloudScale
        element.pointSize = defaultSize
        element.minimumPointScreenSpaceRadius = defaultSize
        element.maximumPointScreenSpaceRadius = defaultSize
        
        let geometry = SCNGeometry(sources: [pointSource, colorSource], elements: [element])
        
        if let p = program {
            geometry.firstMaterial = Self.makePointCloudMaterial(writesDepth: p.pointCloudNodeOpacity >= 1.0)
            geometry.program = p
        } else {
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.readsFromDepthBuffer = true
            material.writesToDepthBuffer = true
            material.isDoubleSided = true
    
            geometry.firstMaterial = material
        }
        
        let node = SCNNode(geometry: geometry)
        
        node.renderingOrder = 10
        
        return node
    }
}
