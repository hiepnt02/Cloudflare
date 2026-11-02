//
//  ProjectDetail.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 17/05/2022.
//

import Foundation

struct ProjectDetail: Decodable {
    let status: StatusList?
    let id: String
    let name: String?
    let gsx_file: String?

    var gsxFileName: String? {
        guard let name = gsx_file?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty, !name.hasSuffix("/") else { return nil }
        let last = (name as NSString).lastPathComponent
        return last.isEmpty || last == "." || last == ".." || last == "/" ? nil : last
    }
}
