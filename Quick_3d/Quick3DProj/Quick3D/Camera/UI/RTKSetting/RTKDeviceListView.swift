//
//  RTKSearchingView.swift
//  Quick3D
//
//  Created by HaNST on 29/12/25.
//

import SwiftUI
import CoreBluetooth

struct RTKDeviceListView: View {
    @EnvironmentObject private var userManager: UserManager
    
    @EnvironmentObject private var rtk: RTKStateObject
    
    @State private var deviceSelected: CBPeripheral?
    @State private var isConnecting = false
    
    let devices: [CBPeripheral]
    
    var selection: ((String, UUID) -> Void)? = nil

    private let isIphone = UIDevice.current.isIphone
    
    private var selectionColors: (bg: Color, border: Color) {
        let isLight = userManager.setting.colorTheme == .light
        return (isLight ? denimBlue.opacity(0.12) : sapphireBlue,
                isLight ? sapphireBlue : skyBlue)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(
                "RTK_BLUETOOTH_DEVICE_MESSAGE_FOUND".localized(
                    userManager.userLanguage
                )
            )
            .font(.system(size: 16).bold())
            .foregroundColor(userManager.setting.textColor)
            .padding(.horizontal, contentPadding)
            
            ScrollView(showsIndicators: false) {
                contentView
            }
            
            if isIphone {
                Divider().background(lightGray)
            }
            
            LoadingButton(
                label: String(
                    format: "RTK_BLUETOOTH_DEVICE_CONNECT_TO"
                        .localized(userManager.userLanguage),
                    deviceSelected?.name ?? ""
                ),
                isShowLoading: $isConnecting,
                onClick: {
                    if !isConnecting,
                       let device = deviceSelected {
                        isConnecting = true
                        selection?(device.name ?? "", device.identifier)
                    }
                }
            )
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .onAppear { deviceSelected = devices.first }
    }

    private var contentView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 1)
            ForEach(devices, id: \.self) { itemVidoc(for: $0) }
            
            VStack(spacing: 5) {
                ForEach(1...3, id: \.self) { i in
                    Text(
                        "RTK_BLUETOOTH_DEVICE_MESSAGE_LIST_NOTE_\(i)".localized(
                            userManager.userLanguage
                        )
                    )
                    .font(.system(size: 14))
                    .foregroundColor(userManager.setting.textColor)
                    .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.horizontal, popupHPadding)
        .padding(.vertical, 16)
    }

    private func itemVidoc(for device: CBPeripheral) -> some View {
        let isSelected = deviceSelected == device
        let name = device.name ?? ""
        let identifier = device.identifier
        
        return VStack {
            Text(name).font(.system(size: 32))
            if identifier == RTKManager.shared.lastVidocConnected {
                Text(
                    "RTK_BLUETOOTH_DEVICE_MESSAGE_LIST_LAST_CONNECTED".localized(
                        userManager.userLanguage
                    )
                )
                .font(.system(size: 12))
            }
        }
        .foregroundColor(userManager.setting.textColor)
        .frame(maxWidth: .infinity, minHeight: 172)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? selectionColors.bg : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? selectionColors.border : lightGray,
                    lineWidth: 2
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { deviceSelected = device }
    }
}
