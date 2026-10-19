//
//  ColorThemeEnum.swift
//  Quick3D
//
//  Created by HungNT on 22/12/25.
//

import Foundation

enum ColorThemeEnum: String, Decodable, Encodable {
    case light = "light"
    case dark = "dark"
}

extension ColorThemeEnum {
    static func from(_ string: String) -> ColorThemeEnum {
        return ColorThemeEnum(rawValue: string) ?? .light
    }
}
