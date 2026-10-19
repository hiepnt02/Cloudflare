//
//  CameraButton.swift
//  Quick3D
//
//  Created by HaNST on 16/12/24.
//

import SwiftUI
import ARKit

enum CameraButtonType {
    case camera
    case ar
}

struct CameraButton: View {
    
    @EnvironmentObject var userManager: UserManager
    
    @State private var isShowingAlert = false
    @State private var alertType : AlertType = .none
    
    @State private var isShowingLocationUnauthorizedAlert = false
    @State private var isShowingLocationOffAlert = false
    @State private var isShowingBluetoothUnauthorizedAlert = false
    @State private var isShowingBluetoothPoweredOffAlert = false
    
    @State private var isSupportLidar: Bool = false
    
    var type: CameraButtonType = .camera
    
    var action: (() -> Void)?
    
    var unsupportedAction: (() -> Void)? = nil
    
    enum AlertType {
        case cameraUnauthorized
        case locationUnauthorized
        case bluetoothUnauthorized
        case bluetoothPoweredOff
        case none
    }
    
    var body: some View {
        Button(
            action: {
                
                if !isSupportLidar {
                    unsupportedAction?()
                    return
                }
                
                PermissionHelper.shared.check {
                    withAnimation(.linear(duration: 0.3)) {
                        LocationManager.shared.start()
                        action?()
                    }
                } cameraUnauthorized: {
                    alertType = .cameraUnauthorized
                    isShowingAlert = true
                } locationUnauthorized: {
                    alertType = .locationUnauthorized
                    isShowingAlert = true
                } bluetoothUnauthorized: {
                    alertType = .bluetoothUnauthorized
                    isShowingAlert = true
                } bluetoothPoweredOff: {
                    alertType = .bluetoothPoweredOff
                    isShowingAlert = true
                }
            },
            label: {
                switch type {
                case .camera:
                    Text("OPEN_TRIAL_CAPTURE".localized(userManager.userLanguage))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 42
                        )
                        .background(sunburst)
                        .contentShape(Rectangle())
                case .ar:
                    Text("AR_QUICK3D_BOOT".localized(userManager.userLanguage))
                }
                
            }
        )
        .buttonStyle(PlainButtonStyle())
        .onLoad {
            isSupportLidar = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        }
        .alert(isPresented: $isShowingAlert, content: {
            getAlert()
        })
    }
    
    private func getAlert() -> Alert {
        
        var title: Text?
        var message: Text?
        
        switch(alertType) {
        case .cameraUnauthorized:
            title = Text("CAMERA_PERMISSION_POPUP_TITLE".localized(userManager.userLanguage))
            message = Text("CAMERA_PERMISSION_POPUP_MESSAGE".localized(userManager.userLanguage))
            break
        case .locationUnauthorized:
            title = Text("LOCATION_PERMISSION_POPUP_TITLE".localized(userManager.userLanguage))
            message = Text("LOCATION_PERMISSION_POPUP_MESSAGE".localized(userManager.userLanguage))
            break
        case .bluetoothUnauthorized:
            title = Text("BLUETOOTH_PERMISSION_POPUP_TITLE".localized(userManager.userLanguage))
            break
        case .bluetoothPoweredOff:
            title = Text("BLUETOOTH_PERMISSION_POPUP_TITLE".localized(userManager.userLanguage))
            break
        case .none:
            break
        }
        
        return Alert(
            title: title!,
            message: message,
            primaryButton: Alert.Button.cancel(
                Text("OPEN_SETTING".localized(userManager.userLanguage)),
                action: {
                    if let url = URL(string:UIApplication.openSettingsURLString) {
                        if UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    }
                }
            ),
            secondaryButton: Alert.Button.default(
                Text("BACK".localized(userManager.userLanguage)),
                action: {
                    isShowingAlert = false
                }
            )
        )
    }
}
