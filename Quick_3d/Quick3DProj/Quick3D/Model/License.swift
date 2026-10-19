//
//  License.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 09/06/2022.
//

import Foundation

struct License: Codable {
    let total: Int?
}

struct LicenseStatus: Codable {
    let numOfLicenses: Double?
    let isARAvailable: Bool?
}
