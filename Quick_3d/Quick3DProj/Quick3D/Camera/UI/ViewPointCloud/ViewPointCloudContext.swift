//
//  ViewPointCloudContext.swift
//  Quick3D
//
//  Created by HaNST on 28/4/26.
//

import Foundation
import SceneKit
import ZIPFoundation

protocol ViewPointCloudDelegate {
    
    func view(project: Cat, error: Error)
    
    func view(project: Cat, loading: Bool)

}

class ViewPointCloudContext: PreviewContextTemplate, PreviewContext {
    
    var delegate: ViewPointCloudDelegate?
    
    let live: Bool = false
    
    public private(set) var camera: SCNNode?

    func perform(_ event: any Event) {
    }
    
    override func setup(_ view: SCNView) {
        super.setup(view)
        
        view.backgroundColor = .black
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true
        
        let scene = SCNScene()
        
        camera = {
            let node = SCNNode()
            let cam = SCNCamera()
            cam.fieldOfView = 60
            cam.zNear = 0.01
            cam.zFar = 1000
            node.camera = cam
            
            node.simdPosition = [0, 0, 5]
            
            return node
        }()

        scene.rootNode.addChildNode(camera!)
        
        view.scene = scene
    }
    
    
    override func clear() {
        super.clear()
        self.camera?.removeFromParentNode()
        self.camera = nil
    }
    
    func load(for project: Cat) {
        DispatchQueue.global().async {
            guard let zipFolder = project.zipFolder else {
                DispatchQueue.main.async {
                    self.delegate?.view(project: project, error: NSError(domain: "ViewPointCloudContext", code: 0, userInfo: [NSLocalizedDescriptionKey: "File not found."]))
                }
                return
            }
            
            DispatchQueue.main.async {
                self.delegate?.view(project: project, loading: true)
            }
            
            defer {
                DispatchQueue.main.async {
                    self.delegate?.view(project: project, loading: false)
                }
            }
            
            do {
                var pointCloudURL: URL?
                let files = try FileManager.default.contentsOfDirectory(at: zipFolder, includingPropertiesForKeys: nil)
                let zipFiles = files.filter { $0.pathExtension.lowercased() == "zip" }
                for zipFile in zipFiles {
                    let archive = try Archive(url: zipFile, accessMode: .read)
                    if let entry = archive["pointcloud.bin"] {
                        pointCloudURL = zipFolder.appendingPathComponent("pointcloud.bin")
                        
                        if FileManager.default.fileExists(atPath: pointCloudURL!.path) {
                            try FileManager.default.removeItem(at: pointCloudURL!)
                        }
                        
                        _ = try archive.extract(entry, to: pointCloudURL!)
                        break
                    }
                }
                
                if let url = pointCloudURL {
                    let reader = GLTFBinReader(url: url)
                    let (points, colors) = try reader.read()
                    let node = self.createNode(positions: points, colors: colors)
                    try? FileManager.default.removeItem(at: url)
                    DispatchQueue.main.async {
                        self.view?.scene?.rootNode.addChildNode(node)
                        self.setupInitialCamera(node: node)
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.delegate?.view(project: project, error: error)
                }
            }
        }
        
    }
    
    private func setupInitialCamera(node: SCNNode) {
        
        let box = node.boundingBox
        let vMin = SIMD3<Float>(box.min)
        let vMax = SIMD3<Float>(box.max)
        let center = (vMin + vMax) / 2
        let size = vMax - vMin
        
        let maxDimension = max(size.x, max(size.y, size.z))
        let distance = maxDimension * 1.0
        let elevation: Float = Float.pi / 6
        let azimuth: Float = 0
        
        let x = center.x + distance * cos(elevation) * sin(azimuth)
        let y = center.y + distance * sin(elevation)
        let z = center.z + distance * cos(elevation) * cos(azimuth)
        
        camera?.simdPosition = [x, y, z]
        camera?.look(at: SCNVector3(center.x, center.y, center.z))
    }
    
    public func createNode(positions: [SIMD3<Float>], colors: [SIMD3<Float>]) -> SCNNode {
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
        
        element.pointSize = SCNGeometry.pointSize
        element.minimumPointScreenSpaceRadius = SCNGeometry.pointSize
        element.maximumPointScreenSpaceRadius = SCNGeometry.pointSize
        
        let geometry = SCNGeometry(sources: [pointSource, colorSource], elements: [element])
        
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.readsFromDepthBuffer = true
        material.writesToDepthBuffer = true
        material.isDoubleSided = true

        geometry.firstMaterial = material
        
        let node = SCNNode(geometry: geometry)
        
        node.renderingOrder = 10
        
        return node
    }
    
}
