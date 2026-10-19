//
//  MetalPointCloud.swift
//  Quick3D
//
//  Created by HaNST on 6/11/25.
//

import Foundation
import Metal
import SceneKit

class MetalCamera {
    
    let cameraPointSize: CGFloat = 22
    
    let base: [SIMD4<Float>]
    
    var positions: MetalBuffer<SIMD3<Float>>
    
    var colors: MetalBuffer<SIMD4<Float>>
    
    var texcoords: MetalBuffer<Float>
    
    var lineIndices: MetalBuffer<UInt32>
    
    var triangleIndices: MetalBuffer<UInt32>
    
    var pointIndices: MetalBuffer<UInt32>
    
    let size: Int
    
    var count: Int = 0
    
    let pointsPerCamera: Int = 5
    let linesPerCamera: Int = 4
    let trianglePerCamera: Int = 2
    
    private var _showAccuracy: Bool = false
    
    var showAccuracy: Bool {
        get { _showAccuracy }
        set {
            if newValue != _showAccuracy {
                _showAccuracy = newValue
                fillColorAlpha()
            }
        }
    }
    
    private var node: SCNNode? = nil
    
    private var boundingBox: (min: SCNVector3, max: SCNVector3) = (SCNVector3(0, 0, 0), SCNVector3(0, 0, 0))
    
    private var _min: SIMD3<Float> = [.infinity, .infinity, .infinity]
    private var _max: SIMD3<Float> = [-.infinity, -.infinity, -.infinity]
    
    init(manager: MetalManager, size: Int, width: Float, height: Float, ratio: Float, showAccuracy: Bool = false) {
        
        let length = width / ratio
        
        let baseX = width / 2
        let baseY = length / 2
        let baseZ = -height
        
        self.base = [
            [0, 0, 0, 1],
            [baseX, baseY, baseZ, 1],
            [baseX, -baseY, baseZ, 1],
            [-baseX, -baseY, baseZ, 1],
            [-baseX, baseY, baseZ, 1]
        ]
        
        self.size = size
        
        self._showAccuracy = showAccuracy
        
        self.positions = manager.makeBuffer(count: size * pointsPerCamera, options: .storageModeShared)!
        
        let _color: [SIMD4<Float>] = (0..<size).map { _ in .zero }
        let _lineIndices: [UInt32] = (0..<size * linesPerCamera * 2).map { _ in 0 }
        let _triangleIndices: [UInt32] = (0..<size * trianglePerCamera * 3).map { _ in 0 }
        let _pointIndices: [UInt32] = (0..<size).map { UInt32($0) }
        let _texcoords: [Float] = (0..<size).map { _ in 1 }
        
        self.colors = manager.makeBuffer(array: _color)!
        self.lineIndices = manager.makeBuffer(array: _lineIndices)!
        self.triangleIndices = manager.makeBuffer(array: _triangleIndices)!
        self.pointIndices = manager.makeBuffer(array: _pointIndices)!
        self.texcoords = manager.makeBuffer(array: _texcoords)!
        
    }
    
    func canAppend() -> Bool{
        return self.size - self.count >= 1
    }
    
    func fillColorAlpha() {
        guard count > 0 else { return }
        if let builder = MetalManager.shared.makeCommandBuilder() {
            try? builder.compute(name: "fillColorAlpha", count: count) { context in
                context.add(self.colors)
                context.add(self._showAccuracy ? Float(1) : .zero)
            }
            builder.commit()
        }
    }
    
