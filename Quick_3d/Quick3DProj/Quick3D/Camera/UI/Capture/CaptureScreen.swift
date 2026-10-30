//
//  CameraView.swift
//  Quick3D
//
//  Created by HaNST on 12/11/24.
//

import SwiftUI
import ARKit
import VigramSDK
import Combine
import CoreBluetooth

struct CaptureScreen: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject private var newProject: NewProject
    @EnvironmentObject var productData: ProductData
    
    @Binding var navigateCat: Cat?
    
    @StateObject private var arObject: ARObject = .init()
    
    @StateObject private var cameraObject = CameraObject()
    
    @StateObject private var locationReady: LocationReadyObject = .init()
    
    @State private var isExportPreview = false
    
    @State private var isUpload = false
    
    @State private var isExporting = false
    
    @State private var isShowMenuSetting = false
    
    @State private var isShowVidocSetting = false
    
    @State private var context = CaptureContext()
    
    @StateObject private var pendingSettings = CapturePendingSettings()
    
    var isPortrait: Bool {
        get {
            AppDelegate.orientationLock == .portrait
        }
    }
    
    var body: some View {
        ZStack {
            CameraView(
                rtk: (true, 6, 10),
                context: $context,
                isShowVidocSetting: $isShowVidocSetting,
                back: nil,
                additionalWarning: { EmptyView() }
            ) {
                if cameraObject.isReady && locationReady.gpsReady {
                    CaptureView {
                        newProject.setProjectName()
                        context.perform(CaptureStartEvent())
                    } saveAction: {
                        if arObject.imageIndex > 0 {
                            context.perform(CapturePauseEvent(true))
                            cameraObject.startLoading()
                        }
                    } openSettingAction: {
                        withAnimation {
                            isShowMenuSetting = true
                        }
                    }
                    abortAction: {
                        context.perform(CapturePauseEvent(false))
                        
                        cameraObject.showAlert(alert: .AbortCapture) {
                            cameraObject.startLoading()
                            discardScan()
                        } secondaryAction: {
                            context.perform(CaptureResumeEvent())
                        }
                    }
                }
            }
            .environmentObject(cameraObject)
        }
        .navigationBarBackButtonHidden(true)
        .onLoad {
            context.delegate = self
            cameraObject.checkMoveToFast = true
            
            ImageCompressionProcessor.current.clearAll()
        }
        .popupNavigationView(show: $isShowMenuSetting, backgroundColor: userManager.setting.themeColor, isFullScreen: true) {
            CaptureSettingsPopup(isShow: $isShowMenuSetting, onSave: {
                context.applyDisplaySettings()
            })
            .environmentObject(pendingSettings)
        }
        .popupNavigationView(show: $isExportPreview, backgroundColor: userManager.setting.themeColor, isFullScreen: true) {
            ExportPreviewPopup(
                isShow: $isExportPreview,
                projectName: $newProject.projectName,
                savedHander: {
                    cameraObject.startLoading()
                    isUpload = false
                    exportOuput()
                },
                exportedHander: {
                    cameraObject.startLoading()
                    isUpload = true
                    exportOuput()
                },
                abortHandler: {
                    cameraObject.showAlert(alert: .AbortCaptureFromPreview) {
                        cameraObject.startLoading()
                        discardScan()
                    } secondaryAction: {
                        withAnimation {
                            isExportPreview = true
                        }
                    }
                }
            )
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Perform actions when the app becomes active
                CaptureSession.current?.sessionLogger.logOperation("scenePhaseChanged", ["phase": "active"])
                context.resume()
            } else if newPhase == .inactive {
                // App is temporarily not receiving events (e.g., system alert is showing)
            } else if newPhase == .background {
                // Perform actions when the app goes to the background
                CaptureSession.current?.sessionLogger.logOperation("scenePhaseChanged", ["phase": "background"])
                context.pause()
                ImageCompressionProcessor.current.clearAll()
            }
        }
        .onChange(of: arObject.status) { value in
            cameraObject.isShowHomeButton = arObject.status == .initial || arObject.status == .stopped
        }
        .onChange(of: pendingSettings.saveToken) { value in
            context.start()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            CaptureSession.current?.sessionLogger.logProcessing("memory", "memoryWarning", level: .warning)
            context.perform(CapturePauseEvent(false))
            cameraObject.showAlert(alert: .OutOfMemory)
        }
        .environmentObject(arObject)
    }
    
    private func discardScan() {
        arObject.imageIndex = 0
        context.perform(CaptureCancelEvent())
        cameraObject.debugOverlapRatio = 0.0
    }
    
    private func exportOuput() {
        isExporting = true
        CaptureSession.current?.sessionLogger.logOperation("saveButtonPressed", ["isUpload": isUpload])
        context.perform(CaptureExportEvent())
        cameraObject.debugOverlapRatio = 0.0
    }
    
    private func back() {
        if UIDevice.current.userInterfaceIdiom == .phone {
            AppDelegate.orientationLock = .landscapeRight
        }
        presentationMode.wrappedValue.dismiss()
    }
}

