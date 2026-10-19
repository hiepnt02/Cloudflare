//
//  TengunApp.swift
//  Tengun
//
//  Created by 木皿直規 on 2022/02/08.
//

import SwiftUI

@main

struct TengunApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// 左寄せ
extension View {
    func leftAligned() -> some View {
        return self.modifier(LeftAligned())
    }
}

struct LeftAligned: ViewModifier {
    func body(content: Content) -> some View {
        HStack {
            content
            Spacer()
        }
    }
}

