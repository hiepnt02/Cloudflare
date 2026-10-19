//
//  UsdzReader.swift
//  Quick3D
//
//  Created by HaNST on 13/10/25.
//

import Foundation
import simd
import SceneKit
import Alamofire

class UsdzReader: ARProjectHelper {
    
    private let url: URL
    private let metadataUrl: URL
    private var jsonUrl: URL?
    private var fileUrl: URL?
    private var localFile: URL?
    private var _offset: SIMD3<Double> = .zero
    
    private var rawOffset: SIMD3<Double> = .zero
    
    var layers: [LayerNode] = []
    
    var node: SCNNode?
    
    override init(projectId: String) {
        self.url = URL(string: Constant.baseUrl + "api/v1/project/\(projectId)/ARdownload/USDZ")!
        self.metadataUrl = URL(string: Constant.baseUrl + "api/v1/project/\(projectId)/ARdownload/USDZMETADATA")!
        super.init(projectId: projectId)
    }
    
    override func update(min: SIMD3<Float>, max: SIMD3<Float>) {
        super.update(min: min, max: max)
        self.update(offset: self.rawOffset + SIMD3<Double>(self.center))
    }
    
    func fetchMetadata(_ metaUrl: URL) async throws -> SIMD3<Double> {
        do{
            self.jsonUrl = try await getPresignUrl(metaUrl)
            
            guard let jsonUrl = self.jsonUrl else { return .zero }
            
            return try await session.request(jsonUrl, method: .get)
                        .validate()
                        .serializingDecodable(USDZMetadata.self)
                        .value
                        .getOffset()
        }catch{
          return .zero
        }
        
    }
    
    func fetch() async {
        do {
            let presignUrl = try await getPresignUrl(url)
            var metaOffset: SIMD3<Double> = .zero
            
            self.fileUrl = try await downloadFile(presignUrl, fileName: "object.usdz")
            metaOffset = try await fetchMetadata(self.metadataUrl)
            
            self.rawOffset = metaOffset
            
            if let scene = loadScene() {
                let scnMax = scene.rootNode.boundingBox.max
                let scnMin = scene.rootNode.boundingBox.min
                let max: SIMD3<Float> = [Float(scnMax.x), Float(scnMax.y), Float(scnMax.z)]
                let min: SIMD3<Float> = [Float(scnMin.x), Float(scnMin.y), Float(scnMin.z)]
                
                update(min: min, max: max)
                
                let rootNode = scene.rootNode
                self.node = rootNode
                
                delegate?.onCreateNode(rootNode)
                
                for child in rootNode.childNodes {
                    child.simdPosition = child.simdPosition - self.center
                }
                
                let metadata = extractIFCMetadata(from: self.fileUrl!)
                let metadataMap = metadata.reduce(into: [String: IFCMetadata]()) { dict, item in
                    if dict[item.xformName] == nil {
                        dict[item.xformName] = item
                    }
                }
                
                layers = parseNode(rootNode, depth: 0, metadata: metadataMap)
                delegate?.onComplete()
                
            } else {
                throw AFError.responseValidationFailed(reason: .dataFileNil)
            }
        } catch {
            setError(error)
        }
    }

    func getOffset() -> SIMD3<Double> {
        return _offset
    }
    
    private func loadScene(convert: Bool = true) -> SCNScene? {
        guard let fileUrl = self.fileUrl, fileUrl.pathExtension.lowercased() == "usdz" else {
            print("Not a USDZ file: \(fileUrl!.lastPathComponent)")
            return nil
        }
        
        let options: [SCNSceneSource.LoadingOption: Any] = convert
        ? [.convertToYUp: true, .convertUnitsToMeters: true]
        : [:]
        
        do {
            return try SCNScene(url: fileUrl, options: options)
        } catch {
            print("Failed to load USDZ scene:", error)
            return nil
        }
    }

    private func parseNode(_ node: SCNNode, depth: Int, metadata: [String : IFCMetadata]) -> [LayerNode] {
        return node.childNodes
            .filter { child in
                guard let name = child.name else { return true }
                return !name.starts(with: "_") && !(name == "Looks")
            }.map { child in
            let info = metadata[child.name ?? ""]

            let id = child.name ?? UUID().uuidString
            let name = child.name ?? "Unnamed"
            let displayName = info?.name
            let type = info?.type ?? (child.geometry != nil ? "Geometry" : "Group")
            
            // Recursively parse children with incremented depth
            let childLayers = parseNode(child, depth: depth + 1, metadata: metadata)
            
            let layerNode = LayerNode(
                id: id,
                name: name,
                displayName: displayName,
                type: type,
                depth: depth,
                children: childLayers,
                isExpanded: true
            )

            // Set parent relationship
            childLayers.forEach { $0.parent = layerNode }
            
            return layerNode
        }
    }
}
