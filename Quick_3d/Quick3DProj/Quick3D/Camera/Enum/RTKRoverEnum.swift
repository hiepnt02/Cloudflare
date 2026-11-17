//
//  RTKRoverEnum.swift
//  Quick3D
//
//  Created by HungNT on 15/10/25.
//

import Foundation

// RTK Rover Device types
enum RTKRoverEnum: String, CaseIterable, Identifiable, Codable {
    case viDoc = "viDoc"
    case viDoc24 = "viDoc24"
    case viDocLight = "viDocLight"
    
    var id: String { self.rawValue }

    /// Nhãn hiển thị của rover. Không dịch — đây là tên thương mại.
    var displayName: String {
        switch self {
        case .viDoc:
            return "viDoc"
        case .viDoc24:
            return "viDoc 24"
        case .viDocLight:
            return "viDoc Light"
        }
    }
}
