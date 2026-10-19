//
//  LanguageChangeObserver.swift
//  Quick3D
//
//  Created by HungNT on 27/3/25.
//

import Foundation
import UIKit
import SwiftUI

class LanguageChangeObserver: ObservableObject {
    @Published var currentLanguages: [String] = Locale.preferredLanguages
    @Published var currentLanguage: String = ""

    init() {
        observeLanguageChanges()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSLocale.currentLocaleDidChangeNotification, object: nil)
    }

    private func observeLanguageChanges() {
        NotificationCenter.default.addObserver(self, selector: #selector(localeDidChange), name: NSLocale.currentLocaleDidChangeNotification, object: nil)
    }

    @objc func localeDidChange() {
        currentLanguages = Locale.preferredLanguages
        currentLanguage = currentLanguages.first ?? ""
        // Now, the @Published property will trigger updates in any SwiftUI views using it.
    }
}
