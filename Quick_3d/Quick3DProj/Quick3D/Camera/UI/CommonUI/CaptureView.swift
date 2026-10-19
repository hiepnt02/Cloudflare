//
//  CaptureView.swift
//  Quick3D
//
//  Created by HaNST on 13/10/25.
//

import SwiftUI

struct CaptureView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var arObject: ARObject
    
    let captureAction: () -> Void
    
    let saveAction: () -> Void
    
    let openSettingAction: () -> Void
    
    let abortAction: () -> Void
    
    @State private var isExpandPreview: Bool = false
    
    @State private var previewContext = CapturePreviewContext(live: true)
    
    private var isShow: Bool {
        arObject.status == .running || arObject.status == .paused || arObject.status == .pausing
    }

    var body: some View {
        VStack(spacing: 12) {
            if arObject.status == .running {
                actionButton(
                    iconName: "ic_arrow_down_white",
                    iconSize: 16,
                    buttonSize: 32,
                    rotation: isExpandPreview ? 0 : 180,
                    onClick: { isExpandPreview.toggle() }
                )
            }
            
            if isExpandPreview && arObject.status == .running {
                PreviewView(context: $previewContext)
                    .frame(height: 150)
                    .padding(.horizontal, 12)
                    .onAppear() {
                        CaptureSession.current?.livePreviewContext = previewContext
                        previewContext.perform(ChangeModeEvent(UserSession.shared.previewMode == .topView))
                    }
                    .onDisappear {
                        CaptureSession.current?.livePreviewContext = nil
                    }
            }
            
            HStack {
                Spacer()

                actionButton(
                    iconName: arObject.status == .running ? "ic_close_white" : "ic_settings_white",
                    onClick: arObject.status == .running ? abortAction : openSettingAction
                )
                .frame(maxWidth: .infinity)

                Spacer()

                captureButton(onClick: arObject.status == .running ? saveAction : captureAction)
                    .frame(maxWidth: .infinity)

                Spacer()

                imageCountView()
                    .frame(maxWidth: .infinity)
                    .opacity(isShow ? 1 : 0)

                Spacer()
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: UIDevice.current.isIphone ? .infinity : (arObject.status == .running ? 580 : 350))
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: UIDevice.current.isIphone ? 32 : 100)
                    .fill(imperialBlue.opacity(0.5))
                    .opacity(arObject.status != .running ? 1 : 0)
                
                RoundedRectangle(cornerRadius: 32)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.1), imperialBlue.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(Color.white, lineWidth: 2)
                            .offset(y: 0.5)
                            .mask(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .black, location: 0.2),
                                        .init(color: .black, location: 0.8),
                                        .init(color: .clear, location: 1.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .mask(
                                    VStack {
                                        Rectangle().frame(height: 30)
                                        Spacer()
                                    }
                                )
                            )
                    )
                    .opacity(arObject.status == .running ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.3), value: arObject.status)
        )
    }
    
    private func actionButton(
        iconName: String,
        iconSize: CGFloat = 32,
        buttonSize: CGFloat = 56,
        rotation: Double = 0,
        onClick: @escaping () -> Void
    ) -> some View {
        Button(action: onClick) {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.5))

                Circle()
                    .strokeBorder(.white, lineWidth: 1)

                Image(iconName)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.white)
                    .frame(width: iconSize, height: iconSize)
                    .rotationEffect(.degrees(rotation))
            }
            .frame(width: buttonSize, height: buttonSize)
            .compositingGroup()
        }
        .contentShape(Circle())
        .buttonStyle(PlainButtonStyle())
    }
    
    private func captureButton(
        onClick: @escaping () -> Void
    ) -> some View {
        Button(action: onClick) {
            ZStack {
                Circle()
                    .strokeBorder(.white, lineWidth: 2)
                
                Image(
                    arObject.status == .running ? "ic_check_circle_green" : "ic_circle_red"
                )
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
            }
            .frame(width: 72, height: 72)
            .compositingGroup()
        }
        .contentShape(Circle())
        .buttonStyle(PlainButtonStyle())
    }
    
    private func imageCountView() -> some View {
        Text(
            String(
                format: "\("IMAGE_CAPTURED_COUNT_IPHONE".localized(userManager.userLanguage))",
                arObject.imageIndex
            )
        )
        .font(.system(size: 16))
        .fixedSize(horizontal: false, vertical: true)
        .foregroundColor(.white)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.black.opacity(0.5))
        )
    }
}
