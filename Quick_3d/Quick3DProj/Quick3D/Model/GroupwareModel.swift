//
//  GroupwareModel.swift
//  Quick3D
//
//  Created by HungNT on 26/8/25.
//

import Foundation

struct GroupwareResponse: Decodable, Hashable {
    var filesDashboard: [GroupwareModel]?
    var filesDesign: [GroupwareModel]?
}

struct GroupwareModel: Decodable, Hashable {
    var bucketId: String
    var nodeId: String
    var name: String
    var key: String
    var size: String
    var path: String
}
