//
//  ViewARScreen.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import SwiftUI
import SceneKit

struct ViewARScreen: View {
    
    @Environment(\.presentationMode) private var presentationMode
    
    @EnvironmentObject var userManager: UserManager
        
    @Binding var selectedCat: Cat?
    
    @State private var isARAccuracyTips = false
    
    @State private var arRendered: Bool = false
    @State private var arItemRendered: Bool = false
    
    @State private var arCalculating: Bool = false
    
    @StateObject private var arPosition = ARPosition()
    
    @State private var isPointCloudRendered = false
    
    // MARK: Ifc sidebar view states
    @State private var isPointClouldVisible = true
    @State private var pointCloudOpacity: CGFloat = 1.0
    @State private var isDesignVisible = true
    @State private var designOpacity: CGFloat = 1.0
    @State private var isExpandLayers = false
    @State private var isAnyOpacitySliderOpen = false
    @State private var activeOpacityNodeId: String? = nil
    @State private var pointCloudScale: Double = ARProjectHelper.pointCloudScale
    @State private var layers: [LayerNode] = []
    @State private var isARPositionExpanded = false
    @State private var isARStepExpanded = false
    @State private var arPositionInstruction: String = ""
    @State private var arPositionMatched: Bool = false
    @ObservedObject private var rtkObject = RTKObject.shared

    @State private var isPointCloudError = false
    @State private var isArError = false
    @State private var pointCloudProgress: Double = 0.0
    
    @StateObject private var cameraObject = CameraObject()
    
    @State private var context = ViewARContext()
    
    @AppStorage("isLightOn")
    private var isLightOn: Bool = true
    
    var isPortrait: Bool {
        get {
            AppDelegate.orientationLock == .portrait
        }
    }
    @State private var isShowVidocSetting = false
    
    @State private var isShowManualCalibration = false

    @State private var calibrationModel: SCNNode?

    var body: some View {
        ZStack {
            cameraLayer

            if isARAccuracyTips {
                ARAccuracyTipsView(isPresented: $isARAccuracyTips)
            }

            if arRendered, !isShowVidocSetting {
                ifcLayersView
            }
        }
        .navigationBarBackButtonHidden(true)
        .contentShape(Rectangle())
        .onTapGesture { hideKeyboard() }
        .overlayPreferenceValue(ARStepPulldownAnchorKey.self) { anchor in
            arStepOptionsOverlay(anchor: anchor)
        }
        .onLoad {
            context.delegate = self
            updateARPositionMessage()
            context.isAROcclusion = userManager.isAROcclusion
            context.isShowPlaneGrid = userManager.isARPlaneGrid
        }
        .environmentObject(cameraObject)
        .onChange(of: cameraObject.rtkQuality) { value in
            if value == .fixed { context.perform(ViewARCalculateEvent()) }
        }
        .onChange(of: isARPositionExpanded) { value in
            cameraObject.isShowAxis = value
            context.perform(ViewARAxisVisibleEvent(value))
            if !value { collapseARStepOptions() }
        }
        .onChange(of: designOpacity) { value in
            layers.forEach { $0.opacity = Double(value) }
        }
        .onChange(of: isLightOn) { value in
            context.perform(ViewARShowHideLightEvent(value))
        }
        .onChange(of: rtkObject.state) { _ in
            guard !arPositionMatched else { return }
            updateARPositionMessage()
        }
        .onChange(of: rtkObject.accuracy.horizontal) { _ in
            guard !arPositionMatched else { return }
            updateARPositionMessage()
        }
        .onChange(of: rtkObject.accuracy.vertical) { _ in
            guard !arPositionMatched else { return }
            updateARPositionMessage()
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: isShowManualCalibration) { isShowing in
            cameraObject.isModalPresented = isShowing
        }
        .fullScreenCover(isPresented: $isShowManualCalibration, onDismiss: {
            // Session/occlusion restore chạy trong ManualCalibrationContext.end()
            // (onDisappear của màn calibration).
            calibrationModel = nil
        }) {
            manualCalibrationSheet
        }
    }

    @ViewBuilder
    private func arStepOptionsOverlay(anchor: Anchor<CGRect>?) -> some View {
        GeometryReader { proxy in
            if isARStepExpanded, let anchor = anchor {
                let anchorFrame = proxy[anchor]
                let spacing: CGFloat = 8
                let width = min(ARStepOptionsView.maxWidth, max(anchorFrame.width, 0))
                let fullHeight = ARStepOptionsView.fullHeight
                let spaceBelow = proxy.size.height - anchorFrame.maxY - spacing
                let spaceAbove = anchorFrame.minY - spacing
                let opensUp = spaceAbove >= fullHeight || spaceAbove >= spaceBelow
                let height = min(fullHeight, max(opensUp ? spaceAbove : spaceBelow, 0))

                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { collapseARStepOptions() }

                ARStepOptionsView(
                    selected: arPosition.currentStep,
                    width: width,
                    height: height,
                    onSelect: { item in
                        arPosition.currentStep = item
                        collapseARStepOptions()
                    }
                )
                .offset(
                    x: max(anchorFrame.maxX - width, 0),
                    y: opensUp ? anchorFrame.minY - spacing - height : anchorFrame.maxY + spacing
                )
            }
        }
        .ignoresSafeArea(.keyboard)
    }

