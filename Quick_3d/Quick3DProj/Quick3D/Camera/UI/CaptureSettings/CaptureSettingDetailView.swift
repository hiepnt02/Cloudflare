//
//  DetailCaptureSetting.swift
//  Quick3D
//
//  Created by Admin on 5/1/26.
//

import SwiftUI

struct CaptureSettingDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var pendingSettings: CapturePendingSettings

    @State private var isShowMovement: Bool = false
    @State private var isEnableAlertSound: Bool = true
    @State private var isShowFeaturePoints: Bool = false
    @State private var isShowResolution: Bool = false
    @State private var isShowOverlap: Bool = false
    @State private var currentPreviewMode: PreviewEnum = .personView
    @State private var isEnableMesh: Bool = true
    @State private var isSaveMesh: Bool = false
    @State private var isEnableLog: Bool = false
    
    private var selectedStrokeColor: Color {
        userManager.setting.colorTheme == .light ? sapphireBlue : skyBlue
    }
    private var strokeColor: Color {
        userManager.setting.colorTheme == .light ? .black : slateGrey
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            if (!UIDevice.current.isIphone) {
                SubBackButton(
                    title: "CAPTURE_SETTING".localized(userManager.userLanguage),
                    onBack: {
                        dismiss()
                    }
                )
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    alertSettingView()
                        .padding(.top, 16)
                                        
                    displaySettingView()
                                        
                    livePreviewMode()
                                        
                    meshSettingView()

                    if currentEnvironment == .dev {
                        logSettingView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationBarBackButtonHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, contentPadding)
    }
    
    private func horizontalDivider() -> some View {
        Divider().frame(height: 1).background(userManager.setting.dividerColor)
            .padding(.horizontal, 4)
    }
    
    private func alertSettingView() -> some View {
        VStack {
            Text("ALERT_SETTINGS".localized(userManager.userLanguage))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(slateGrey)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ItemSettingToggleView(
                title: "SHOW_MOVEMENT_UI".localized(userManager.userLanguage),
                isOn: $isShowMovement
            )

            ItemSettingToggleView(
                title: "ALERT_SOUND".localized(userManager.userLanguage),
                isOn: $isEnableAlertSound
            )
        }
        .padding(.horizontal, 4)
        .cornerRadius(8)
        .onLoad {
            isShowMovement = pendingSettings.isShowMovement
            isEnableAlertSound = pendingSettings.isEnableAlertSound
        }
        .onChange(of: isShowMovement) { newValue in
            pendingSettings.isShowMovement = isShowMovement
        }
        .onChange(of: isEnableAlertSound) { newValue in
            pendingSettings.isEnableAlertSound = isEnableAlertSound
        }
    }
    
    private func displaySettingView() -> some View {
        VStack {
            horizontalDivider()
            
            Text("SHOW".localized(userManager.userLanguage))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(slateGrey)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ItemSettingToggleView(
                title: "FEATURE_POINTS".localized(userManager.userLanguage),
                isOn: $isShowFeaturePoints
            )
            
            ItemSettingToggleView(
                title: "RESOLUTION".localized(userManager.userLanguage),
                isOn: $isShowResolution
            )
            
            ItemSettingToggleView(
                title: "Overlap".localized(userManager.userLanguage),
                isOn: $isShowOverlap
            )
        }
        .padding(.horizontal, 4)
        .cornerRadius(8)
        .onLoad {
            isShowFeaturePoints = pendingSettings.isShowFeaturePoints
            isShowResolution = pendingSettings.isShowResolution
            isShowOverlap = pendingSettings.isShowOverlap
        }
        .onChange(of: isShowFeaturePoints) { newValue in
            pendingSettings.isShowFeaturePoints = isShowFeaturePoints
        }
        .onChange(of: isShowResolution) { newValue in
            pendingSettings.isShowResolution = isShowResolution
        }
        .onChange(of: isShowOverlap) { newValue in
            pendingSettings.isShowOverlap = isShowOverlap
        }
    }
    
    private func livePreviewMode() -> some View {
        VStack {
            horizontalDivider()
            
            Text("LIVE_PREVIEW_MODE".localized(userManager.userLanguage))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(slateGrey)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            itemSelectPreviewMode(
                title: "FIRST_PERSON_VIEW".localized(userManager.userLanguage),
                mode: .personView
            )
            
            itemSelectPreviewMode(
                title: "TOP_VIEW".localized(userManager.userLanguage),
                mode: .topView
            )
        }
        .padding(.horizontal, 4)
        .cornerRadius(8)
        .onLoad {
            currentPreviewMode = pendingSettings.previewMode
        }
    }
    
    private func itemSelectPreviewMode(
        title: String,
        mode: PreviewEnum
    ) -> some View {
        return HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(userManager.setting.textColor)
            
            Spacer()

            ZStack {
                Circle()
                    .stroke(mode == currentPreviewMode ? selectedStrokeColor : strokeColor, lineWidth: 1)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(userManager.setting.itemBgColor))
                if mode == currentPreviewMode {
                    Circle()
                        .fill(selectedStrokeColor)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(UIDevice.current.isIphone ? 0 : 12)
        .padding(.trailing, UIDevice.current.isIphone ? 4 : 0)
        .frame(height: UIDevice.current.isIphone ? 30 : 70)
        .background(UIDevice.current.isIphone ? Color.clear : userManager.setting.itemBgColor)
        .cornerRadius(UIDevice.current.isIphone ? 0 : 8)
        .onTapGesture {
            currentPreviewMode = mode
            pendingSettings.previewMode = mode
        }
    }
    
    private func meshSettingView() -> some View {
        VStack {
            horizontalDivider()
            
            Text("MESH".localized(userManager.userLanguage))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(slateGrey)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ItemSettingToggleView(
                title: "ENABLE_MESH".localized(userManager.userLanguage),
                isOn: $isEnableMesh
            )
            
//            ItemSettingToggleView(
//                title: "SAVE_MESH".localized(userManager.userLanguage),
//                isOn: $isSaveMesh
//            )
        }
        .padding(.horizontal, 4)
        .cornerRadius(8)
        .onLoad {
            isEnableMesh = pendingSettings.isEnableMesh
            isSaveMesh = pendingSettings.isSaveMesh
        }
        .onChange(of: isEnableMesh) { newValue in
            pendingSettings.isEnableMesh = isEnableMesh
        }
        .onChange(of: isSaveMesh) { newValue in
            pendingSettings.isSaveMesh = isSaveMesh
        }
    }

    private func logSettingView() -> some View {
        VStack {
            horizontalDivider()

            Text("DEBUG".localized(userManager.userLanguage))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(slateGrey)
                .frame(maxWidth: .infinity, alignment: .leading)

            ItemSettingToggleView(
                title: "CAPTURE_LOG".localized(userManager.userLanguage),
                isOn: $isEnableLog
            )
        }
        .padding(.horizontal, 4)
        .cornerRadius(8)
        .onLoad {
            isEnableLog = pendingSettings.isEnableLog
        }
        .onChange(of: isEnableLog) { newValue in
            pendingSettings.isEnableLog = isEnableLog
        }
    }
}
