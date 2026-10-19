//
//  ViewARPreview.swift
//  Quick3D
//
//  Created by HaNST on 17/4/26.
//

import SwiftUI
import SceneKit

struct ViewARPreview: View {
    
    @EnvironmentObject private var userManager: UserManager
    
    @Binding var isPreview: Bool
    @Binding var arContext: ViewARContext
    
    @State private var context: ViewARPreviewContext = .init()
    
    @State private var currentScale: CGFloat = 95.0
    @State private var lastScale: CGFloat = 95.0
    @State private var isUserControl: Bool = false

    @State private var position: SIMD3<Float> = .zero
    
    @State private var icSize: CGFloat = 18
    @State private var btnSize: CGFloat = 30

    @State private var startPoint: CGPoint?
    
    @State private var isExpanded: Bool = false
    
    @State private var colorColumn: Int = 0
    
    @State private var colorRow: Int = 0
    
    @AppStorage("arPreviewColorIndex") private var colorIndex: Int = 2
    
    let items: [Color] = [.init(hex: "#448AFF"), .init(hex: "#B6F10D"), .white, .black, .red]
    
    let borders: [Color] = [.white, .white, .black, .white, .white]

    
    private func controlCamera() {
        if !isUserControl {
            isUserControl = true
            position = context.cameraTransform.columns.3.xyz
            currentScale = 100.0 - CGFloat(context.cameraInitDistance / context.cameraMaxDistance * 100)
            lastScale = currentScale
        }
    }
    
    private func resetCamera() {
        currentScale = 100.0 - CGFloat(context.cameraInitDistance / context.cameraMaxDistance * 100)
        lastScale = currentScale
        position = .zero
        isUserControl = false
        
        context.resetCamera()
    }
    
    func projectOnPlane(_ point: CGPoint, y: Float, in view: SCNView) -> SIMD3<Float>? {
        let near = view.unprojectPoint(SCNVector3(point.x, point.y, 0))
        let far  = view.unprojectPoint(SCNVector3(point.x, point.y, 1))

        let dir = SIMD3<Float>(far) - SIMD3<Float>(near)

        let t = (y - near.y) / dir.y
        guard t.isFinite else { return nil }

        return SIMD3<Float>(near) + dir * t
    }
    
    var body: some View {
        ZStack {
            SCNPreviewView(context: $context)
                .ignoresSafeArea()
                .onLoad {
                    arContext.previewContext = context
                    context.load(arContext)
                    if !items.indices.contains(colorIndex) {
                        colorIndex = 2
                    }
                    context.setBackgroundColor(UIColor(items[colorIndex]))
                }
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            
                            controlCamera()
                            
                            let delta = log(value)
                            let sensitivity: CGFloat = currentScale > 50 ? 0.4 : 1.0
                            let slowDown = 1 / (1 + log(currentScale))   // scale lớn → chậm lại
                            let newScale = lastScale * exp(delta * sensitivity * slowDown)
                            currentScale = min(max(newScale, 1), 99)
                            context.updateCamera(Float(100 - currentScale) / 100 * context.cameraMaxDistance, isUserControl: true)
                        }
                        .onEnded { _ in
                            lastScale = currentScale
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if startPoint == nil {
                                controlCamera()
                                startPoint = value.startLocation
                                context.calculateFOV()
                            }
                            let translated = context.translated(left: Float(value.location.x - value.startLocation.x), down: Float(value.location.y - value.startLocation.y))
                            context.updateCamera(position + translated, isUserControl: true)
                        }
                        .onEnded { value in
                            startPoint = nil
                            let translated = context.translated(left: Float(value.location.x - value.startLocation.x), down: Float(value.location.y - value.startLocation.y))
                            position += translated
                            context.updateCamera(position, isUserControl: true)
                        }
                )
            
            
            VStack {
//                HStack {
//                    Button {
//                        isPreview = false
//                    } label: {
//                        HStack(spacing: 8) {
//                            Image(systemName: "chevron.backward")
//                                .frame(width: UIDevice.current.isIphone ? 18 : 24,
//                                       height: UIDevice.current.isIphone ? 18 : 24)
//                            
//                            Text("BACK".localized(userManager.userLanguage))
//                                .font(.system(size: 16))
//                                .fixedSize(horizontal: true, vertical: false)
//                        }
//                        .foregroundColor(.white)
//                    }
//                    .padding(.leading, 16)
//                    .contentShape(Rectangle())
//                    
//                    Spacer()
//                }
                
                VStack {
                        GeometryReader { geo in

                            if colorColumn == 0 {
                                Color.clear
                                    .onAppear {
                                        let height = geo.size.height
                                        colorRow = Int(height / btnSize) - 1
                                        colorColumn = (items.count + colorRow - 1) / colorRow
                                    }
                            }
                            
                            HStack {
                                ForEach(0..<colorColumn, id: \.self) { col in
                                    VStack {
                                        Spacer()
                                        ForEach(0..<colorRow, id: \.self) { row in
                                            let index = col * colorRow + row
                                            if  index < items.count {
                                                CircleButton(
                                                    icon: Image(systemName: "circle.fill"),
                                                    iconSize: btnSize - 4,
                                                    backgroundColor: colorIndex == index ? borders[index] : items[index],
                                                    foregroundColor: items[index],
                                                    isShowStroke: false,
                                                    buttonSize: btnSize,
                                                    action: {
                                                        colorIndex = index
                                                        context.setBackgroundColor(UIColor(items[index]))
                                                    }
                                                )
                                            }
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .environment(\.layoutDirection, .rightToLeft)
                            .opacity(isExpanded ? 1 : 0)
                            .padding(.trailing, 10)
                        }
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                
                HStack {
                    if isUserControl {
                        CircleButton(
                            icon: Image(systemName: "arrow.uturn.backward"),
                            iconSize: icSize,
                            backgroundColor: borders[colorIndex].opacity(0.6),
                            isShowStroke: false,
                            buttonSize: btnSize,
                            action: {
                                resetCamera()
                            }
                        )
                        .padding(.leading, 10)
                        .padding(.bottom, 10)
                        
                    }
                    
                    Spacer()
                    
                    CircleButton(
                        icon: Image(systemName: isExpanded ? "xmark" : "plus"),
                        iconSize: icSize,
                        backgroundColor: isExpanded ? .red : .blue,
                        isShowStroke: false,
                        buttonSize: btnSize,
                        action: {
                            withAnimation(
                                .spring(response: 0.4, dampingFraction: 0.7)
                            ) {
                                isExpanded.toggle()
                            }
                        }
                    )
                    .padding(.trailing, 10)
                    .padding(.bottom, 10)
                }
            }
        }
    }
}
