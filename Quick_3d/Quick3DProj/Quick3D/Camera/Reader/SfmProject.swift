//
//  SfmProject.swift
//  Quick3D
//
//  Created by HaNST on 20/2/25.
//

import Foundation
import CoreLocation
import Alamofire
import simd
import SceneKit

struct CrsResp: Codable {
    let conditionFlag: Bool
    let horizontal: String
    let vertical: String
    let conversionLock: Bool
}

struct FetchedData {
    let error: Error?
    init(_ error: Error?) {
        self.error = error
    }
}

class SfmProject {
    
    let projectId: String
    
    let isAR: Bool
    
    var ouptutCrs: String = "32648"
    
    var offset: SIMD3<Double> = .zero
    
    var ifcLayers: [LayerNode] = []
    
    var pointCloudNode: SCNNode?
    
    var ifcNode: SCNNode?
    
    var program: MetalViewARProgram = .init()
    
    private var lasOffset: SIMD3<Double>? = nil
    
    private var ifcOffset: SIMD3<Double>? = nil
    
    private var lasError: Error? = nil
    
    private var ifcError: Error? = nil
    
    private var isLasCompleted = false
    
    private var isIfcCompleted = false
    
    private let lasReader: BVHReader
    
    private let ifcReader: UsdzReader
    
    private var projectDownloader: Task<Void, Error>?
    
    private var lasDownloader: Task<Void, Error>?
    
    private var ifcDownloader: Task<Void, Error>?
    
    init(projectId: String, concurrentLimit: Int = 2, isAR: Bool) {
        self.projectId = projectId
        self.isAR = isAR
        self.lasReader = BVHReader(projectId: self.projectId, concurrentLimit: concurrentLimit,  isAR: isAR)
        self.ifcReader = UsdzReader(projectId: self.projectId)
    }
    
    private func updateOffset() {
        if let offset = lasOffset {
            self.offset = offset
        } else if let offset = ifcOffset {
            self.offset = offset
        }
        if let ifcOffset = ifcOffset, let lasOffset = lasOffset {
            ifcNode?.simdPosition = (SIMD3<Float>)(ifcOffset - lasOffset)
        }
    }
    
    func complete(onError: ((Error) -> Void)? = nil,
                  onComplete: (() -> Void)? = nil) {
        if self.isLasCompleted && self.isIfcCompleted {
            if let lasError = self.lasError, let _ = self.ifcError {
                onError?(lasError)
            } else {
                onComplete?()
            }
        }
    }
    
    func cancel() {
        projectDownloader?.cancel()
        projectDownloader = nil
        lasDownloader?.cancel()
        lasDownloader = nil
        ifcDownloader?.cancel()
        ifcDownloader = nil
        lasReader.cancel()
        ifcReader.cancel()
    }
    
    func render(
        arNode: SCNNode,
        onAddNode: ((SCNNode?, SCNNode?) -> Void)? = nil,
        onUpdateOffset: ((SIMD3<Double>) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        onLasError: ((Error) -> Void)? = nil,
        onIfcError: ((Error) -> Void)? = nil,
        onComplete: (() -> Void)? = nil,
        onLasComplete: (() -> Void)? = nil,
        onLasProgressChanged: ((Double) -> Void)? = nil,
        onIfcComplete: (([LayerNode]) -> Void)? = nil
    ) {
        
        projectDownloader = Task {
            
            let lasDelegate = ARProjectDelegateHelper { node in
                Task { @MainActor in
                    node.name = nameLasNode
                    self.pointCloudNode = node
                    arNode.addChildNode(node)
                    onAddNode?(self.pointCloudNode, self.ifcNode)
                }
            } onUpdateOffset: { offset in
                Task { @MainActor in
                    self.lasOffset = offset
                    self.updateOffset()
                    onUpdateOffset?(self.offset)
                }
            } onError: { error in
                self.lasError = error
                onLasError?(error)
            } onComplete: {
                Task { @MainActor in
                    onLasComplete?()
                    self.isLasCompleted = true
                    self.complete(onError: onError, onComplete: onComplete)
                }
            }
            
            let ifcDelegate = ARProjectDelegateHelper { node in
                Task { @MainActor in
                    node.name = nameUSDZNode
                    self.ifcNode = node
                    arNode.addChildNode(node)
                    onAddNode?(self.pointCloudNode, self.ifcNode)
                }
            } onUpdateOffset: { offset in
                Task { @MainActor in
                    self.ifcOffset = offset
                    self.updateOffset()
                    onUpdateOffset?(self.offset)
                }
            } onError: { error in
                self.ifcError = error
                onIfcError?(error)
            } onComplete: {
                Task { @MainActor in
                    self.ifcLayers = self.ifcReader.layers
                    onIfcComplete?(self.ifcLayers)
                    self.isIfcCompleted = true
                    self.complete(onError: onError, onComplete: onComplete)
                }
            }
            
            await self.fetchCrs()
            
            lasDownloader = Task {
                lasReader.delegate = lasDelegate
                await lasReader.fetch(level: UserSession.shared.lasLevel, program: program, onProgress: onLasProgressChanged)
            }
            
            ifcDownloader = Task {
                ifcReader.delegate = ifcDelegate
                await ifcReader.fetch()
            }
        }
        
    }
    
    private func fetchCrs() async {
        if let data = await getCrs() {
            self.ouptutCrs = "\(data.horizontal)+\(data.vertical)"
        }
    }
    
    private func getCrs() async -> CrsResp? {
        let url = URL(string: Constant.baseUrl + "api/v1/project/\(projectId)/coordinate-system")!
        return try? await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .get)
                .validate()
                .responseDecodable(of: CrsResp.self) { response in
                    switch response.result {
                    case .success(let data):
                        continuation.resume(returning: data)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
    
}

