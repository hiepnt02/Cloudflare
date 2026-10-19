//
//  ProjectUploadModel.swift
//  Quick3D
//
//  Created by HungNT on 4/3/25.
//

import Foundation

struct ProjectUploadModel {
    let jobsiteId: String
    let useARMarker: Bool
    let coordinateSetting: Bool
    let linkDashboard: Bool
    let shouldInterpolate: Bool
    let url: URL?
    let cat: Cat?
}
