//
//  CameraObject.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import Foundation
import SwiftUI

public class CameraObject: ObservableObject {
    
    @Published var checkMoveToFast: Bool = false
    
    @Published var debugOverlapRatio: Float = 0
    
    @Published var zDistance: Float = 0
    
    @Published var isLoading = false
    
    @Published var loadingText: String = ""
    
    @Published var alertType: CameraAlertTypeEnum = .None
    
    @Published var isShowAlert = false
    
    @Published var errorMessage: String?
    
    @Published var alertMessage: String?
    
    @Published var rtkQuality: RTKQuality?
    
    @Published var isShowAxis = false
    
    @Published var isShowHomeButton = true

    /// True while a modal/fullScreenCover is presented over the camera screen.
    /// Alerts are suppressed when this flag is set.
    var isModalPresented: Bool = false
    
    /// True while an in-hierarchy popup (popupNavigationView) of the host screen covers the camera.
    /// Warning banners and their sounds are suppressed when this flag is set.
    @Published var isPopupPresented = false
    
    @Published var isReady = false
    
    public private(set) var alertPrimaryAction: (() -> Void)? = nil
    
    public private(set) var alertSecondaryAction: (() -> Void)? = nil
    
    func startLoading(text: String = "") {
        DispatchQueue.main.async {
            self.loadingText = text
            self.isLoading = true
        }
    }
    
    func stopLoading() {
        isLoading = false
        loadingText = ""
    }
    
    func showAlert(alert: CameraAlertTypeEnum, primaryAction: (() -> Void)? = nil, secondaryAction: (() -> Void)? = nil) {
        guard !isModalPresented else { return }
        alertPrimaryAction = primaryAction
        alertSecondaryAction = secondaryAction
        alertType = alert
        
        withAnimation {
            isShowAlert = true
        }
    }
    
    func showError(_ error: Error, action: (() -> Void)? = nil) {
        errorMessage = error.localizedDescription
        showAlert(alert: .Error, primaryAction: action)
    }
    
    func showAlertMessage(_ alertMessage: String) {
        self.alertMessage = alertMessage
    }
}
