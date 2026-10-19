//
//  ExportPreviewView.swift
//  Quick3D
//
//  Created by HaNST on 09/09/25.
//

import SwiftUI
import SceneKit
import simd

struct ExportPreviewPopup: View {
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var arObject: ARObject
    
    @Binding var isShow: Bool
    @Binding var projectName: String

    var savedHander: (() -> Void)?
    var exportedHander: (() -> Void)?
    var abortHandler: (() -> Void)?

    @State private var context = CapturePreviewContext(live: false)
    
    @FocusState private var focusState: Bool

    @State private var isShowingAlert = false
    @State private var hasAnyRTKFrame: Bool? = nil
    
    @State private var isHandleSaving = false
    @State private var isHandleExporting = false
    
    var body: some View {
        VStack(spacing: 0) {
            PopupTitle(
                title: "SAVE_THE_CAPTURED_IMAGE".localized(userManager.userLanguage).capitalized,
                isShow: $isShow
            ) {
                abortHandler?()
            }
            
            ScrollView(showsIndicators: true) {
                contentView()
            }
            
            VStack {
                Rectangle()
                    .fill(.gray)
                    .frame(height: 1)
                
                LoadingButton(
                    label: "SAVE_LOCALLY".localized(userManager.userLanguage),
                    isStroke: true,
                    isShowLoading: $isHandleSaving,
                    onClick: {
                        isHandleSaving = true
                        onSaveProject(isExport: false)
                    }
                )
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .disabled(isHandleSaving || isHandleExporting || projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(isHandleSaving ? 0.5 : 1.0)
                
                LoadingButton(
                    label: "UPLOAD".localized(userManager.userLanguage),
                    isShowLoading: $isHandleExporting,
                    onClick: {
                        isHandleExporting = true
                        onSaveProject(isExport: true)
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .disabled(isHandleSaving || isHandleExporting || projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(isHandleExporting ? 0.5 : 1.0)
            }
            .background(userManager.setting.themeColor)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .background(userManager.setting.themeColor)
        .navigationBarHidden(true)
        .alert(isPresented: $isShowingAlert) {
            showAlert()
        }
        .onAppear {
            Task {
                guard let frames = CaptureSession.current?.frames else {
                    await MainActor.run { hasAnyRTKFrame = LocationManager.shared.isRTK }
                    return
                }
                let anyRTK = frames.contains { $0.isRTK }
                await MainActor.run { hasAnyRTKFrame = anyRTK || LocationManager.shared.isRTK }
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    private func contentView() -> some View {
        VStack(alignment: .leading) {
            Text("NAME".localized(userManager.userLanguage))
                .font(.system(size: 14))
                .foregroundColor(userManager.setting.textColor)
                .padding(.bottom, 16)
            
            TextField(
                "PROJECT_NAME".localized(userManager.userLanguage),
                text: $projectName
            )
            .foregroundColor(userManager.setting.textColor)
            .disableAutocorrection(true)
            .padding(.horizontal, 10)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isShowingAlert ? .red : .gray, lineWidth: 1)
                    .overlay(alignment: .bottom) {
                        if focusState {
                            Rectangle().frame(height: 2).foregroundColor(.blue)
                        }
                    }
                    .frame(height: UserSession.isIPhone ? 40 : 55, alignment: .leading)
            )
            .modifier(ClearButton(text: $projectName))
            .font(.body)
            .focused($focusState)
            .padding(.bottom, 16)
            
            pointCloudPreview()
            
            Text("REPORT".localized(userManager.userLanguage))
                .font(.system(size: 16).bold())
                .foregroundColor(userManager.setting.textColor)
                .padding(.top, 16)
            
            Text("IMAGE".localized(userManager.userLanguage))
                .font(.system(size: 16))
                .foregroundColor(userManager.setting.textColor)
                .padding(.top, 16)
            
            itemInfo(
                label: "IMAGE".localized(userManager.userLanguage),
                content: "\(arObject.imageIndex)"
            )
            
            Text("GEOLOCATION".localized(userManager.userLanguage))
                .font(.system(size: 16))
                .foregroundColor(userManager.setting.textColor)
                .padding(.top, 16)
            
            itemInfo(
                label: "GEOLOCATION_SOURCE".localized(userManager.userLanguage),
                content: hasAnyRTKFrame == true ? "RTK" : "GPS"
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, popupHPadding)
        .padding(.bottom, 16)
    }
    
    private func itemInfo(
        label: String,
        content: String
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(userManager.setting.textColor)
            
            Spacer()
            
            Text(content)
                .font(.system(size: 20).bold())
                .foregroundColor(userManager.setting.textColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(userManager.setting.itemBgColor)
        .cornerRadius(8)
    }
    
    private func pointCloudPreview() -> some View {
        ZStack(alignment: .topLeading) {
            PreviewView(context: $context)
            
            VStack {
                HStack {
                    Spacer()
                    Text(hasAnyRTKFrame == true ? "RTK" : "GPS")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(8)
                        .padding(.top, 12)
                        .padding(.trailing, 12)
                }
                Spacer()
            }
                            
            
            if let isRtk = hasAnyRTKFrame, isRtk {
                VStack(alignment: .leading, spacing: 8) {
                    AccuracyRow(color: .green, radius: 5, text: "OPTIMAL".localized(userManager.userLanguage))
                    AccuracyRow(color: .yellow, radius: 7, text: "REDUCED".localized(userManager.userLanguage))
                    AccuracyRow(color: .red, radius: 9, text: "LOW".localized(userManager.userLanguage))
                }
                .padding(EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 0))
            }
        }
        .frame(height: 350)
    }
    
    private func onSaveProject(isExport: Bool) {
        guard !StorageManager.shared.isDuplicateZipFileName(projectName) else {
            isShowingAlert = true
            return
        }
        
        if isExport {
            exportedHander?()
        } else {
            CaptureSession.current?.name = projectName
            savedHander?()
        }
        
        isShowingAlert = false
        isShow = false
        isHandleSaving = false
        isHandleExporting = false
    }
    
    private func showAlert() -> Alert {
        return Alert(
            title: Text("SAVE_ERROR".localized(userManager.userLanguage)),
            message: Text("ERROR_DUPLICATE_FILE_NAME".localized(userManager.userLanguage)),
            dismissButton: Alert.Button.destructive(
                Text("OK"),
                action: {
                    // Do nothin
                    isHandleSaving = false
                    isHandleExporting = false
                }
            )
        )
    }
}

struct AccuracyRow: View {
    let color: Color
    let radius: CGFloat
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: radius * 2, height: radius * 2)
                .padding(.leading, 10 - radius)
            
            Text(text)
                .frame(alignment: .leading)
                .foregroundColor(.white)
                .padding(.leading, 16 - radius)
        }
    }
}