extension CaptureScreen: CaptureDelegate {
    
    func capture(_ session: CaptureSession?, didCapture count: Int) {
        arObject.imageIndex = count
        
        handleLimitCapture(count)
    }
    
    // Set auto complete capture when number of images reach to 4000 images.
    private func handleLimitCapture(_ imageCount: Int) {
        if imageCount == 3500 {
            CaptureSession.current?.sessionLogger.logOperation("captureLimitWarning", ["count": imageCount])
            cameraObject.showAlertMessage("CAPTURE_MAX_LIMIT".localized(userManager.userLanguage))
        } else if imageCount == 4000 {
            CaptureSession.current?.sessionLogger.logOperation("captureLimitReached", ["count": imageCount])
            cameraObject.showAlertMessage("CAPTURE_LIMIT_REACHED".localized(userManager.userLanguage))
            context.perform(CapturePauseEvent(true))
            cameraObject.startLoading()
        }
    }
    
    func capture(_ session: CaptureSession?, exportProgress progress: Double) {
        if isExporting {
            let loadingText = progress >= 0 ? "\("SAVING".localized(userManager.userLanguage)): \(Int(progress * 100))%" : ""
            cameraObject.startLoading(text: loadingText)
        }
    }
    
    func capture(_ session: CaptureSession?, didExport url: URL) {
        isExporting = false
        discardScan()
        cameraObject.stopLoading()
        if isUpload {
            newProject.isShowUploadPopup = isUpload
            newProject.jobSiteValue = nil
            newProject.isCreate = true
            newProject.currentCat = navigateCat
            newProject.url = url
            back()
        } else {
            // Save project
            // Create local project with default settings
            guard let _ = productData.saveProduct(
                title: newProject.projectName,
                jobsiteId: "",
                zipFileUrl: url,
                cat: newProject.currentCat,
                coordinateSetting: false,
                linkDashboard: false,
                verticalCoordinate: "",
                horizontalCoordinate: ""
            ) else {
                return
            }
            
            // Update product data to refresh UI
            productData.updateDisplayProduct()

            // currentCat có thể còn giá trị cũ từ lần upload/import trước trong cùng
            // phiên — nếu không reset, lần lưu-local kế tiếp sẽ đi vào nhánh
            // cat != nil của createCatModel và project không được thêm vào danh sách.
            newProject.resetData()
        }
    }
    
    func capture(_ session: CaptureSession?, didChange status: ARStatus) {
        
        if arObject.status == .pausing && status == .paused {
            withAnimation {
                isExportPreview = true
            }
        }
        
        withAnimation {
            arObject.status = status
        }
    }
    
    func capture(_ session: CaptureSession?, error: any Error, action: (() -> Void)?) {
        cameraObject.showError(error) {
            action?()
        }
    }
    
    func capture(_ session: CaptureSession?, didCalculateOverlap ratio: Float, zDistance: Float) {
        cameraObject.debugOverlapRatio = ratio
        cameraObject.zDistance = zDistance
    }
    
    func capture(_ session: CaptureSession?, didStart isReady: Bool) {
        
        if !cameraObject.isReady {
            if CaptureSession.isSessionError {
                let crashLogTask = Task.detached(priority: .utility) {
                    try? CaptureSession.buildCrashLogZip()
                }
                Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                    Task { @MainActor in
                        cameraObject.showAlert(alert: .SessionError, primaryAction: {
                            Task { @MainActor in
                                _ = await crashLogTask.value
                                CaptureSession.clear()
                                cameraObject.isReady = isReady
                            }
                        })
                    }
                }
            } else {
                cameraObject.isReady = isReady
            }
        } else {
            cameraObject.stopLoading()
        }
        
    }
}
