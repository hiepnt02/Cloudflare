//
//  CaptureSetting.swift
//  Quick3D
//
//  Created by Admin on 30/12/25.
//

import SwiftUI

struct CaptureSettingView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var pendingSettings: CapturePendingSettings

    var pushDetail: (() -> Void)? = nil

    var body: some View {
        ScrollView(showsIndicators: true) {
            contentView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var contentView: some View {
        VStack(alignment: .leading) {
            captureGuide
                .padding(.bottom, 16)
            
            ResolutionSettingView()
                .padding(.bottom, 8)
            
            OverlapSettingView()
                .padding(.bottom, 8)
            
            if currentEnvironment == .dev {
                RatioSettingView()
                    .padding(.bottom, 8)
                
                SmoothSettingView()
                    .padding(.bottom, 8)
            }
            
            Text("OVERLAP_DESC".localized(userManager.userLanguage))
                .font(.system(size: 12))
                .foregroundColor(userManager.setting.textColor.opacity(0.5))
                .padding(.bottom, 16)
            
            Button(action: {
                pushDetail?()
                hideKeyboard()
            }) {
                HStack {
                    Text("DETAIL_CAPTURE_SETTING".localized(userManager.userLanguage))
                        .font(.system(size: 16))
                        .foregroundColor(userManager.setting.textColor)
                    
                    Spacer()
                    
                    Image("ic_arrow_down_white")
                        .renderingMode(.template)
                        .resizable()
                        .foregroundColor(userManager.setting.iconColor)
                        .frame(width: 16, height: 16)
                        .rotationEffect(.degrees(-90))
                }
                .frame(height: 20)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Spacer()
                .frame(height: 30)
        }
        .padding(contentPadding)
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    private var captureGuide: some View {
        VStack(alignment: .leading) {
            Text("CAPTURE_SETTING".localized(userManager.userLanguage))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(userManager.setting.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
            
            Text("CAPTURE_SETTING_DESC".localized(userManager.userLanguage))
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(userManager.setting.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(contentPadding)
        .cornerRadius(16)
        .overlay(
            RoundedCorner(radius: 16)
                .stroke(userManager.setting.textColor, lineWidth: 1)
        )
    }
}