    func append(_ frame: FrameMetadata) {
        let positions = base.map { frame.transform * $0 }
        
        positions.forEach { position in
            self._min.x = min(self._min.x, position.x)
            self._min.y = min(self._min.y, position.y)
            self._min.z = min(self._min.z, position.z)
            
            self._max.x = max(self._max.x, position.x)
            self._max.y = max(self._max.y, position.y)
            self._max.z = max(self._max.z, position.z)
        }
        
        boundingBox = (SCNVector3(self._min.x, self._min.y, self._min.z), SCNVector3(self._max.x, self._max.y, self._max.z))
        
        node?.boundingBox = boundingBox
        
        let positionOffset = size + count * linesPerCamera
        let lineOffset = count * linesPerCamera * 2
        let triangleOffset = count * trianglePerCamera * 3
        
        self.positions[count] = [positions[0].x, positions[0].y, positions[0].z]
        
        for i in 0..<linesPerCamera {
            let point = positions[i + 1]
            self.positions[positionOffset + i] = [point.x, point.y, point.z]
            
            let offset = lineOffset + i * 2
            lineIndices[offset] = UInt32(count)
            lineIndices[offset + 1] = UInt32(positionOffset + i)
        }
        
        triangleIndices[triangleOffset] = UInt32(positionOffset)
        triangleIndices[triangleOffset + 1] = UInt32(positionOffset + 1)
        triangleIndices[triangleOffset + 2] = UInt32(positionOffset + 2)
        
        triangleIndices[triangleOffset + 3] = UInt32(positionOffset + 2)
        triangleIndices[triangleOffset + 4] = UInt32(positionOffset + 3)
        triangleIndices[triangleOffset + 5] = UInt32(positionOffset)
        
        let rtkzAccuracy: RTKZAccuracyEnum?
        if frame.isRTK, let rtkVertical = frame.rtkLocation?.vertical {
            rtkzAccuracy = RTKZAccuracyEnum.from(value: rtkVertical)
        } else {
            rtkzAccuracy = nil
        }
        if frame.isRTK, let color = rtkzAccuracy?.rgb() {
            colors[count] = SIMD4<Float>(color, _showAccuracy ? 1 : 0)
        } else {
            colors[count] = [1, 0, 0, _showAccuracy ? 1 : 0]
        }
        
        count += 1
    }
    
    func makeSCNNode(_ live: Bool) -> SCNNode {
        
        if let _node = self.node {
            return _node
        }
        
        let positionSource = SCNGeometrySource(
            buffer: positions.buffer,
            vertexFormat: .float3,
            semantic: .vertex,
            vertexCount: positions.count,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float>>.stride
        )
        
        let colorSource = SCNGeometrySource(
            buffer: colors.buffer,
            vertexFormat: .float4,
            semantic: .color,
            vertexCount: colors.count,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD4<Float>>.stride
        )
        
        let texcoordSource = SCNGeometrySource(
            buffer: texcoords.buffer,
            vertexFormat: .float,
            semantic: .texcoord,
            vertexCount: texcoords.count,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.stride
        )
        
        let lineElement = SCNGeometryElement(buffer: lineIndices.buffer, primitiveType: .line, primitiveCount: size * linesPerCamera, bytesPerIndex: MemoryLayout<UInt32>.size)
        let triangleElement = SCNGeometryElement(buffer: triangleIndices.buffer, primitiveType: .triangles, primitiveCount: size * trianglePerCamera, bytesPerIndex: MemoryLayout<UInt32>.size)
        let pointElement = SCNGeometryElement(buffer: pointIndices.buffer, primitiveType: .point, primitiveCount: size, bytesPerIndex: MemoryLayout<UInt32>.size)
        
        pointElement.pointSize = cameraPointSize
        pointElement.minimumPointScreenSpaceRadius = cameraPointSize
        pointElement.maximumPointScreenSpaceRadius = cameraPointSize
        
        let geometry = SCNGeometry(sources: [positionSource, colorSource, texcoordSource], elements: [lineElement, triangleElement, pointElement])
        
        let material = SCNMaterial()
        material.isDoubleSided = true
        material.readsFromDepthBuffer = true
        material.writesToDepthBuffer = true
        material.shaderModifiers = [
            .fragment: """
                _output.color = vec4(0, 0, 1, 1.0);
                """
        ]
        
        let material2 = SCNMaterial()
        material2.isDoubleSided = true
        material2.lightingModel = .constant
        material2.readsFromDepthBuffer = true
        material2.writesToDepthBuffer = true
        material2.blendMode = .alpha
        material2.transparency = 0.5
        
        material2.shaderModifiers = [
            .fragment: """
                _output.color = vec4(0, 0, 1, 0.5);
                """
        ]
        
        let material3 = SCNMaterial()
        
        material3.isDoubleSided = true
        material3.readsFromDepthBuffer = true
        material3.writesToDepthBuffer = true
        
        geometry.materials = [material, material2, material3]
        
        self.node = SCNNode(geometry: geometry)
        
        node!.renderingOrder = 100
        
        return node!
    }
    
    func toggleVisible(_ visible: Bool) {
        node?.isHidden = !visible
    }
}

extension MetalManager {
    func makeCamera(size: Int, width: Float, height: Float, ratio: Float, showAccuracy: Bool = false) -> MetalCamera? {
        guard isReady else { return nil }
        return MetalCamera(manager: self, size: size, width: width, height: height, ratio: ratio, showAccuracy: showAccuracy)
    }
}
