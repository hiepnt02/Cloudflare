//
//  BVHModel.swift
//  Test4
//
//  Created by HaNST on 13/1/26.
//

import Foundation

struct BVHData: Codable {
    let point: String
    let color: String
    
    init(point: String, color: String) {
        self.point = point
        self.color = color
    }
    
    init(_ data: BVHData) {
        self.point = data.point
        self.color = data.color
    }
}

struct BVHDataResp: Codable {
    let meta: String
    let levels: [[BVHData]]
}

struct BVHMetadataResp: Codable {
    let offset: [Double]
    let root: BVHMetadataItem
    
    func getOffset() -> SIMD3<Double> {
        SIMD3(x: offset[0], y: offset[2], z: -offset[1])
    }
}

struct BVHMetadataItem: Codable {
    let id: Int
    let url: String
    let size: Int
    let children: [BVHMetadataItem]
    
    func getTotal(level: Int, current: Int = -1) -> Int {
        if current > level { return 0 }
        let childrenSize = children.map { $0.getTotal(level: level, current: current + 1) }.reduce(0, +)
        return size + childrenSize
    }
}

struct BVHAsyncResult {
    let min: SIMD3<Float>
    let max: SIMD3<Float>
    let flag: Bool
    let error: Error?

    init(min: SIMD3<Float>, max: SIMD3<Float>) {
        self.min = min
        self.max = max
        self.flag = true
        self.error = nil
    }
    
    init(error: Error) {
        self.min = .zero
        self.max = .zero
        self.flag = false
        self.error = error
    }
}

enum BVHReadError: Error {
    case dataReadFailed(Error)
    case invalidDataSize(Int)
    case dataWasNil
}
