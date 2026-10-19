//
//  Thumbnail.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 18/06/2022.
//

import Foundation

struct Thumbnail: Decodable {
    let name: String
    let data: String
}

struct ThumbnailURL: Decodable {
    let url: String
}
