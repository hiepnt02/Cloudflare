//
//  RTKSearchingView.swift
//  Quick3D
//
//  Created by HaNST on 29/12/25.
//

import SwiftUI
import CoreBluetooth

struct RTKDeviceNTRIPView: View {
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var rtk: RTKStateObject
    
    @Binding var isShowMountpoints: Bool
    @Binding var isShowCoordinates: Bool
    @Binding var isProviderExpanded: Bool
    
    @StateObject private var popoverManager = PopoverManager()
    
    private let isIphone = UIDevice.current.isIphone
    
    @State private var inputItemWidth: CGFloat = 0
    @State private var isShowingAlert = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    
    private var providerPulldownWidth: CGFloat {
        guard !isIphone, inputItemWidth > 0 else {
            return NtripProviderOptionsView.pulldownWidth
        }
        
        return inputItemWidth
    }
    
    private var isMountpointValid: Bool {
        rtk.isNtripMountpointStatus
    }
    
    private var isCoordinateValid: Bool {
        rtk.isNtripCoordinateSystemStatus
    }
    
    private let statusIconSize: CGFloat = 16
    
    @ViewBuilder
    private var ntripStatusIcon: some View {
        if rtk.isMountpointsFetching {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(userManager.setting.textColor)
                .scaleEffect(0.8)
        } else if rtk.ntripError != nil {
            Image("ic_exclamation")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(vibrantPeach)
        } else if rtk.isNtripProviderStatus {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: statusIconSize))
                .foregroundColor(mintBreeze)
        } else {
            Color.clear
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("NTRIP")
                    .font(.system(size: 16))
                    .foregroundColor(slateGrey)
                
                ntripStatusIcon
                    .frame(width: statusIconSize, height: statusIconSize)
                    .padding(.leading, 4)
                
                if rtk.ntripError != nil {
                    Text("RTK_NTRIP_AUTH_ERROR".localized(userManager.userLanguage))
                        .font(.system(size: 14))
                        .foregroundColor(vibrantPeach)
                        .lineLimit(1)
                        .padding(.leading, 4)
                }
                
                Spacer()
            }
            .padding(16)
            
            providerPulldown()
            
            gridInput()
                .zIndex(3)

            Button {
                rtk.fetchMountpoints(
                    onCompletion: { mountPoints in
                        doValid()
                    },
                    onError: { error in
                        doInvalid(error)
                    }
                )
            } label: {
                Text("RTK_VALIDATE_NTRIP".localized(userManager.userLanguage))
                    .font(.system(size: 16))
                    .foregroundColor(sapphireBlue)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(sapphireBlue, lineWidth: 1)
            )
            .disabled(!rtk.allowNtripValid)
            .padding(.bottom, 16)
            .padding(.horizontal, 16)
            
            HStack(spacing: 8) {
                buttonOpenList(
                    label: "Mountpoint",
                    description: rtk.currentMountpoint.isEmpty ? "Choose mountpoint" :  rtk.currentMountpoint,
                    isValid: isMountpointValid,
                    icon: Image(systemName: "globe").font(.system(size: 24)).foregroundColor(userManager.setting.textColor)) {
                        isShowMountpoints = true
                    }
                    .disabled(!rtk.isNtripProviderStatus)
                
                buttonOpenList(
                    label: "Coordinate system",
                    description: rtk.currentNtripCoordinateSystem?.id ?? "Coordinate system",
                    isValid: isCoordinateValid,
                    icon: Image(userManager.setting.colorTheme == .light ? "ic_coordinate" : "ic_coordinate_dark").frame(width: 24, height: 24)
                ) {
                    isShowCoordinates = true
                }
                .disabled(!rtk.isNtripMountpointStatus)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8).fill(userManager.setting.itemBgColor)
        )
        .onPreferenceChange(NtripInputItemWidthKey.self) { width in
            inputItemWidth = width - 4
        }
        .alert(isPresented: $isShowingAlert) {
            getAlert()
        }
    }
    
    private var isEndpointReadOnly: Bool {
        rtk.ntripServiceProvider != .other
    }
    
    private func providerPulldown() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RTK_NTRIP_VRS_PROVIDER".localized(userManager.userLanguage))
                .font(.system(size: 14))
                .foregroundColor(userManager.setting.colorTheme == .light ? abbeyGray : bombayGray)
                        
            Button {
                hideKeyboard()
                withAnimation(.easeInOut(duration: 0.15)) {
                    isProviderExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(rtk.ntripServiceProvider.localizedKey.localized(userManager.userLanguage))
                        .font(.system(size: 16))
                        .foregroundColor(userManager.setting.textColor)
                        .lineLimit(isIphone ? nil : 1)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image("ic_arrow_down_white")
                        .renderingMode(.template)
                        .resizable()
                        .foregroundColor(userManager.setting.textColor)
                        .frame(width: 16, height: 16)
                        .rotationEffect(.degrees(isProviderExpanded ? 180 : 0))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(width: nil, height: isIphone ? nil : 32)
                .frame(maxWidth: isIphone ? .infinity : nil, minHeight: 32)
                .background(
                    RoundedRectangle(cornerRadius: 2).fill(userManager.setting.colorTheme == .light ? Color.white : abbeyGray)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 2).stroke(steelGray, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .anchorPreference(key: ProviderPulldownAnchorKey.self, value: .bounds) { anchor in
                anchor
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }
    
    private func rowInput() -> some View {
        VStack(spacing: 10) {
            inputItem(
                label: "RTK_HOSTNAME_IP".localized(userManager.userLanguage),
                placeholder: "RTK_HOSTNAME_IP_PLACEHOLDER".localized(userManager.userLanguage),
                value: $rtk.hostnameNtrip,
                inputType: .URL
            )
            
            inputItem(
                label: "RTK_PORT".localized(userManager.userLanguage),
                placeholder: "RTK_PORT_PLACEHOLDER".localized(userManager.userLanguage),
                value: $rtk.portNtrip,
                inputType: .numberPad
            )
            
            inputItem(
                label: "RTK_USERNAME".localized(userManager.userLanguage),
                placeholder: "RTK_USERNAME_PLACEHOLDER".localized(userManager.userLanguage),
                value: $rtk.usernameNtrip
            )
            passwordItem()
        }
        .padding(.horizontal, 11)
        .padding(.bottom, 16)
    }
    
    private func gridInput() -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                inputItem(
                    label: "RTK_HOSTNAME_IP".localized(userManager.userLanguage),
                    placeholder: "RTK_HOSTNAME_IP_PLACEHOLDER".localized(userManager.userLanguage),
                    value: $rtk.hostnameNtrip,
                    inputType: .URL,
                    readOnly: isEndpointReadOnly
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                
                inputItem(
                    label: "RTK_PORT".localized(userManager.userLanguage),
                    placeholder: "RTK_PORT_PLACEHOLDER".localized(userManager.userLanguage),
                    value: $rtk.portNtrip,
                    inputType: .numberPad,
                    readOnly: isEndpointReadOnly
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: NtripInputItemWidthKey.self, value: proxy.size.width)
                    }
                )
            }
            HStack(spacing: 10) {
                inputItem(
                    label: "RTK_USERNAME".localized(userManager.userLanguage),
                    placeholder: "RTK_USERNAME_PLACEHOLDER".localized(userManager.userLanguage),
                    value: $rtk.usernameNtrip,
                    inputType: .URL,
                    showsHint: rtk.ntripServiceProvider.showsUsernameHint
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .zIndex(3)
                
                passwordItem(showsHint: rtk.ntripServiceProvider.showsUsernameHint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .zIndex(3)
        }
        .padding(.horizontal, 11)
        .padding(.bottom, 16)
    }
    
    private func inputItem(
        label: String,
        placeholder: String = "",
        value: Binding<String>,
        inputType: UIKeyboardType = .default,
        readOnly: Bool = false,
        showsHint: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(userManager.setting.colorTheme == .light ? abbeyGray : bombayGray)
                
                if showsHint {
                    HelpPopoverView(
                        manager: popoverManager,
                        id: "ntrip_username_hint",
                        content: "RTK_NTRIP_USERNAME_HINT".localized(userManager.userLanguage),
                        frameWidth: 220,
                        frameHeight: 64,
                        offsetValue: CGSize(width: 90, height: 52),
                        iconColor: sapphireBlue,
                        trailingPadding: 0,
                        autoHideAfter: 5,
                        onClicked: {}
                    )
                    .zIndex(3)
                }
                
                Spacer(minLength: 0)
            }
            .zIndex(3)
            
            TextField(placeholder, text: value, prompt: Text(placeholder).foregroundColor(slateGrey))
                .keyboardType(inputType)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
                .disabled(readOnly)
                .font(.system(size: 16))
                .foregroundColor(readOnly || rtk.isReady ? steelGray : userManager.setting.textColor)
                .frame(height: 32)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 2).fill( userManager.setting.colorTheme == .light ? Color.white : abbeyGray)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 2).stroke(steelGray, lineWidth: 1)
                )
                .onChange(of: value.wrappedValue) { value in
                    doInvalid()
                }
        }
    }
    
    private func doInvalid(_ err: Error? = nil) {
        rtk.isNtripProviderStatus = false
        rtk.isNtripMountpointStatus = false
        rtk.currentMountpoint = ""
        
        // Editing the credentials means "not validated yet", not "validation failed" —
        // without this the error icon would stay on while the user is still typing.
        if err == nil {
            rtk.ntripError = nil
        }
        
        if let err = err {
            alertTitle = "VALIDATION_FAILS".localized(userManager.userLanguage)
            alertMessage = err.localizedDescription
            isShowingAlert = true
        }
    }
    
    private func doValid() {
        hideKeyboard()
        
        rtk.isNtripProviderStatus = true
        
        if let _ = rtk.mountpoints.filter({ $0.name == rtk.currentMountpoint }).first {
            rtk.isNtripMountpointStatus = true
        } else {
            rtk.isNtripMountpointStatus = false
            rtk.currentMountpoint = ""
        }
        
        if !rtk.isNtripMountpointStatus {
            isShowMountpoints = true
        }
    }
    
    private func passwordItem(showsHint: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Text("RTK_PASSWORD".localized(userManager.userLanguage))
                    .font(.system(size: 14))
                    .foregroundColor(userManager.setting.colorTheme == .light ? abbeyGray : bombayGray)
                if showsHint {
                    Spacer().frame(height: 30)
                }
                Spacer(minLength: 0)
            }
            
            SecureField(
                "RTK_PASSWORD_PLACEHOLDER".localized(userManager.userLanguage),
                text: $rtk.passwordNtrip,
                prompt: Text("RTK_PASSWORD_PLACEHOLDER".localized(userManager.userLanguage)).foregroundColor(slateGrey)
            )
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .font(.system(size: 16))
            .foregroundColor(slateGrey)
            .frame(height: 32)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 2).fill( userManager.setting.colorTheme == .light ? Color.white : abbeyGray)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2).stroke(steelGray, lineWidth: 1)
            )
            .onChange(of: rtk.passwordNtrip) { value in
                doInvalid()
            }
        }
    }
    
    private func buttonOpenList(
        label: String,
        description: String,
        isValid: Bool,
        icon: some View, action: (() -> Void)? = nil
    ) -> some View {
        Button {
            action?()
        } label: {
            VStack(alignment: .leading) {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(userManager.setting.textColor)
                    .padding(.bottom, 4)
                
                HStack(spacing: 8) {
                    icon
                        .frame(width: 24, height: 24)
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(isValid ? userManager.setting.textColor : userManager.setting.colorTheme == .light ? steelGray : bombayGray)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16))
                        .foregroundColor(userManager.setting.textColor)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(isValid ? mintBreeze : lightGray, lineWidth: 1)
        )
    }
    
    private func getAlert() -> Alert {
        return Alert(
            title: Text(alertTitle),
            message: Text(alertMessage),
            dismissButton: Alert.Button.default(
                Text("OK"),
                action: {
                    isShowingAlert = false
                }
            )
        )
    }
}

struct NtripInputItemWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ProviderPulldownAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }
    
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

struct NtripProviderOptionsView: View {
    @EnvironmentObject private var userManager: UserManager
    
    static let rowHeight: CGFloat = 40
    static let pulldownWidth: CGFloat = 250
    
    static var fullHeight: CGFloat {
        let count = CGFloat(NtripServiceProviderEnum.allCases.count)
        return count * rowHeight + (count - 1)
    }
    
    let selected: NtripServiceProviderEnum
    let width: CGFloat
    let height: CGFloat
    let onSelect: (NtripServiceProviderEnum) -> Void
    
    var body: some View {
        let items = NtripServiceProviderEnum.allCases
        
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        onSelect(item)
                    } label: {
                        HStack(spacing: 8) {
                            Text(item.localizedKey.localized(userManager.userLanguage))
                                .font(.system(size: 14))
                                .foregroundColor(userManager.setting.textColor)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            if selected == item {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12))
                                    .foregroundColor(sapphireBlue)
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(height: Self.rowHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    if index < items.count - 1 {
                        Divider().background(lightGray)
                    }
                }
            }
        }
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: 4).fill(userManager.setting.themeColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4).stroke(lightGray, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}
