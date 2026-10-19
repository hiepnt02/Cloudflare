//
//  CameraOffsetEnum.swift
//  Quick3D
//
//  Created by HungNT on 14/3/25.
//

import Foundation

enum CameraOffsetEnum: String, CaseIterable, Identifiable, Codable {
    case SPC = "SPC"
    case SPCPlus = "SPC_PLUS"
    case CasetifySPCPlus = "CASETIFY_SPC_PLUS"
    case Custom = "CUSTOM"
    
    var id: String { self.rawValue }

    func displayName(_ language: String) -> String {
        switch self {
        case .SPC:
            return "SPC"
        case .SPCPlus:
            return "SPC+"
        case .CasetifySPCPlus:
            return "Casetify SPC+"
        case .Custom:
            return "RTK_CAMERA_OFFSET_CUSTOM".localized(language)
        }
    }
    
    init(string: String?) {
        switch string {
        case CameraOffsetEnum.SPC.rawValue:
            self = .SPC
        case CameraOffsetEnum.SPCPlus.rawValue:
            self = .SPCPlus
        case CameraOffsetEnum.CasetifySPCPlus.rawValue:
            self = .CasetifySPCPlus
        case CameraOffsetEnum.Custom.rawValue:
            self = .Custom
        default:
            self = .SPCPlus
        }
    }
}
