//
//  Pix4DCloudData.swift
//  Quick3D
//
//  Created by ryoma.terai on 2024/08/20.
//

import Foundation

struct Pix4DCloudData: Codable {
    let id: String
    let name: String
    let features: Features
    let settings: Settings
    let iat: Int
    let exp: Int
}

func strRTKLabel (rtkValue: Int) -> String {
    if (rtkValue == 0) {
        return "GPS";
    } else if (rtkValue == 1) {
        return "RTK";
    } else {
        return "GPS RTK";
    }
};

struct RTKOffset: Codable {
    let value: [Float]
    let device: String
}

struct ExportSettings: Codable {
    let exportAfterSave: Bool
}

struct Offsets: Codable {
    let rtkOffsets: [RTKOffset]?
    let caseName: String
}

struct Overlap: Codable {
    let percentage: Int
}

struct Triggering: Codable {
    let overlap: Overlap
}

struct Settings: Codable {
    let export: ExportSettings
    let offsets: Offsets?
    let triggering: Triggering
}

struct Features: Codable {
    let cloud: Cloud
}

struct Cloud: Codable {
    let cloudCrs: CloudCrs
    let cloudUrl: String
}

struct CloudCrs: Codable {
    let wkt: String
}
