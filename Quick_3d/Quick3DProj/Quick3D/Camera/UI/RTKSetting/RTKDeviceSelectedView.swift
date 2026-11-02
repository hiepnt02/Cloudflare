//
//  RTKSearchingView.swift
//  Quick3D
//
//  Created by HaNST on 29/12/25.
//

import SwiftUI
import CoreBluetooth
import Network
import VigramSDK

struct RTKDeviceSelectedView: View {
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var rtk: RTKStateObject
    
    let deviceName: String
    let identifier: UUID
    var back : (() -> Void)? = nil
    var onClose : (() -> Void)? = nil
    
    @State private var isConnecting = false
    @State private var isDisconnecting = false
    @State private var isProviderExpanded: Bool = false
    @State private var isShowMountpoints: Bool = false
    @State private var isShowCoordinates: Bool = false
    @State private var currentElev: ElevationValue = .ang15
    @State private var currentGNSS: Set<GNSSEnum> = [.GPS]
    @State private var isClickConnectRTK = false
    @State private var activeAlert: ActiveAlertEnum?
    
    private var isIphone: Bool {
        UIDevice.current.isIphone
    }
    
    private var isDisabled: Bool {
        rtk.isReady || isConnecting
    }
    
    private var isConnectButtonDisabled: Bool {
        !(rtk.isNtripProviderStatus &&
          rtk.isNtripCoordinateSystemStatus &&
          rtk.isNtripMountpointStatus &&
          !rtk.currentMountpoint.isEmpty &&
          rtk.currentNtripCoordinateSystem != nil &&
          (rtk.cameraOffsetSegment != .Custom || rtk.customOffsetVidoc != .zero)
        )
    }
    
    var body: some View {
        ZStack {
            contentView
            
            if isShowMountpoints {
                RTKMountpointsView(isShow: $isShowMountpoints, onMountpointSelected: {
                    // Only auto-open coordinate system picker when none is selected yet
                    if rtk.currentNtripCoordinateSystem == nil {
                        isShowCoordinates = true
                    }
                })
            }
            
            if isShowCoordinates {
                RTKCoordinatesView(isShow: $isShowCoordinates)
            }
        }
        .overlayPreferenceValue(ProviderPulldownAnchorKey.self) { anchor in
            providerOptionsOverlay(anchor: anchor)
        }
        .onLoad {
            currentElev = UserSession.shared.elevation
            currentGNSS = UserSession.shared.gnsss
        }
        .onAppear {
            isConnecting = rtk.state == .connecting
            isDisconnecting = rtk.state == .disconnecting
            isClickConnectRTK = false
        }
        .onTapGesture {
            hideKeyboard()
            collapseProviderOptions()
        }
        .onChange(of: rtk.state) { value in
            if value == .connected || value == .disconnected {
                isConnecting = false
                isDisconnecting = false
            }
            
            if value == .connected && isClickConnectRTK {
                isClickConnectRTK = false
                onClose?()
            }
        }
        .alert(item: $activeAlert) { alertType in
            getAlert(alertType: alertType)
        }
    }
    
