//
//  LanguageMode.swift
//  Quick3D
//
//  Created by HungNT on 20/5/26.
//

import Foundation

enum LanguageMode: String, CaseIterable {
    case cs     // チェコ語
    case de     // ドイツ語
    case fr     // フランス語
    case en     // 英語
    case ja     // 日本語
    
    var symbol: String {
        switch self {
        case .cs: return "cz"
        default: return self.rawValue
        }
    }
    
    var title: String {
        switch self {
        case .ja: return "日本語"
        case .en: return "English"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .cs: return "český jazyk"
        }
    }
}
