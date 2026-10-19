//
//  RTKSearchingView.swift
//  Quick3D
//
//  Created by HaNST on 29/12/25.
//

import SwiftUI

struct RTKScanningView: View {
    @EnvironmentObject private var userManager: UserManager
    @State private var angle: Double = 0
    
    private let isPhone = UIDevice.current.userInterfaceIdiom == .phone
    private var radius: CGFloat { isPhone ? 130.5 : 144.5 }

    var body: some View {
        VStack {
            Spacer()
            ZStack {
                // Vòng tròn xoay
                Circle().stroke(skyBlue, lineWidth: 1)
                    .frame(width: radius * 2, height: radius * 2)

                Circle().fill(skyBlue)
                    .frame(width: 11, height: 11)
                    .offset(y: -radius)
                    .rotationEffect(.degrees(angle))

                // Nội dung Text
                VStack(spacing: 8) {
                    contentText("RTK_BLUETOOTH_DEVICE_MESSAGE_SEARCHING", isTitle: true)
                        .padding(.bottom, 8)
                    
                    contentText("RTK_BLUETOOTH_DEVICE_MESSAGE_POWER_ON")
                    
                    contentText("RTK_BLUETOOTH_DEVICE_MESSAGE_BLUETOOTH_ON")
                }
            }
            Spacer()
        }
        .onAppear {
            _ = ConnectivityMonitor.shared.isCurrentlyConnected()
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                angle = 360
            }
        }
    }

    private func contentText(_ key: String, isTitle: Bool = false) -> some View {
        Text(key.localized(userManager.userLanguage))
            .font(.system(size: isTitle ? (isPhone ? 18 : 24) : (isPhone ? 14 : 16)))
            .if(isTitle) { view in
                view.bold()
            }
            .foregroundColor(userManager.setting.textColor)
    }
}
