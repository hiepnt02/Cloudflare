//
//  OtherDebugView.swift
//  Quick3D
//
//  Created by HungNT on 3/6/26.
//

import SwiftUI
import VigramSDK
import Combine

struct OthersDebugView: View {
    
    @ObservedObject private var thermalMonitor = ThermalMonitor.shared
    @ObservedObject private var arTrackingObject = ARTrackingObject.shared
    
    var body: some View {
        VStack {
            DebugTitleView(label: "Others")
            DebugItemView(label: "Thermal", value: "\(thermalMonitor.state)")
            DebugItemView(label: "ARCamera", value: {
                if case .limited(let reason) = arTrackingObject.currentState {
                    let reasonText: String
                    switch reason {
                    case .initializing: reasonText = "initializing"
                    case .excessiveMotion: reasonText = "excessiveMotion"
                    case .insufficientFeatures: reasonText = "insufficientFeatures"
                    case .relocalizing: reasonText = "relocalizing"
                    @unknown default: reasonText = "unknown"
                    }
                    return "limited\n\(reasonText)"
                }
                return "\(arTrackingObject.currentState)"
            }(), lineLimit: 2)
            
        }
        .padding(8)
        .foregroundColor(.white)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(imperialBlue.opacity(0.5))
        )
    }
}
