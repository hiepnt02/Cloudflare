//
//  PreviewNode.swift
//  Quick3D
//
//  Created by HaNST on 19/9/25.
//

import Foundation
import SceneKit

class CameraNode : SCNNode {
    
    init(size: CGFloat = 0.2, color: UIColor = .blue) {
        super.init()
        
        let body = SCNBox(
            width: size,
            height: size,
            length: size,
            chamferRadius: size / 10
        )
        let bodyMaterial = SCNMaterial()
        bodyMaterial.diffuse.contents = color
        body.materials = [bodyMaterial]

        let bodyNode = SCNNode(geometry: body)
        self.addChildNode(bodyNode)

        let fov = SCNPyramid(width: size, height: size / 2, length: size)
        let fovMaterial = SCNMaterial()
        fovMaterial.diffuse.contents = color
        fovMaterial.isDoubleSided = true
        fov.materials = [fovMaterial]

        let fovNode = SCNNode(geometry: fov)
        fovNode.position = SCNVector3(0, 0, -0.75 * size)
        fovNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        bodyNode.addChildNode(fovNode)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

class FovNode : SCNNode {
    
    let cameraPointSize: CGFloat = 20
    
    var gpsCircleNode: SCNNode?
    
    init(width: CGFloat, height: CGFloat, ratio: CGFloat, color: UIColor = .blue, sphereColor: UIColor?, showGpsCircle: Bool = false) {

        super.init()
        
        let length = width / ratio
        
        let pyramid = SCNPyramid(width: width, height: height, length: length)

        let sideMaterial = SCNMaterial()
        sideMaterial.diffuse.contents = color
        sideMaterial.transparency = 0.1
        sideMaterial.isDoubleSided = true
        sideMaterial.writesToDepthBuffer = false

        let bottomMaterial = SCNMaterial()
        bottomMaterial.diffuse.contents = color
        bottomMaterial.transparency = 0.6
        bottomMaterial.isDoubleSided = true
        bottomMaterial.writesToDepthBuffer = false

        pyramid.materials = [
            sideMaterial,
            sideMaterial,
            sideMaterial,
            sideMaterial,
            bottomMaterial,
        ]

        let pyramidNode = SCNNode(geometry: pyramid)
        pyramidNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        pyramidNode.renderingOrder = 1

        let outlineNode = createPyramidOutline(width: width, height: height, length: length, color: color)
        outlineNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        outlineNode.renderingOrder = 1

        if let sphereColor = sphereColor {
            let sphereNode = createSphere(color: sphereColor)
            sphereNode.position = SCNVector3(0, 0, Float(length))
            sphereNode.renderingOrder = 10
            self.addChildNode(sphereNode) 
        } else {
            let gpsCircle = createSphere(color: .red)
            gpsCircle.position = SCNVector3(0, 0, Float(length))
            gpsCircle.renderingOrder = 10
            gpsCircle.isHidden = !showGpsCircle
            self.addChildNode(gpsCircle)
            self.gpsCircleNode = gpsCircle
        }

        self.addChildNode(pyramidNode)
        self.addChildNode(outlineNode)
        self.simdPosition = [0, 0, -Float(height)]
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func createSphere(color: UIColor) -> SCNNode {
        var positionArray = [SIMD3<Float>(0, 0, 0)]
        
        let vertexSource = SCNGeometrySource(
            data: Data(bytes: &positionArray, count: MemoryLayout<SIMD3<Float>>.size),
            semantic: .vertex,
            vectorCount: 1,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float>>.size
        )
        
        return SCNNode(geometry: .build(sources: [vertexSource], size: 1, pointSize: cameraPointSize, color: color))
    }
    
    func createPyramidOutline(width: CGFloat, height: CGFloat, length: CGFloat, color: UIColor = .blue) -> SCNNode {
        let node = SCNNode()

        let hw = Float(width / 2)
        let hl = Float(length / 2)
        let h = Float(height)

        let top = SCNVector3(0, h, 0)

        let p1 = SCNVector3(-hw, 0, -hl)
        let p2 = SCNVector3(hw, 0, -hl)
        let p3 = SCNVector3(hw, 0, hl)
        let p4 = SCNVector3(-hw, 0, hl)

        let edges = [
            (p1, p2), (p2, p3), (p3, p4), (p4, p1),
            (p1, top), (p2, top), (p3, top), (p4, top)
        ]

        for (start, end) in edges {
            let edgeNode = lineNode(from: start, to: end, color: color)
            node.addChildNode(edgeNode)
        }

        return node
    }
    
    func lineNode(from: SCNVector3, to: SCNVector3, color: UIColor) -> SCNNode {
        let vertices: [SCNVector3] = [from, to]
        let vertexSource = SCNGeometrySource(vertices: vertices)

        let indices: [UInt32] = [0, 1]
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.size)
        let element = SCNGeometryElement(data: indexData,
                                         primitiveType: .line,
                                         primitiveCount: 1,
                                         bytesPerIndex: MemoryLayout<UInt32>.size)

        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
        geometry.firstMaterial?.diffuse.contents = color
//        geometry.firstMaterial?.transparency = 0.7
        geometry.firstMaterial?.isDoubleSided = true
        geometry.firstMaterial?.lightingModel = .constant
        geometry.firstMaterial?.readsFromDepthBuffer = false
        geometry.firstMaterial?.writesToDepthBuffer = false

        return SCNNode(geometry: geometry)
    }

    
}

class PreviewNode : SCNNode {
    
    init(width: CGFloat, height: CGFloat, ratio: CGFloat, size: CGFloat = 0.2, color: UIColor = .blue, sphereColor: UIColor? = nil, showGpsCircle: Bool = false) {
        super.init()
        
        let frame = FovNode(width: width, height: height, ratio: ratio, color: color, sphereColor: sphereColor, showGpsCircle: showGpsCircle)
        self.addChildNode(frame)
        
        //        let camera = CameraNode(size: size, color: color)
        //        self.addChildNode(camera)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension PreviewNode {
    
    static func build(frame: FrameMetadata, showGpsCircle: Bool = false) -> PreviewNode {
        let ratio = frame.width / frame.height
        let rtkzAccuracy: RTKZAccuracyEnum?
        if frame.isRTK, let rtkVertical = frame.rtkLocation?.vertical {
            rtkzAccuracy = RTKZAccuracyEnum.from(value: rtkVertical)
        } else {
            rtkzAccuracy = nil
        }
        let node: PreviewNode
        if frame.isRTK, let color = rtkzAccuracy?.color() {
            node = PreviewNode(width: 0.15, height: 0.1, ratio: ratio, size: 0.05, color: .blue, sphereColor: color)
        } else {
            node = PreviewNode(width: 0.15, height: 0.1, ratio: ratio, size: 0.05, color: .blue, sphereColor: nil, showGpsCircle: showGpsCircle)
        }
        node.simdTransform = frame.transform
        return node
    }
}