    private var contentView: some View {
        VStack(spacing: 0) {
            HStack {
                SubBackButton(
                    title: "RTK_BLUETOOTH_DEVICE_MESSAGE_BACK_TO_LIST".localized(userManager.userLanguage),
                    isBoldTitle: true,
                    onBack: {
                        RTKManager.shared.disconnect()
                        back?()
                    }
                )
                .padding(.leading, 16)
                
                Spacer()
            }
            
            ScrollView(showsIndicators: false) {
                settingsView
            }
            
            if UIDevice.current.isIphone {
                Divider().background(lightGray)
            }
            
            bottomActionView
                .padding(16)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var settingsView: some View {
        VStack(spacing: 0) {
            Text(deviceName)
                .font(.system(size: 32))
                .foregroundColor(userManager.setting.textColor)
                .padding(.vertical, 16)
            
            VidocInfoSection()
            
            RTKDeviceOffsetView()
                .padding(.bottom, 16)
                .disabled(isDisabled)
            
            RTKDeviceNTRIPView(
                isShowMountpoints: $isShowMountpoints,
                isShowCoordinates: $isShowCoordinates,
                isProviderExpanded: $isProviderExpanded
            )
            .padding(.bottom, 16)
            .disabled(isDisabled)
            .zIndex(3)
            
            ElevationSection(currentElev: $currentElev)
            
            Text("ELEVATION_MASK_DESC".localized(userManager.userLanguage))
                .font(.system(size: 12))
                .foregroundColor(userManager.setting.textColor.opacity(0.5))
                .padding(.top, 8)
                .padding(.bottom, 16)
            
            ConstelationsSection(currentGNSS: $currentGNSS)
            
            Text("GNSS_CONSTELLATIONS_DESC".localized(userManager.userLanguage))
                .font(.system(size: 12))
                .foregroundColor(userManager.setting.textColor.opacity(0.5))
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, popupHPadding)
        .padding(.bottom, 16)
    }
    
    @ViewBuilder
    private var bottomActionView: some View {
        if rtk.isReady {
            NormalButton(
                label: "RTK_BLUETOOTH_DEVICE_DISCONNECT".localized(userManager.userLanguage),
                backgroundColor: materialRed,
                onClick: {
                    isConnecting = false
                    isDisconnecting = true
                    RTKManager.shared.disconnect()
                }
            )
        } else if isConnecting {
            LoadingButton(
                label: "RTK_BLUETOOTH_DEVICE_MESSAGE_ACQUIRING_LOCATION".localized(userManager.userLanguage),
                isShowLoading: $isConnecting,
                onClick: {
                }
            )
        }  else if isDisconnecting {
            LoadingButton(
                label: "",
                isShowLoading: $isDisconnecting,
                onClick: {
                }
            )
        } else {
            NormalButton(
                label: "RTK_BLUETOOTH_DEVICE_CONNECT".localized(userManager.userLanguage),
                isDisabled: isConnectButtonDisabled,
                onClick: onConnectRTK
            )
        }
    }
    
    @ViewBuilder
    private func providerOptionsOverlay(anchor: Anchor<CGRect>?) -> some View {
        GeometryReader { proxy in
            if isProviderExpanded, let anchor = anchor {
                let anchorFrame = proxy[anchor]
                let spacing: CGFloat = 8
                let width = min(anchorFrame.width, max(proxy.size.width - 32, 0))
                let fullHeight = NtripProviderOptionsView.fullHeight
                let spaceBelow = proxy.size.height - anchorFrame.maxY - spacing
                let spaceAbove = anchorFrame.minY - spacing
                let opensDown = spaceBelow >= fullHeight || spaceBelow >= spaceAbove
                let height = min(fullHeight, max(opensDown ? spaceBelow : spaceAbove, 0))
                
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        collapseProviderOptions()
                    }
                
                NtripProviderOptionsView(
                    selected: rtk.ntripServiceProvider,
                    width: width,
                    height: height,
                    onSelect: { item in
                        rtk.applyNtripServiceProvider(item)
                        collapseProviderOptions()
                    }
                )
                .offset(
                    x: max(anchorFrame.maxX - width, 0),
                    y: opensDown ? anchorFrame.maxY + spacing : anchorFrame.minY - spacing - height
                )
            }
        }
        .ignoresSafeArea(.keyboard)
    }
    
    private func collapseProviderOptions() {
        guard isProviderExpanded else { return }
        
        withAnimation(.easeInOut(duration: 0.15)) {
            isProviderExpanded = false
        }
    }
    
    private func onConnectRTK() {
        if !ConnectivityMonitor.shared.isCurrentlyConnected() {
            activeAlert = .noNetwork
            return
        }
        
        do {
            UserSession.shared.elevation = currentElev
            UserSession.shared.gnsss = currentGNSS
            
            UserSession.shared.ntripInfo = NtripInfoModel(
                username: rtk.usernameNtrip,
                password: rtk.passwordNtrip,
                port: Int(rtk.portNtrip) ?? 0,
                hostnameOrIp: rtk.hostnameNtrip
            )
            
            UserSession.shared.ntripServiceProvider = rtk.ntripServiceProvider
            UserSession.shared.mountPointNtrip = rtk.currentMountpoint
            UserSession.shared.coordinateSystemNtrip = rtk.currentNtripCoordinateSystem
            UserSession.shared.cameraOffsetSegment = rtk.cameraOffsetSegment
            
            isClickConnectRTK = true
            RTKConnectionObserver.shared.reset()
            try connectToDevice()
            isConnecting = true
        } catch {
            print("Error \(error)")
            isClickConnectRTK = false
            activeAlert = .custom(
                title: "CONNECTION_FAILED".localized(userManager.userLanguage),
                message: "DEVICE_NOT_FOUND".localized(userManager.userLanguage)
            )
        }
    }
    
    private func connectToDevice() throws {
        if let device = rtk.devices.filter({ $0.identifier == identifier }).first {
            try RTKManager.shared.connectTo(device: device, isAutoConnectToNtrip: true)
        } else {
            throw NSError(domain: "", code: 0, userInfo: nil)
        }
    }
    
    private func getAlert(alertType: ActiveAlertEnum) -> Alert {
        switch alertType {
        case .noNetwork:
            return noNetworkAlert(
                userManager: userManager,
                onDissmiss: {}
            )
        case .custom:
            return Alert(
                title: Text(activeAlert?.title ?? ""),
                message: Text(activeAlert?.message ?? ""),
                dismissButton: .default(
                    Text("OK"),
                    action: {}
                )
            )
        }
    }
}
