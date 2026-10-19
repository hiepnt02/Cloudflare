//
//  PositioningMode.swift
//  Quick3D
//
//  Created by HungNT on 4/6/26.
//

import SwiftUI

enum PositioningMode: Int {
    case gps = 0
    case rtk = 1
    
    var buttonColor: Color {
        switch self {
        case .gps: return Color(hex: 0x4C6CB3)
        case .rtk: return Color(hex: 0x2E7D32)
        }
    }
}
