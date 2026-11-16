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
    init(_ error: Error?) { self.error = error }
}

class SfmProject {
    let projectId: String
    let isAR: Bool
    var ouptutCrs: String = "32648"
    var offset: SIMD3<Double> = .zero
    var ifcLayers: [LayerNode] = []
    var scmLayers: [LayerNode] = []
    var pointCloudNode: SCNNode?
    var ifcNode: SCNNode?
    var scmNode: SCNNode?
    var program: MetalViewARProgram = .init()

    private var lasOffset: SIMD3<Double>?
    private var designOffsets: [ARDesignType: SIMD3<Double>] = [:]
    private var lasError: Error?
    private var designErrors: [ARDesignType: Error] = [:]
    private var isLasCompleted = false
    private var completedDesigns: Set<ARDesignType> = []
    private var completionReported = false
    private var isCancelled = false
    private let lasReader: BVHReader
    private let ifcReader: UsdzReader
    private let scmReader: SCMReader
    private var projectDownloader: Task<Void, Never>?
    private var lasDownloader: Task<Void, Never>?
    private var ifcDownloader: Task<Void, Never>?
    private var scmDownloader: Task<Void, Never>?

    init(projectId: String, concurrentLimit: Int = 2, isAR: Bool) {
        self.projectId = projectId
        self.isAR = isAR
        lasReader = BVHReader(projectId: projectId, concurrentLimit: concurrentLimit, isAR: isAR)
        ifcReader = UsdzReader(projectId: projectId)
        scmReader = SCMReader(projectId: projectId)
    }

    @MainActor
    private func updateOffset() {
        offset = lasOffset ?? designOffsets[.ifc] ?? designOffsets[.scm] ?? .zero
        // The point-cloud reader owns its centering transform. Do not replace it.
        // Readers center each design before it joins the shared AR display origin.
        ifcNode?.simdPosition = .zero
        scmNode?.simdPosition = .zero
    }

    @MainActor
    private func complete(onError: ((Error) -> Void)?, onComplete: (() -> Void)?) {
        guard !isCancelled, !completionReported, isLasCompleted,
              completedDesigns.count == ARDesignType.allCases.count else { return }
        completionReported = true
        if pointCloudNode == nil && ifcNode == nil && scmNode == nil {
            let error = lasError ?? designErrors[.ifc] ?? designErrors[.scm]
                ?? NSError(domain: "ARProject", code: 1,
                           userInfo: [NSLocalizedDescriptionKey: "No renderable point cloud or design"])
            onError?(error)
        } else {
            onComplete?()
        }
    }

    func cancel() {
        isCancelled = true
        projectDownloader?.cancel()
        lasDownloader?.cancel()
        ifcDownloader?.cancel()
        scmDownloader?.cancel()
        lasReader.cancel()
        ifcReader.cancel()
        scmReader.cancel()
        lasReader.delegate = nil
        ifcReader.delegate = nil
        scmReader.delegate = nil
    }

