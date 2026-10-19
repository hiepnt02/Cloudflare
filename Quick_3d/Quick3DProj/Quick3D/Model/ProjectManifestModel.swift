//
//  ProjectManifestModel.swift
//  Quick3D
//
//  Created by HungNT on 4/6/25.
//

import Foundation

struct ProjectManifestModel: Decodable {
    let captured_data: CapturedData?
}

struct CapturedData: Decodable {
    let images: [ImageInfo]?
}

struct ImageInfo: Decodable {
    let photo: String?
}




