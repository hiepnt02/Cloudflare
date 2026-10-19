//
//  UserSession.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 21/04/2022.
//

import Foundation
import KeychainAccess
import UIKit

class UserSession {
    static let shared = UserSession()
    private let keychain = Keychain(service: "ltd.landlog.scquick3d")
    private var cacheThumbnail = [String: UIImage]()
    
    static var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    
    var userInfo: UserInfo? {
        get {
            guard
                let jsonString = try? keychain.getString("userInfo"),
                let jsonData = jsonString.data(using: .utf8),
                let user = try? JSONDecoder().decode(UserInfo.self, from: jsonData)
            else {
                return nil
            }
            return user
        }
        set {
            guard let newValue = newValue else {
                try? keychain.remove("userInfo")
                return
            }
            guard 
                let jsonData = try? JSONEncoder().encode(newValue),
                let jsonString = String(data: jsonData, encoding: .utf8)
            else {
                return
            }
            try? keychain.set(jsonString, key: "userInfo")
        }
    }
    
    var sessionId: String? {
        set {
            guard let sessionId = newValue else {
                try? keychain.remove("sessionId")
                return
            }
            try? keychain.set(sessionId, key: "sessionId")
        }
        get {
            try? keychain.getString("sessionId")
        }
    }

    var cookies: [HTTPCookie]? {
        set {
            guard
                let cookies = newValue,
                let data = try? NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: false)
            else {
                try? keychain.remove("cookiesKey")
                return
            }
            try? keychain.set(data, key: "cookiesKey")
        }
        get {
            guard
                let data = try? keychain.getData("cookiesKey"),
                let cookies = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [HTTPCookie]
            else {
                return nil
            }
            return cookies
        }
    }
    
    static var products: [Cat] {
        set {
            guard
                let jsonData = try? JSONEncoder().encode(newValue),
                let jsonString = String(data: jsonData, encoding: .utf8)
            else {
                return
            }
            UserDefaults.standard.set(jsonString, forKey: "products")
            UserDefaults.standard.synchronize()
        }
        get {
            guard
                let jsonString = UserDefaults.standard.object(forKey: "products") as? String,
                let jsonData = jsonString.data(using: .utf8),
                let datas = try? JSONDecoder().decode([Cat].self, from: jsonData)
            else {
                return []
            }
            return datas
        }
    }

    func cacheThumbnail(for projectId: String) -> UIImage? {
        cacheThumbnail[projectId]
    }

    func saveCacheThumbnail(_ image: UIImage, for projectId: String) {
        cacheThumbnail[projectId] = image
    }

    static var sortOption: SortOption {
        set {
            UserDefaults.standard.set(newValue == .uploadDate ? "uploadDate" : "capturedDate", forKey: "sortOptionKey")
        }
        get {
            UserDefaults.standard.string(forKey: "sortOptionKey") == "uploadDate" ? .uploadDate : .capturedDate
        }
    }

    static var userLanguage: String {
        set {
            UserDefaults.standard.set(newValue, forKey: "languageKey")
        }
        get {
//            guard let lang = UserDefaults.standard.string(forKey: "languageKey") else {
//                let currentLang = Locale.current.languageCode ?? "en"
//                let langMode = (LanguageMode(rawValue: currentLang) ?? .en).rawValue
//                self.userLanguage = langMode
//                return langMode
//            }

//            本体設定による言語決定
            for langRegion in NSLocale.preferredLanguages {
                guard let lang = langRegion.components(separatedBy: "-").first
                else { continue }
                
                guard let langMode = LanguageMode(rawValue: lang)
                else { continue }
                
                return langMode.rawValue
            }
            
            return "en"
        }
    }
}
