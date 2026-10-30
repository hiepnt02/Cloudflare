//
//  RTKRoverEnum.swift
//  Quick3D
//
//  Created by HungNT on 15/10/25.
//

import Foundation

// RTK Rover Device types
enum RTKRoverEnum: String, CaseIterable, Identifiable {
    case viDoc = "viDoc"
    case viDoc24 = "viDoc24"
    case viDocLight = "viDocLight"
    
    var id: String { self.rawValue }
}