    @MainActor
    private func finishDesign(
        _ design: ARDesignType, reader: ARProjectHelper, node: SCNNode?,
        layers: [LayerNode], arNode: SCNNode,
        onAddNode: ((SCNNode?, SCNNode?, SCNNode?) -> Void)?,
        onUpdateOffset: ((SIMD3<Double>) -> Void)?,
        onDesignError: ((ARDesignType, Error) -> Void)?,
        onDesignComplete: ((ARDesignType, [LayerNode]) -> Void)?,
        onError: ((Error) -> Void)?, onComplete: (() -> Void)?
    ) {
        guard !isCancelled, !Task.isCancelled else { return }
        if !reader.isError, let node = node {
            node.name = design.rootNodeName
            if design == .ifc {
                ifcNode = node
                ifcLayers = layers
            } else {
                scmNode = node
                scmLayers = layers
            }
            designOffsets[design] = reader.offset
            arNode.addChildNode(node)
            updateOffset()
            onAddNode?(pointCloudNode, ifcNode, scmNode)
            onUpdateOffset?(offset)
            print("[ARCoordinates] \(design.rawValue.uppercased()) sourceCenter=\(reader.offset) reference=\(offset) position=\(node.simdPosition)")
            onDesignComplete?(design, layers)
        } else {
            let error = reader.error ?? NSError(domain: "ARDesign", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No renderable design"])
            designErrors[design] = error
            onDesignError?(design, error)
        }
        completedDesigns.insert(design)
        complete(onError: onError, onComplete: onComplete)
    }

    func render(
        arNode: SCNNode,
        onAddNode: ((SCNNode?, SCNNode?, SCNNode?) -> Void)? = nil,
        onUpdateOffset: ((SIMD3<Double>) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        onLasError: ((Error) -> Void)? = nil,
        onDesignError: ((ARDesignType, Error) -> Void)? = nil,
        onComplete: (() -> Void)? = nil,
        onLasComplete: (() -> Void)? = nil,
        onLasProgressChanged: ((Double) -> Void)? = nil,
        onDesignComplete: ((ARDesignType, [LayerNode]) -> Void)? = nil
    ) {
        projectDownloader = Task {
            await fetchCrs()
            guard !Task.isCancelled, !isCancelled else { return }

            let lasDelegate = ARProjectDelegateHelper { node in
                Task { @MainActor in
                    guard !self.isCancelled else { return }
                    node.name = nameLasNode
                    self.pointCloudNode = node
                    arNode.addChildNode(node)
                    self.updateOffset()
                    onAddNode?(self.pointCloudNode, self.ifcNode, self.scmNode)
                    // Direct LAS sends its offset before its node, whereas
                    // BVH sends the node first. Notify again once both exist.
                    if self.lasOffset != nil { onUpdateOffset?(self.offset) }
                }
            } onUpdateOffset: { offset in
                Task { @MainActor in
                    guard !self.isCancelled else { return }
                    self.lasOffset = offset
                    self.updateOffset()
                    onUpdateOffset?(self.offset)
                }
            } onError: { error in
                Task { @MainActor in
                    guard !self.isCancelled else { return }
                    self.lasError = error
                    onLasError?(error)
                }
            } onComplete: {
                Task { @MainActor in
                    guard !self.isCancelled else { return }
                    onLasComplete?()
                    self.isLasCompleted = true
                    self.updateOffset()
                    if self.lasOffset != nil { onUpdateOffset?(self.offset) }
                    print("[ARCoordinates] LAS reference=\(String(describing: self.lasOffset)) IFC=\(String(describing: self.ifcNode?.simdPosition)) SCM=\(String(describing: self.scmNode?.simdPosition))")
                    self.complete(onError: onError, onComplete: onComplete)
                }
            }

            lasDownloader = Task {
                lasReader.delegate = lasDelegate
                await lasReader.fetch(level: UserSession.shared.lasLevel, program: program, onProgress: onLasProgressChanged)
            }
            // These readers are independent: neither is a fallback for the other.
            ifcDownloader = Task {
                await ifcReader.fetch()
                await finishDesign(.ifc, reader: ifcReader, node: ifcReader.node,
                    layers: ifcReader.layers, arNode: arNode, onAddNode: onAddNode,
                    onUpdateOffset: onUpdateOffset, onDesignError: onDesignError,
                    onDesignComplete: onDesignComplete, onError: onError, onComplete: onComplete)
            }
            scmDownloader = Task {
                await scmReader.fetch()
                await finishDesign(.scm, reader: scmReader, node: scmReader.node,
                    layers: scmReader.layers, arNode: arNode, onAddNode: onAddNode,
                    onUpdateOffset: onUpdateOffset, onDesignError: onDesignError,
                    onDesignComplete: onDesignComplete, onError: onError, onComplete: onComplete)
            }
        }
    }

    private func fetchCrs() async {
        if let data = await getCrs() { ouptutCrs = "\(data.horizontal)+\(data.vertical)" }
    }

    private func getCrs() async -> CrsResp? {
        let url = URL(string: Constant.baseUrl + "api/v1/project/\(projectId)/coordinate-system")!
        return try? await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .get)
                .validate()
                .responseDecodable(of: CrsResp.self) { response in
                    switch response.result {
                    case .success(let data): continuation.resume(returning: data)
                    case .failure(let error): continuation.resume(throwing: error)
                    }
                }
        }
    }
}
