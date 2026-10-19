//
//  ThemeManager.swift
//  Quick3D
//
//  Created by yoshiaki.kakinuma on 2023/12/14.
//

import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    @Published var isDarkMode = true

    func toggleDarkMode() {
        isDarkMode.toggle()
    }
}
