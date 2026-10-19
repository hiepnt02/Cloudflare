//
//  SmoothSettingView.swift
//  Quick3D
//
//  Created by HungNT on 11/5/26.
//

import Foundation
import SwiftUI
import Combine

struct SmoothSettingView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var pendingSettings: CapturePendingSettings

    @State private var maxSmoothingFrames: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("Max Smoothing Frames:")
                .font(.system(size: 16))
                .foregroundColor(userManager.setting.textColor)

            TextField("1", text: $maxSmoothingFrames)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
                .foregroundColor(userManager.setting.textColor)
                .multilineTextAlignment(.trailing)
                .onReceive(Just(maxSmoothingFrames)) { newValue in
                    var filtered = newValue.filter { "0123456789".contains($0) }
                    while filtered.hasPrefix("0") {
                        filtered.removeFirst()
                    }
                    if filtered != newValue {
                        self.maxSmoothingFrames = filtered
                    }
                }
                .onChange(of: maxSmoothingFrames) { newValue in
                    saveToSession(newValue)
                }
                .onChange(of: pendingSettings.saveToken) { _ in
                    if maxSmoothingFrames.isEmpty {
                        maxSmoothingFrames = "\(pendingSettings.smoothValue)"
                    }
                }
        }
        .padding(16)
        .background(userManager.setting.itemBgColor)
        .cornerRadius(8)
        .frame(maxWidth: .infinity)
        .onAppear {
            let initialValue = pendingSettings.smoothValue
            self.maxSmoothingFrames = initialValue > 0 ? "\(initialValue)" : "1"
        }
    }
    
    private func saveToSession(_ newValue: String) {
        if newValue.isEmpty {
            pendingSettings.smoothValue = 1
            return
        }
        if let value = Int(newValue), value > 0 {
            pendingSettings.smoothValue = value
        }
    }
}
