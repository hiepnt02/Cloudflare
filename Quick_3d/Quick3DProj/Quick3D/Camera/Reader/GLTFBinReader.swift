//
//  BinReader.swift
//  Quick3D
//
//  Created by Admin on 27/10/25.
//

import Foundation

class GLTFBinReader {
    private let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    func getFloat(_ data: Data, offset: Int) -> Float {
        let bytes = Data(data[offset...offset+3].reversed())
        let floatValue: Float = Float(bitPattern: UInt32(bigEndian: bytes.withUnsafeBytes { $0.load(as: UInt32.self) }))
        return floatValue
    }
    
    func read() throws -> (points: [SIMD3<Float>], colors: [SIMD3<Float>]) {
        let binaryData = try Data(contentsOf: url)
        let size = binaryData.count / 24
        
        var points: [SIMD3<Float>] = []
        var colors: [SIMD3<Float>] = []
        
        for i in 0..<size {
            let offset = i * 24
            let x = getFloat(binaryData, offset: offset)
            let y = getFloat(binaryData, offset: offset+4)
            let z = getFloat(binaryData, offset: offset+8)
            let r = getFloat(binaryData, offset: offset+12)
            let g = getFloat(binaryData, offset: offset+16)
            let b = getFloat(binaryData, offset: offset+20)
            
            points.append([x, z, -y])
            colors.append([r, g, b])
        }
        
        return (points, colors)
    }
}
