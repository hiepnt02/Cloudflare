//
//  PreviewView.swift
//  Quick3D
//
//  Created by HaNST on 09/09/25.
//

import SceneKit
import SwiftUI

struct PreviewView: View {
    
    @EnvironmentObject private var arObject: ARObject
    
    @State private var isCameraHidden = false
    @State private var isPointCloudHidden = false
    @State private var isExpanded = false
    @State private var isUserControl = false
    
    @Binding var context: CapturePreviewContext
    
    @State private var icSize: CGFloat = 14
    @State private var btnSize: CGFloat = 30
    
    var body: some View {
        ZStack {
            SCNPreviewView(context: $context)
            .onAppear {
                context.perform(PreviewHiddenEvent(isCameraHidden: isCameraHidden, isPointCloudHidden: isPointCloudHidden))
            }

            VStack {
                Spacer()
                HStack {

                    if isUserControl {
                        CircleButton(
                            icon: Image(systemName: "arrow.uturn.backward"),
                            iconSize: icSize,
                            backgroundColor: Color.black.opacity(0.6),
                            isShowStroke: false,
                            buttonSize: btnSize,
                            action: {
                                isUserControl = false
                                context.perform(ResetCameraEvent())
                            }
                        )
                        .padding()
                    }

                    Spacer()

                    ZStack {
                        // Camera button
                        CircleButton(
                            icon: Image(systemName: "camera.fill"),
                            iconSize: icSize,
                            backgroundColor: isCameraHidden ? .gray : .blue,
                            isShowStroke: false,
                            buttonSize: btnSize,
                            action: {
                                isCameraHidden.toggle()
                                context.perform(PreviewHiddenEvent(isCameraHidden: isCameraHidden, isPointCloudHidden: isPointCloudHidden))
                            }
                        )
                        .offset(y: isExpanded ? -104 : 0)
                        .opacity(isExpanded ? 1 : 0)

                        // Grid button
                        CircleButton(
                            icon: Image(systemName: "circle.grid.2x2.fill"),
                            iconSize: icSize,
                            backgroundColor: isPointCloudHidden ? .gray : .green,
                            isShowStroke: false,
                            buttonSize: btnSize,
                            action: {
                                isPointCloudHidden.toggle()
                                context.perform(PreviewHiddenEvent(isCameraHidden: isCameraHidden, isPointCloudHidden: isPointCloudHidden))
                            }
                        )
                        .offset(y: isExpanded ? -52 : 0)
                        .opacity(isExpanded ? 1 : 0)

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
                        
                    }
                    .padding()
                }
            }
        }
        .onLoad {
            context.delegate = self
            let live = context.live
            self.icSize = UIDevice.current.isIphone ? (live ? 14 : 18) : (live ? 20 : 24)
            self.btnSize = UIDevice.current.isIphone ? (live ? 30 : 40) : (live ? 40 : 56)
        }
    }

}

extension PreviewView: PreviewDelegate {
    func preview(_ session: CaptureSession?, didControlCamera isControl: Bool) {
        if isUserControl == isControl {
            return
        }
        isUserControl = isControl
    }
}
