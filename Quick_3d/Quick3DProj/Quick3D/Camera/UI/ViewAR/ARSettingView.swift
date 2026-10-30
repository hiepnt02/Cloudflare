//
//  ARSettingView.swift
//  Quick3D
//
//  Created by Admin on 24/12/25.
//

import SwiftUI

struct ARSettingView: View {
    @EnvironmentObject private var userManager: UserManager
    
    @Binding var context: ViewARContext
    
    @Binding var isPointCloudRendered: Bool
    @Binding var isARPositionExpanded: Bool
    @Binding var isARStepExpanded: Bool
    
    @Binding var arRendered: Bool
    @Binding var arItemRendered: Bool
    @Binding var arCalculating: Bool
    
    @ObservedObject var arPosition: ARPosition
    @Binding var pointCloudScale: Double
    @Binding var pointCloudProgress: Double
    @Binding var arPositionInstruction: String
    
    @State var isPreview: Bool = false
    
    @Binding var isPointCloudVisible: Bool
    @Binding var pointOpacity: CGFloat
    
    @Binding var isARObjectVisisble: Bool
    @Binding var arObjectScale: CGFloat
    var onARObjectVisibilityChanged: (Bool) -> Void = { _ in }
    
    @State var isUpdateAROn: Bool = true
    @State private var animatedProgress: Double = 0.0
    //@State var isLightOn = true
    
    @AppStorage("isLightOn")
    private var isLightOn: Bool = true
    
    @AppStorage("positionHistoryMaxSize")
    private var positionHistoryMaxSize: String = "50"
    
    @AppStorage("positionHistoryHorizontal")
    private var positionHistoryHorizontal: String = "0.015"
    
    @AppStorage("positionHistoryDistance")
    private var positionHistoryDistance: String = "0.5"
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            
            // MARK: Setting Views
            Group {
                if !isARPositionExpanded && !isPreview {
                    HStack {
                        CircleButton(
                            icon: Image(systemName: "gearshape"),
                            iconSize: 20,
                            backgroundColor: imperialBlue.opacity(0.5),
                            foregroundColor: .white,
                            isShowStroke: true,
                            strokeColor: .white.opacity(0.3),
                            buttonSize: 48
                        ) {
                            isARPositionExpanded = true
                        }
                        
                        if arRendered {
                            CircleButton(
                                icon: Image(systemName: "map"),
                                iconSize: 20,
                                backgroundColor: imperialBlue.opacity(0.5),
                                foregroundColor: .white,
                                isShowStroke: true,
                                strokeColor: .white.opacity(0.3),
                                buttonSize: 48
                            ) {
                                isPreview = true
                            }
                        }
                        
                        Spacer()
                        
                        updateARView
                    }
                } else if isARPositionExpanded {
                    ARSettingDetailView(
                        context: context,
                        arPosition: arPosition,
                        isShow: $isARPositionExpanded,
                        isPointCloudVisible: $isPointCloudVisible,
                        isPointCloudRendered: $isPointCloudRendered,
                        pointCloudScale: $pointCloudScale,
                        pointCloudOpacity: pointOpacity,
                        isLightOn: $isLightOn,
                        isARPositionExpanded: $isARPositionExpanded,
                        isARStepExpanded: $isARStepExpanded,
                        isUpdateAROn: $isUpdateAROn
                    )
                } else if isPreview {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: { isPreview = false }) {
                                Image("closeIcon")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                            }
                        }
                        ViewARPreview(isPreview: $isPreview, arContext: $context)
                    }
                    .frame(height: 260)
                    .padding(EdgeInsets(top: 8, leading: 15, bottom: 15, trailing: 15))
                    .glassBackground()
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            
            // MARK: Sliders
            if isPointCloudRendered || arItemRendered {
                settingSlidersView
            }
            
            // MARK: Point Cloud loading progress
            if 0 < animatedProgress && animatedProgress < 1.0 {
                loadingProgressPCView
            }
            
//            arPositionInstructionView
        }
        .frame(maxWidth: UIDevice.current.isIphone ? .infinity : 580)
        .onLoad {
            updateCalculationSetting()
        }
        .onChange(of: pointCloudProgress) { newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                animatedProgress = newValue
            }
        }
    }
    
    @ViewBuilder
    private var updateARView: some View {
//        if arItemRendered || arRendered {
        Spacer()
        HStack {
            Text("AR_UPDATED".localized(userManager.userLanguage))
                .font(.system(size: 16))
                .foregroundColor(mintBreeze)
                .frame(height: 48)
            
            CustomToggle(isOn: $isUpdateAROn)
                .onChange(of: isUpdateAROn) { value in
                    context.perform(ViewARAllowCalculateEvent(value))
                }
                .padding(.leading, 8)
        }
        .padding(.horizontal, 16)
        .glassBackground()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
//        } else {
//            EmptyView()
//        }
    }
    
    private var formattedProgress: String {
        if animatedProgress >= 1.0 {
            return "100%"
        } else {
            return String(format: "%.2f%%", animatedProgress * 100)
        }
    }
    
    private var settingSlidersView: some View {
        VStack {
            if isPointCloudRendered {
                ARVisibleScaleView(
                    title: "POINT_CLOUD".localized(userManager.userLanguage),
                    isVisible: isPointCloudVisible,
                    scale: $pointOpacity,
                    onVisibilityChanged: { visible in
                        isPointCloudVisible = visible
                        context.perform(ViewARPointcloudVisibleEvent(visible))
                    },
                    onScaleChanged: { scale in
                        pointOpacity = scale
                        context.perform(ViewARPointcloudOpacityEvent(scale))
                    },
                    isVisibilityLocked: ViewARVisibilityLock.isLocked(isPointCloudVisible, pointOpacity)
                )
            }

            if arItemRendered {
                ARVisibleScaleView(
                    title: "DESIGN".localized(userManager.userLanguage),
                    isVisible: isARObjectVisisble,
                    scale: $arObjectScale,
                    onVisibilityChanged: { visible in
                        isARObjectVisisble = visible
                        context.perform(ViewARIFCVisibleEvent(nil, visible))
                        onARObjectVisibilityChanged(visible)
                    },
                    onScaleChanged: { scale in
                        arObjectScale = scale
                        context.perform(ViewARIFCOpacityEvent(nil, scale))
                    },
                    isVisibilityLocked: ViewARVisibilityLock.isLocked(isARObjectVisisble, arObjectScale)
                )
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .glassBackground()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
    }
    
    // Show loading process of point cloud
    private var loadingProgressPCView: some View {
        HStack {
            ProgressView(value: animatedProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                .background(Color.white.opacity(0.3))
                .cornerRadius(2)
            
            Text(formattedProgress)
                .font(.system(size: 14))
                .foregroundColor(Color.white)
                .padding(.leading, 8)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .glassBackground()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var arPositionInstructionView: some View {
        ZStack {
            Text(arPositionInstruction)
                .font(.system(size: 16))
                .foregroundColor(Color.white)
                .lineLimit(2)
                .truncationMode(.tail)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .glassBackground()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func updateCalculationSetting() {
        if let positionHisttoryMaxSize = Int(self.positionHistoryMaxSize),
           let positionHisttoryHorizontal = Double(self.positionHistoryHorizontal.forcedFormatNumber()),
           let positionHisttoryDistance = Double(self.positionHistoryDistance.forcedFormatNumber()) {
            context.perform(ViewARCalculationSettingEvent(positionHistoryMaxSize: positionHisttoryMaxSize, positionHistoryHorizontal: positionHisttoryHorizontal, positionHistoryDistance: positionHisttoryDistance))
        }
    }
}

