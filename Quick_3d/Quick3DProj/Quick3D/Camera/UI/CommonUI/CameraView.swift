//
//  CameraView.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import SwiftUI

struct CameraView<Context, Content, AdditionalWarning>: View where Context: CameraContext, Content: View, AdditionalWarning: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var cameraObject: CameraObject
    
    @ObservedObject var rtkObj: RTKObject = RTKObject.shared
    
    var rtk: (isOptional: Bool, scanTimeout: TimeInterval, connectionTimeout: TimeInterval) = (true, 6, 20)
    
    @Binding var context: Context
    
    @Binding var isShowVidocSetting: Bool
    
    var back: (() -> Void)? = nil

    /// View tùy biến của màn hình gọi, hiển thị ở cột trái bên dưới nút Home, phía trên nút debug
    var optionButtons: AnyView? = nil

    @ViewBuilder let additionalWarning: () -> AdditionalWarning

    @ViewBuilder let content: () -> Content
    
    @State private var isShowDebugView = true
    
    @State private var errorMessage: String = ""
    @State private var isShowErrorMessage: Bool = false
    
    @StateObject private var motionObject = MotionObject()
    
    @StateObject private var rtkDisconnectObserver: RTKConnectionObserver = .shared
    
    @StateObject private var rtkAutoConnection = RTKAutoConnection()
    
    @State private var isConnectingVidoc: Bool = true
    
    private let axisSize: CGFloat = UIDevice.current.isIphone ? 100 : 120
    
    @State private var isViewActive = false
    
    @ObservedObject private var thermalMonitor = ThermalMonitor.shared
    
    @AppStorage("isShowResolution")
    private var isShowResolution: Bool = false
    @AppStorage("isShowOverlap")
    private var isShowOverlap: Bool = false
    
    @StateObject private var popoverManager = PopoverManager()
    
    var body: some View {
        ZStack {
            ARSCNCameraView(context: $context)
                .ignoresSafeArea()
                .onLoad {
                    context.start()
                }
            
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .allowsHitTesting(false)
            
            topButtonsLayer()
            
            bottomButtonsLayer()
                .ignoresSafeArea(edges: .bottom)

            if cameraObject.checkMoveToFast {
                MotionView()
            }

            if cameraObject.isLoading {
                ProgressLoadingView(text: cameraObject.loadingText)
                    .edgesIgnoringSafeArea(.all)
            }

            warningOverlayView
        }
        .navigationBarBackButtonHidden(true)
        .alert(
            cameraObject.alertType.title.localized(userManager.userLanguage),
            isPresented: $cameraObject.isShowAlert,
            actions: {
                Button(
                    cameraObject.alertType.primaryLabel.localized(userManager.userLanguage),
                    role: cameraObject.alertType.primaryRole
                ) {
                    cameraObject.alertPrimaryAction?()
                    dissmissAlert()
                }
            
                if let secondaryLabel = cameraObject.alertType.secondaryLabel {
                    Button(secondaryLabel.localized(userManager.userLanguage), role: cameraObject.alertType.secondaryRole) {
                        cameraObject.alertSecondaryAction?()
                        dissmissAlert()
                    }
                }
            },
            message: {
                if cameraObject.alertType == .Error {
                    if let message = cameraObject.errorMessage {
                        Text(message.localized(userManager.userLanguage))
                    }
                } else if let message = cameraObject.alertType.message {
                    Text(message.localized(userManager.userLanguage))
                }
            }
        )
        .overlay(popoverOverlay)
        .onLoad {
            
            if UIDevice.current.userInterfaceIdiom == .phone {
                AppDelegate.orientationLock = .portrait
            }
            
            LocationManager.shared.start()
            
            rtkDisconnectObserver.showAlert = { msg in
                errorMessage = msg.localized(userManager.userLanguage)
                isShowErrorMessage = true
                if isViewActive {
                    AudioService.shared.playAlertSound()
                }
            }
            
            autoConnectRTK()
            
            thermalMonitor.start()
        }
        .popupNavigationView(show: $isShowVidocSetting, backgroundColor: userManager.setting.themeColor, isFullScreen: true) {
            RTKSettingsPopup(isShow: $isShowVidocSetting)
        }
        .onChange(of: rtkAutoConnection.isError) { value in
            if !rtk.isOptional && value {
                cameraObject.showAlert(alert: .RTKAutoConnectionFail)
            }
        }
        .onChange(of: cameraObject.alertMessage) { value in
            errorMessage = cameraObject.alertMessage ?? ""
            isShowErrorMessage = true
        }
        .onChange(of: rtkAutoConnection.quality) { value in
            cameraObject.rtkQuality = value
        }
        .onChange(of: rtkAutoConnection.state) { value in
            isConnectingVidoc = value == .connecting
        }
        .onAppear {
            isViewActive = true
        }
        .onDisappear {
            isViewActive = false
            if !cameraObject.isModalPresented {
                thermalMonitor.stop()
            }
        }
    }
    
    private func debugInfosView() -> some View {
        VStack(alignment: .leading) {
            CircleButton(
                icon: Image(systemName: isShowDebugView ? "eye" : "eye.slash"),
                iconSize: 20,
                backgroundColor: imperialBlue.opacity(0.5),
                isShowStroke: false,
                buttonSize: 48,
                action: {
                    isShowDebugView.toggle()
                }
            )
            
            if isShowDebugView {
                DebugView(isViewARScreen: !rtk.isOptional)
            }
            
            Spacer()
        }
    }
    
    private var popoverOverlay: some View {
        Group {
            if popoverManager.activePopoverID != nil {
                ThermalPopoverView(
                    text: thermalMonitor.message.localized(userManager.userLanguage),
                    offsetValue: CGSize(width: -70, height: UIDevice.current.isIphone ? -5 : 10)
                )
                .position(x: popoverManager.anchorFrame.midX, y: popoverManager.anchorFrame.midY)
            }
        }
    }
    
    private var warningOverlayView: some View {
        VStack(spacing: 8) {
            if thermalMonitor.state == .critical {
                VStack {
                    Text(thermalMonitor.message.localized(userManager.userLanguage))
                        .font(.system(size: 16))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .background(.red)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 16)
                        )
                }
                .padding(.horizontal, 30)
            }
            
            if isShowErrorMessage {
                Text(errorMessage)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 8).fill(rubyRed))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                            isShowErrorMessage = false
                        }
                    }
            }
            
            additionalWarning()

        }
        .padding(.horizontal, 30)
    }
    
    private func topButtonsLayer() -> some View {
        VStack(spacing: 8) {
            HStack {
                if cameraObject.isShowHomeButton {
                    HomeButton(action: {
                        onBack()
                    })
                }
                
                Spacer()
                
                if isConnectingVidoc {
                    ConnectingBluetoothView()
                        .padding(.leading, 10)
                        .padding(.top, 5)
                } else {
                    GNSSStatusBar(
                        isShowVidocSetting: $isShowVidocSetting,
                        onClickThermal: { frame in
                            popoverManager.toggle(id: "thermal_btn", frame: frame)
                        },
                        onHideThermal: {
                            popoverManager.hideAll()
                        }
                    )
                    .environmentObject(cameraObject)
                    .environmentObject(thermalMonitor)
                }
                
            }
            .frame(maxWidth: .infinity)
            
            HStack(alignment: .top) {

                VStack(alignment: .leading) {
                    if let optionButtons {
                        optionButtons
                    }
                    if currentEnvironment == .dev {
                        debugInfosView()
                    }
                }

                Spacer()
                
                VStack(alignment: .trailing) {
                    if rtkObj.isReady {
                        GNSSQualityBar()
                    }
                    
                    GNSSSignalBar()
                    
                    if rtk.isOptional {
                        HStack {
                            Spacer()
                            if isShowResolution {
                                ResolutionInfoView()
                            }
                            
                            if isShowOverlap {
                                OverlapInfoView()
                            }
                        }
                    }
                    if cameraObject.isShowAxis {
                        HStack {
                            Spacer()
                            AxisView()
                                .frame(width: axisSize, height: axisSize)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    private func bottomButtonsLayer() -> some View {
        VStack {
            Spacer()
            
            if cameraObject.checkMoveToFast {
                MoveFastWarningView()
            }

            ARTrackingAlertView()

            content()
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private func autoConnectRTK() {
        RTKAutoConnectionHelper.shared.start(optional: rtk.isOptional, scanTimeout: rtk.scanTimeout, timeout: rtk.connectionTimeout)
    }
    
    private func onBack() {
        back?()
        if UIDevice.current.userInterfaceIdiom == .phone {
            AppDelegate.orientationLock = .landscapeRight
        }
        presentationMode.wrappedValue.dismiss()
    }
    
    private func dissmissAlert() {
        cameraObject.alertType = .None
        cameraObject.isShowAlert = false
    }
    
    private func openSetting() {
        if let url = URL(string:UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}
