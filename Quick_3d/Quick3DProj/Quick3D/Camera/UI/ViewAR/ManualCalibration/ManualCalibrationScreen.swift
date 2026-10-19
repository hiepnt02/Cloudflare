//
//  ManualCalibrationScreen.swift
//  Quick3D
//

import SwiftUI
import SceneKit

struct ManualCalibrationScreen: View {

    let parentContext: ViewARContext

    let panelModel: SCNNode

    var onCalibrationComplete: (CalibrationResult) -> Void

    var onDismiss: () -> Void

    @State private var context = ManualCalibrationContext()

    /// Bản đọc của state trong context, cập nhật qua ManualCalibrationDelegate.
    @State private var selection = CalibrationSelection()

    @StateObject private var cameraObject = CameraObject()

    @EnvironmentObject private var userManager: UserManager

    @State private var isShowVidocSetting = false

    @State private var alertMessage: String = ""

    @State private var isShowAlert = false

    @ObservedObject private var thermalMonitor = ThermalMonitor.shared

    @State private var thermometerCenter: CGPoint = .zero

    @State private var isShowThermometerMessage = false

    var body: some View {
        ZStack(alignment: .top) {
            cameraLayer
            panelLayer
            topBarLayer

            if isShowThermometerMessage {
                ThermalPopoverView(
                    text: thermalMonitor.message.localized(userManager.userLanguage),
                    offsetValue: CGSize(width: -70, height: UIDevice.current.isIphone ? -5 : 10)
                )
                .position(x: thermometerCenter.x, y: thermometerCenter.y)
            }
        }
        .ignoresSafeArea()
        .environmentObject(cameraObject)
        .alert("Error", isPresented: $isShowAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .popupNavigationView(show: $isShowVidocSetting, backgroundColor: userManager.setting.themeColor, isFullScreen: true) {
            RTKSettingsPopup(isShow: $isShowVidocSetting)
        }
        .onDisappear {
            context.end()
        }
    }

    private var instructionKey: String {
        selection.step.panelMode == .expanded
            ? "CALIBRATION_GUIDE_STEP1"
            : "CALIBRATION_GUIDE_STEP2"
    }

    /// Bước chỉ định vị trí trong AR: panel thu nhỏ nằm đáy, hướng dẫn nằm ngay dưới nó.
    private var instructionBanner: some View {
        Text(instructionKey.localized(userManager.userLanguage))
            .calibrationInstructionStyle()
    }

    private var cameraLayer: some View {
        ZStack {
            ARSCNCameraView(context: $context)
                .ignoresSafeArea()
                .onLoad {
                    cameraObject.isReady = true
                    context.calibrationDelegate = self
                    context.begin(parent: parentContext, model: panelModel)
                }

            if selection.step.isCameraTapActive {
                CameraTapView { point in
                    context.perform(ManualCalibrationTapCameraEvent(point))
                }
                .ignoresSafeArea()
            }
        }
    }

    private var topBarLayer: some View {
        VStack {
            HStack(alignment: .top) {
                backButton
                    .padding(.leading, 12)
                    .padding(.top, 48)
                Spacer()
                // Expanded mode dedicates the top-right corner to the P1/P2 buttons.
                if selection.step.panelMode == .collapsed {
                    GNSSStatusBar(
                        isShowVidocSetting: $isShowVidocSetting,
                        onClickThermal: { rect in
                            thermometerCenter = CGPoint(x: rect.midX, y: rect.midY)
                            isShowThermometerMessage = true
                        },
                        onHideThermal: {
                            isShowThermometerMessage = false
                        }
                    )
                    .padding(.trailing, 12)
                    .padding(.top, 48)
                    .environmentObject(cameraObject)
                    .environmentObject(thermalMonitor)
                }
            }
            Spacer()
        }
    }

    private var backButton: some View {
        Button(action: onDismiss) {
            Image("ic_arrow_back_white")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(imperialBlue.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: borderNormal))
        }
        .accessibilityLabel("Back")
    }

    private var panelLayer: some View {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let panel = CalibrationPanelView(
            context: $context,
            selection: selection,
            model: panelModel,
            instructionText: instructionKey.localized(userManager.userLanguage)
        )
        return Group {
            if selection.step.panelMode == .expanded {
                panel
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    if isIPad {
                        HStack(spacing: 0) {
                            panel.padding(.leading, 16)
                            Spacer()
                        }
                        HStack(spacing: 0) {
                            instructionBanner.padding(.leading, 16)
                            Spacer()
                        }
                    } else {
                        panel
                        instructionBanner.padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }
}

extension ManualCalibrationScreen: ManualCalibrationDelegate {

    func calibration(didUpdate selection: CalibrationSelection) {
        Task { @MainActor in
            self.selection = selection
        }
    }

    func calibration(didComplete result: CalibrationResult) {
        Task { @MainActor in
            onCalibrationComplete(result)
        }
    }

    func calibration(didFail error: Error) {
        Task { @MainActor in
            if let error = error as? CalibrationError, case .pointsTooClose = error {
                alertMessage = "CALIBRATION_POINTS_TOO_CLOSE".localized(userManager.userLanguage)
            } else {
                alertMessage = error.localizedDescription
            }
            isShowAlert = true
        }
    }

}

// MARK: - Camera tap overlay

private struct CameraTapView: UIViewRepresentable {

    var onTap: (CGPoint) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                          action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    final class Coordinator: NSObject {
        var onTap: (CGPoint) -> Void
        init(onTap: @escaping (CGPoint) -> Void) { self.onTap = onTap }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            onTap(gesture.location(in: gesture.view))
        }
    }
}
