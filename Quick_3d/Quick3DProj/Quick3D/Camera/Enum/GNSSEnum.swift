//
//  GNSSEnum.swift
//  Quick3D
//
//  Created by HungNT on 30/12/25.
//

import Foundation

enum GNSSEnum: String, CaseIterable, Identifiable {
    case GPS
    case GALILEO
    case QZSS
    case GLONASS
    case BEIDOU
    
    var id: String { self.rawValue }
    
    var title: String {
        switch self {
        case .GPS:
            return "GPS"
        case .GALILEO:
            return "Galileo"
        case .QZSS:
            return "QZSS"
        case .GLONASS:
            return "GLONASS"
        case .BEIDOU:
            return "BeiDou"
        }
    }
}
