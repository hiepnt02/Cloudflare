//
//  CameraOffsetEnum.swift
//  Quick3D
//
//  Created by HungNT on 14/3/25.
//

import Foundation

enum CameraOffsetEnum: String, CaseIterable, Identifiable {
    case SPC = "SPC"
    case SPCPlus = "SPC_PLUS"
    case CasetifySPCPlus = "CASETIFY_SPC_PLUS"
    case Custom = "CUSTOM"
    
    var id: String { self.rawValue }
    
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
