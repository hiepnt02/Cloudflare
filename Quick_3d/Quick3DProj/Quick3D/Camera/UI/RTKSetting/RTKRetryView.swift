//
//  RTKSearchingView.swift
//  Quick3D
//
//  Created by HaNST on 29/12/25.
//
import SwiftUI

struct RTKRetryView: View {
    @EnvironmentObject private var userManager: UserManager
    
    var retry: (() -> Void)? = nil

    private let isIphone = UIDevice.current.isIphone

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            contentText("RTK_BLUETOOTH_DEVICE_MESSAGE_NOT_FOUND", isTitle: true)
                .padding(.bottom, 16)
            
            contentText("RTK_BLUETOOTH_DEVICE_MESSAGE_POWER_ON")
            
            contentText("RTK_BLUETOOTH_DEVICE_MESSAGE_BLUETOOTH_ON")
                .padding(.bottom, 24)
            
            NormalButton(
                label: "RTK_BLUETOOTH_DEVICE_MESSAGE_RETRY".localized(userManager.userLanguage),
                labelSize: 16,
                minHeight: 48,
                isStroke: true,
                onClick: { retry?() }
            )
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    private func contentText(_ key: String, isTitle: Bool = false) -> some View {
        Text(key.localized(userManager.userLanguage))
            .font(.system(size: isTitle ? (isIphone ? 18 : 24) : (isIphone ? 14 : 16)))
            .if(isTitle) { view in
                view.bold()
            }
            .foregroundColor(userManager.setting.textColor)
            .multilineTextAlignment(.center)
    }
}