    private func collapseARStepOptions() {
        guard isARStepExpanded else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            isARStepExpanded = false
        }
    }

    private var cameraLayer: some View {
        CameraView(
            rtk: (false, 6, 60),
            context: $context,
            isShowVidocSetting: $isShowVidocSetting,
            back: {
                context.perform(ViewARCancelDownloadEvent())
                Task {
                    context.clear()
                }
            },
            optionButtons: currentEnvironment == .dev && arItemRendered ? AnyView(calibrationButton) : nil,
            additionalWarning: {
                ARInstructionToastView(message: arPositionInstruction)
            },
            content: {
                ARSettingView(
                    context: $context,
                    isPointCloudRendered: $isPointCloudRendered,
                    isARPositionExpanded: $isARPositionExpanded,
                    isARStepExpanded: $isARStepExpanded,
                    arRendered: $arRendered,
                    arItemRendered: $arItemRendered,
                    arCalculating: $arCalculating,
                    arPosition: arPosition,
                    pointCloudScale: $pointCloudScale,
                    pointCloudProgress: $pointCloudProgress,
                    arPositionInstruction: $arPositionInstruction,
                    isPointCloudVisible: $isPointClouldVisible,
                    pointOpacity: $pointCloudOpacity,
                    isARObjectVisisble: $isDesignVisible,
                    arObjectScale: $designOpacity,
                    onARObjectVisibilityChanged: syncRootLayersVisibility
                )
            }
        )
    }

    @ViewBuilder
    private var manualCalibrationSheet: some View {
        if let model = calibrationModel {
            ManualCalibrationScreen(
                parentContext: context,
                panelModel: model,
                onCalibrationComplete: { result in
                    arPosition.setFrom(
                        position: result.position,
                        eulerAngles: result.eulerAngles,
                        scale: result.scale
                    )
                    UserSession.shared.position = result.position
                    UserSession.shared.eulerAngles = result.eulerAngles
                    arPosition.updateUserSessionAndEvent { pos, eulerAngles, scale in
                        context.perform(ViewARUpdatePositionEvent(pos, eulerAngles, scale))
                    }
                    isShowManualCalibration = false
                },
                onDismiss: { isShowManualCalibration = false }
            )
            .environmentObject(userManager)
        }
    }

    private var calibrationButton: some View {
        Button(action: {
            calibrationModel = context.makeCalibrationModelNode()
            isShowManualCalibration = true
        }) {
            Image("manual_calibration")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(imperialBlue.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: borderNormal))
        }
    }
    
    private var ifcLayersView: some View {
        ZStack(alignment: .leading) {
            SidebarView(
                context: context,
                isPointCloudVisible: $isPointClouldVisible,
                layers: $layers,
                isAnyOpacitySliderOpen: $isAnyOpacitySliderOpen,
                activeOpacityNodeId: $activeOpacityNodeId,
                pointCloudScale: $pointCloudScale,
                isExpandLayers: $isExpandLayers,
                isPointCloudRendered: $isPointCloudRendered,
                pointCloudOpacity: pointCloudOpacity,
                isDesignVisible: $isDesignVisible,
                designOpacity: $designOpacity
            )
            
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpandLayers.toggle()
                    }
                }) {
                    Image(systemName: isExpandLayers ? "chevron.left" : "chevron.right")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Rectangle())
                }
                .frame(width: 32, height: 60)
                .background(
                    RoundedCorners(tl: 0, tr: 6, bl: 0, br: 6)
                        .fill(Color.black.opacity(0.6))
                )
                .clipShape(RoundedCorners(tl: 0, tr: 6, bl: 0, br: 6))
                .padding(.leading, isExpandLayers ? UIScreen.main.bounds.width * (isPortrait ? 0.7 : 0.4) : 0)
                
                Spacer()
            }
        }
    }
    
    private func syncRootLayersVisibility(_ visible: Bool) {
        for root in layers where root.isVisible != visible {
            root.isVisible = visible
            context.perform(ViewARIFCVisibleEvent(root, visible))
        }
    }
    
    private func updateARPositionMessage(arPositionDidMatch: Bool = false) {
        if arPositionDidMatch && rtkObject.state == .connected {
            arPositionMatched = true
            setInstruction("AR_DISPLAY_COMPLETE".localized(userManager.userLanguage))
            return
        }
        guard !arPositionMatched else { return }
        if rtkObject.state != .connected {
            setInstruction("RTK_CONNECT".localized(userManager.userLanguage))
        } else if rtkObject.accuracy.horizontal > 0.015 || rtkObject.accuracy.vertical > 0.015 {
            setInstruction("RTK_WAIT_ACCURACY".localized(userManager.userLanguage))
        } else {
            setInstruction("RTK_WALK".localized(userManager.userLanguage))
        }
    }

    private func setInstruction(_ text: String) {
        guard text != arPositionInstruction else { return }
        arPositionInstruction = text
    }
    
    private func dismiss() {
        if UIDevice.current.userInterfaceIdiom == .phone {
            AppDelegate.orientationLock = .landscapeRight
        }
        presentationMode.wrappedValue.dismiss()
    }
}

