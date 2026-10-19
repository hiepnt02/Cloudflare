//
//  Color++.swift
//  Quick3D
//
//  Created by yoshiaki.kakinuma on 2023/12/28.
//

import SwiftUI

extension Color {
    
    static let colorBgDark = Color(hex: 0x3c3c3c)
    
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }

    func toHexString() -> String? {
        // UIColorに変換
        let uiColor = UIColor(self)

        // RGB値を取得
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // 各色を0-255の範囲に変換して16進数に変換
        let redInt = Int(red * 255)
        let greenInt = Int(green * 255)
        let blueInt = Int(blue * 255)
        let alphaFloat = Float(alpha)

        return String(format: "#%02X%02X%02X", redInt, greenInt, blueInt)
    }
    
    func getAlphaValue() -> Float {
        // UIColorに変換
        let uiColor = UIColor(self)

        // RGB値を取得
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let alphaFloat = Float(alpha)
        
        return alphaFloat
    }

}
