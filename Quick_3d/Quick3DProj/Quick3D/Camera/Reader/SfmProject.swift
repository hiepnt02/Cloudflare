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
    
    private var ifcReader: UsdzReader?
    private var scmReader: SCMReader?
    /// Design source actually in use. Starts as USDZ (IFC) unless forced; flips
    /// to SCM when the project has no USDZ (fetch fails), so SCM-only projects
    /// still show their design without any USDZ file.
    private var useSCM: Bool
    
    private var projectDownloader: Task<Void, Error>?
    
    private var lasDownloader: Task<Void, Error>?
    
    private var ifcDownloader: Task<Void, Error>?
    
    init(projectId: String, concurrentLimit: Int = 2, isAR: Bool, useSCM: Bool = false) {
        self.projectId = projectId
        self.isAR = isAR
        self.lasReader = BVHReader(projectId: self.projectId, concurrentLimit: concurrentLimit,  isAR: isAR)
        self.useSCM = useSCM
        self.scmReader = SCMReader(projectId: self.projectId)
        if !useSCM {
            self.ifcReader = UsdzReader(projectId: self.projectId)
        }
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
        ifcReader?.cancel()
        scmReader?.cancel()
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
                    self.ifcLayers = self.useSCM ? (self.scmReader?.layers ?? []) : (self.ifcReader?.layers ?? [])
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
                // 1) USDZ (IFC) first. Its errors are held back: a missing USDZ
                //    is expected for SCM-only projects and must not raise
                //    "File not found" before SCM is tried.
                if !useSCM, let ifcReader = ifcReader {
                    let usdzDelegate = ARProjectDelegateHelper { node in
                        ifcDelegate.onCreateNode(node)
                    } onUpdateOffset: { offset in
                        ifcDelegate.onUpdateOffset(offset)
                    } onError: { _ in
                    } onComplete: {
                    }
                    ifcReader.delegate = usdzDelegate
                    await ifcReader.fetch()
                    if !ifcReader.isError {
                        ifcDelegate.onComplete()
                        return
                    }
                    if Task.isCancelled { return }
                    print("[SfmProject] USDZ unavailable (\(ifcReader.error?.localizedDescription ?? "-")), falling back to SCM")
                    self.useSCM = true
                }
                // 2) SCM — reports errors normally, so a project with neither
                //    file still shows the original error.
                if let scmReader = scmReader {
                    scmReader.delegate = ifcDelegate
                    await scmReader.fetch()
                }
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

