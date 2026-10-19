//
//  VidocData.swift
//  Quick3D
//
//  Created by HungNT on 2/1/25.
//

import Foundation

struct CoodinateSystemJobsite: Decodable, Hashable {
    var conditionFlag: Bool
    var horizontal: String?
    var vertical: String?
    
    var rotation: Double?
    var originEasting: Double?
    var originNorthing: Double?
    var originLatitude: Double?
    var originLongitude: Double?
    var scaleFactor: Double?
    var verticalOffset: Double?
    var useViDoc: Double?
    var inclineX: Double?
    var inclineY: Double?
    var conversionLock: Bool?
}