extension ViewARScreen : ViewARDelegate {
    // MARK: - Core & Status
    func ar(_ project: SfmProject?, didStart isReady: Bool) {
        Task { @MainActor in
            self.cameraObject.isReady = isReady
            
            if let projectId = selectedCat?.projectId {
                // Gửi event tải project
                context.perform(ViewARDownloadEvent(
                    projectId: projectId,
                    isAR: selectedCat?.statusList?.getIsAR ?? false
                ))
            } else {
                cameraObject.showError(NSError(domain: "ViewARScreen", code: 0, userInfo: [NSLocalizedDescriptionKey: "Project ID is nil."])) {
                    dismiss()
                }
            }
        }
    }
    
    func ar(_ project: SfmProject?, error: Error) {
        Task { @MainActor in
            cameraObject.showError(error)
        }
    }
    
    // MARK: - Calculation Lifecycle
    func ar(_ project: SfmProject?, willCalculate offset: SIMD3<Double>) {
        Task { @MainActor in
            self.arCalculating = true
        }
    }
    
    func ar(_ project: SfmProject?, didCalculate offset: SIMD3<Double>) {
        Task { @MainActor in
            // arPosition.fetch() cập nhật dữ liệu từ UserSession lên UI
//            self.arPosition.fetch()
            self.arCalculating = false
        }
    }
    
    func ar(_ project: SfmProject?, didFailToCalculate error: Error) {
        Task { @MainActor in
            self.arCalculating = false
            cameraObject.showAlert(alert: .ARCalculationFail)
        }
    }
    
    // MARK: - Download Lifecycle
    func ar(_ project: SfmProject?, willDownload projectId: String) {
        Task { @MainActor in
            cameraObject.startLoading(text: "LOADING_PROJECT".localized(userManager.userLanguage))
        }
    }
    
    func ar(_ project: SfmProject?, didDownload offset: SIMD3<Double>) {
        Task { @MainActor in
            cameraObject.stopLoading()
            self.arRendered = true
        }
    }
    
    func ar(_ project: SfmProject?, didFailToDownload code: Int) {
        Task { @MainActor in
            cameraObject.stopLoading()
            
            let type: CameraAlertTypeEnum
            switch code {
            case 400: type = .ARDownloadFail400
            case 404: type = .ARDownloadFail404
            default:  type = .ARDownloadFail500
            }
            
            cameraObject.showAlert(alert: type, primaryAction: {
                dismiss()
            })
        }
    }
    
    // MARK: - PointCloud & IFC
    func ar(_ project: SfmProject?, onPointCloudProgressChanged progress: Double) {
        Task { @MainActor in
            self.pointCloudProgress = progress
        }
    }
    
    func ar(_ project: SfmProject?, didDownloadPointCloudItem offset: SIMD3<Double>) {
        Task { @MainActor in
            cameraObject.stopLoading()
            self.isPointCloudRendered = !isPointCloudError
        }
    }
    
    func ar(_ project: SfmProject?, didDownloadPointCloud offset: SIMD3<Double>) {
        // Có thể dùng để cập nhật trạng thái đã tải xong hoàn toàn Point Cloud nếu cần
    }
    
    func ar(_ project: SfmProject?, didFailToDownloadPointCloud error: Error) {
        Task { @MainActor in
            self.isPointCloudRendered = false
            self.isPointCloudError = true
        }
    }
    
    func ar(_ project: SfmProject?, didDownloadIFC layers: [LayerNode]) {
        Task { @MainActor in
            cameraObject.stopLoading()
            self.arItemRendered = !isArError
            self.isARAccuracyTips = true
            layers.forEach { $0.opacity = Double(self.designOpacity) }
            self.layers = layers
        }
    }
    
    func ar(_ project: SfmProject?, didFailToDownloadIFC error: Error) {
        Task { @MainActor in
            self.arItemRendered = false
            self.isArError = true
        }
    }
    
    func ar(_ project: SfmProject?, arPositionDidMatch: Bool) {
        updateARPositionMessage(arPositionDidMatch: true)
    }
}
