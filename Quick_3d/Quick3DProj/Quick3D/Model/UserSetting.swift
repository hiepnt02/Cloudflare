//
//  UserSetting.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 22/05/2023.
//

import Foundation
import SwiftUI

struct UserSetting: Codable {
    var userId: String?
    var colorTheme: ColorThemeEnum = .light
    var coordinateSetting: Bool
//    var uploadCoordinateSetting: Bool
    var pointCloudBgcolor: String
    var pointCloudBgalpha: Double
    var linkDashboard: Bool
//    var uploadLinkDashboard: Bool
    var notifyByEmail: Bool
    
    var isTester: Bool
    
    func getColorThemeLabel(for userLanguage: String) -> String {
        return colorTheme.rawValue.localized(userLanguage)
    }
    
    //背景色
    var themeColor: Color {
        colorTheme == .light ? .white : .black
    }
    
    //ボディー
    var bodyColor: Color {
        colorTheme == .light ? platinumColor : raisinBlack
    }
    
    var itemBgColor: Color {
        colorTheme == .light ? pearlGrey : charcoalDark
    }
    
    var projectCellColor: Color {
        colorTheme == .light ? .white : jetBlack
    }
    
    //テキストColor用
    var textColor: Color {
        colorTheme == .light ? .black : .white
    }
    
    var subtileTextColor: Color {
        colorTheme == .light ? pearlGrey : charcoalDark
    }
    
    //アイコン
    var iconColor: Color {
        colorTheme == .light ? .black : .white
    }
    
    //ボタンカラーColor用
    var buttonColor: Color {
        colorTheme == .light ? electricBlue : .blue
    }
    
    //削除ボタンカラーColor用
    var deleteButtonColor: Color {
        materialRed
    }
    
    var dividerColor: Color {
        colorTheme == .light ? lightGray : blueCharcoal
    }
    
    //GPSRTKボタンカラーColor用
    // GPS:0 RTK:1
    func getGpsRtkButtonColor(_ mode: Int) -> Color {
        switch mode {
        case 0:
            return Color(hex: 0x4C6CB3);
        case 1:
            return Color(hex: 0x2E7D32);
        default:
            return .blue // デフォルトの色を指定
        }
    }
    
    // frame label color
    var labelColor: Color {
        colorTheme == .light ? dimGray : .gray
    }
    
    //ドロップダウンの背景色
    var dropdownColor: Color {
        colorTheme == .light ? .white : crowBlack
    }
    
    //グリッドセル
    var gridCellColor: Color {
        colorTheme == .light ? .white : .black
    }
    
    //グリッドセル
    var textFieldColor: Color {
        colorTheme == .light ? .white : .black
    }
    
    var textFieldBorderColor: Color {
        colorTheme == .light ? .black : .white
    }
    
    var buttonCameraColor: Color {
        amber
    }
    
    func toJson1() -> [String: Any] {
        var jsonDictionary: [String: Any] = [:]
        
        if let userId = userId {
            jsonDictionary["userId"] = userId
        }
        
        jsonDictionary["colorTheme"] = colorTheme.rawValue
        
        if !coordinateSetting {
            jsonDictionary["coordinateSetting"] = coordinateSetting
        }
        
        if pointCloudBgcolor != nil && !pointCloudBgcolor.isEmpty {
            jsonDictionary["pointCloudBgcolor"] = pointCloudBgcolor
        }
        
        if pointCloudBgalpha != 1.0 {
            jsonDictionary["pointCloudBgalpha"] = pointCloudBgalpha
        }
        
        if !linkDashboard {
            jsonDictionary["linkDashboard"] = linkDashboard
        }
        
        if !notifyByEmail {
            jsonDictionary["notifyByEmail"] = notifyByEmail
        }
        print("userId type: \(type(of: userId))")
        print("colorTheme type: \(type(of: colorTheme))")
        print("coordinateSetting type: \(type(of: coordinateSetting))")
        print("pointCloudBgcolor type: \(type(of: pointCloudBgcolor))")
        print("pointCloudBgalpha type: \(type(of: pointCloudBgalpha))")
        print("linkDashboard type: \(type(of: linkDashboard))")
        
        return jsonDictionary
    }
    
}
