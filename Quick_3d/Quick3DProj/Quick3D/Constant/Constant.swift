//
//  Constant.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 21/04/2022.
//

import UIKit
import SwiftUI

enum AppEnvironment: String {
    case dev
    case stg
    case prod
}

let currentEnvironment: AppEnvironment = {
    let type = Bundle.main.object(forInfoDictionaryKey: "ENV_TYPE") as? String
    return AppEnvironment(rawValue: type ?? "dev") ?? .dev
}()
struct Constant {
    static let domainUrl: String = {
        switch currentEnvironment {
        case .dev:
            return "quick3d-dev.smartconstruction.com"
        case .stg:
            return "quick3d-stg.smartconstruction.com"
        case .prod:
            return "quick3d.smartconstruction.com"
        }
    }()
    
    static let licenseAssignUrl: String = {
        switch currentEnvironment {
        case .dev:
            return "https://portal-stg.smartconstruction.com/licenses/assign"
        case .stg:
            return "https://portal-stg.smartconstruction.com/licenses/assign"
        case .prod:
            return "https://portal.smartconstruction.com/licenses/assign"
        }
    }()
    
    static let accountManagerUrl: String = {
        switch currentEnvironment {
        case .dev:
            return "https://portal-stg.smartconstruction.com/user"
        case .stg:
            return "https://portal-stg.smartconstruction.com/user"
        case .prod:
            return "https://portal.smartconstruction.com/user"
        }
    }()
    
    static let addSiteUrl: String = {
        switch currentEnvironment {
        case .dev:
            return "https://portal-stg.smartconstruction.com/apps/sites/add/input"
        case .stg:
            return "https://portal-stg.smartconstruction.com/apps/sites/add/input"
        case .prod:
            return "https://portal.smartconstruction.com/apps/sites/add/input"
        }
    }()
  
    static let baseUrl = "https://\(domainUrl)/"
    static let webUrl = "https://\(domainUrl)/ios/"
    static let webARUrl = "https://\(domainUrl)/ios-ar/"
    static let jpDateFormat = "yyyy/MM/dd"
    static let otherDateFormat = "dd/MM/yyyy"
    
    static let jpTimeFormat = "yyyy/MM/dd HH:mm"
    static let globalTimeFormat = "dd/MM/yyyy HH:mm"
    
    static let timeFormat = "HH:mm"
    static let fullDateFormat = "yyyy/MM/dd HH:mm"
    static let rfcFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    static let appstoreURL = "itms-apps://apple.com/app/id1627645913"
    static let llvURL = "https://web.viewer.landlog.info/organization/2Zbj4V1ZWXL3dwobBySX01/site/"

    // MARK: - Help / legal URLs
    private static let supportUrlJa = "https://support-quick3d.smartconstruction.com/hc/ja"
    private static let supportUrlEn = "https://support-quick3d.smartconstruction.com/hc/en-us"
    private static let termsOfUseUrlJa = "https://terms.smartconstruction.com/jp/terms-of-use"
    private static let termsOfUseUrlGlobal = "https://terms.smartconstruction.com/na/terms-of-use"

    static let userManualUrl = URL(string: "https://support-quick3d.smartconstruction.com/hc/ja/articles/11060723222937--Smart-Construction-Quick3D-%E3%83%A6%E3%83%BC%E3%82%B6%E3%83%BC%E3%82%AC%E3%82%A4%E3%83%89")

    /// Japanese users get the JA help center, everybody else the global one.
    static func supportUrl(for language: String) -> URL? {
        URL(string: language == LanguageMode.ja.rawValue ? supportUrlJa : supportUrlEn)
    }

    static func termsOfUseUrl(for language: String) -> URL? {
        URL(string: language == LanguageMode.ja.rawValue ? termsOfUseUrlJa : termsOfUseUrlGlobal)
    }
}

extension Notification.Name {
    static let updateCell = Notification.Name(rawValue: "Update Cell")
}

// MARK: Colors Palette
let platinumColor: Color = Color(hex: 0xECEDEE)

let raisinBlack: Color = Color(hex: 0x17171a)
let jetBlack: Color = Color(hex: 0x1e1e1e)

let materialRed: Color = Color(hex: 0xf44336)
let rubyRed: Color = Color(hex: 0xC62828)
let vibrantPeach: Color = Color(hex: 0xf9665a)

let sunburst = Color.init(hex: 0xf9c42e)

let lightGray: Color = Color(hex: 0xD6D7DB)
let dimGray: Color = Color(hex: 0x575757)
let abbeyGray: Color = Color(hex: 0x51545D)
let bombayGray: Color = Color(hex: 0xB5B8BF)
let slateGrey: Color = Color(hex: 0x8C909B)
let pearlGrey: Color = Color(hex: 0xF4F5F5)
let steelGray: Color = Color(hex: 0x6B6F7B)
let grey: Color = Color(hex: 0x757575)
let charcoalDark: Color = Color(hex: 0x2F3137)
let blueCharcoal: Color = Color(hex: 0x251545D)

let crowBlack: Color = Color(hex: 0x202020)
let amber: Color = Color(hex: 0xffb800)

let electricBlue: Color = Color(hex: 0x2F24E6)
let electricViolet: Color = Color(hex: 0x736CED)
let lavender: Color = Color(hex: 0xE5E4FB)
let imperialBlue: Color = Color(hex: 0x1F3366)
let sapphireBlue: Color = Color(hex: 0x0064BA)
let steelBlue: Color = Color(hex: 0x0E1A33)
let darkNavy: Color = Color(hex: 0x0D0765)
let skyBlue: Color = Color(hex: 0x42A5F5)
let denimBlue: Color = Color(hex: 0x1976D2)

let mintBreeze = Color.init(hex: 0x68eeac)
let pineGreen = Color(hex: 0x167E1E)

let orange: Color = Color(hex: 0xFF9800)
