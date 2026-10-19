//
//  SetImageResolutionView.swift
//  Quick3D
//
//  Created by HungNT on 17/9/25.
//

import SwiftUI
import ARKit

struct ResolutionSettingView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var pendingSettings: CapturePendingSettings

    @State private var listResolutions: [ImageResolutionEnum] = []
    @State private var currentResolution: ImageResolutionEnum = ImageResolutionEnum.normal
    
    private var selectedStrokeColor: Color {
        userManager.setting.colorTheme == .light ? sapphireBlue : skyBlue
    }
    
    private var strokeColor: Color {
        userManager.setting.colorTheme == .light ? .black : slateGrey
    }
    
    var body: some View {
        VStack {
            VStack {
                Text("RESOLUTION".localized(userManager.userLanguage))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(userManager.setting.textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(listResolutions, id: \.self) { element in
                    VStack {
                        itemSelectResolution(
                            itemType: element,
                            currentType: $currentResolution
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(userManager.setting.itemBgColor)
            .cornerRadius(8)
            .frame(alignment: .leading)
            .onAppear {
                currentResolution = pendingSettings.imageResolution
            }
            .onLoad {
                checkResolutionSupport()
            }
        }
    }
    
    private func itemSelectResolution(
        itemType: ImageResolutionEnum,
        currentType: Binding<ImageResolutionEnum>
    ) -> some View {
        let title = switch itemType {
        case .normal:
            "NORMAL".localized(userManager.userLanguage)
        case .fourK:
            "4K"
        case .maximum:
            "MAXIMUM_RESOLUTION".localized(userManager.userLanguage)
        }
        
        return HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(userManager.setting.textColor)
                .padding(.leading, 16)
            
            Spacer()

            ZStack {
                Circle()
                    .stroke(itemType == currentType.wrappedValue ? selectedStrokeColor : strokeColor, lineWidth: 1)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(userManager.setting.itemBgColor))
                if itemType == currentType.wrappedValue {
                    Circle()
                        .fill(selectedStrokeColor)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .frame(height: 30)
        .contentShape(Rectangle())
        .onTapGesture {
            currentType.wrappedValue = itemType
            pendingSettings.imageResolution = itemType
        }
    }
    
    private func checkResolutionSupport() {
        let availableFormats = ARWorldTrackingConfiguration.supportedVideoFormats
        // Get ARKit's default video format, usually 1920x1080.
        if let _ = CameraVideoFormatHelper.videoFromats[.normal] {
            listResolutions.append(.normal)
        }
        
        // Find 4K format (3840x2160)
        if let _ = CameraVideoFormatHelper.videoFromats[.fourK] {
            listResolutions.append(.fourK)
        }
        
        // Get the highest resolution format
        if let _ = CameraVideoFormatHelper.videoFromats[.maximum] {
            listResolutions.append(.maximum)
        }
    }
}
