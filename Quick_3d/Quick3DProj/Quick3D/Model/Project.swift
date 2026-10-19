//
//  Product.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 17/06/2022.
//

import Foundation

struct ProjectList: Decodable {
    let projects: [Project]
    let total: Int
    let hitsTotal: Int
}

struct Project: Decodable {
    // MARK: Core identity
    let id: String
    var name: String?
    let directory: String?
    let jobSiteId: String
    let userId: String?
    let numberOfImage: Int?

    // MARK: Status
    let status: StatusList?
    let useArMarker: Bool
    let useViDoc: Bool?
    let lidarEditing: String?
    let sfmEditing: String?
    let helmartEditing: String?

    // MARK: Dates
    let uploadTime: String
    let captureTime: String

    var uploadDate: Date { Project.parseDate(uploadTime) }
    var captureDate: Date { Project.parseDate(captureTime) }

    private static func parseDate(_ timeStr: String) -> Date {
        timeStr.toDate(format: Constant.rfcFormat, timeZone: .utc) ?? Date()
    }

    // MARK: Upload metadata
    let las_file: String?
    let ifc_file: String?
    let vertical: String?
    let horizontal: String?
    let ar_color: String?
    let design_file: String?
}
