//
//  CaptureDebugView.swift
//  Quick3D
//
//  Created by HungNT on 3/6/26.
//

import SwiftUI

struct CaptureDebugView: View {
    
    @EnvironmentObject private var cameraObject: CameraObject
    
    var body: some View {
        VStack {
            DebugTitleView(label: "OVERLAP")
            DebugItemView(label: "Z", value: "\(cameraObject.zDistance)")
            DebugItemView(label: "Ratio", value: "\(cameraObject.debugOverlapRatio)")
        }
        .padding(8)
        .foregroundColor(.white)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(imperialBlue.opacity(0.5))
        )
    }
}
