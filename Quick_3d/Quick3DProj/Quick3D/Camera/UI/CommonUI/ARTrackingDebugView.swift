//
//  ARTrackingDebugView.swift
//  Quick3D
//

import SwiftUI
import ARKit

struct ARTrackingDebugView: View {
    @ObservedObject private var arTrackingObject = ARTrackingObject.shared

    private struct TrackingOption {
        let label: String
        let state: ARCamera.TrackingState
    }

    private let options: [TrackingOption] = [
        TrackingOption(label: "normal",               state: .normal),
        TrackingOption(label: "notAvailable",         state: .notAvailable),
        TrackingOption(label: "initializing",         state: .limited(.initializing)),
        TrackingOption(label: "excessiveMotion",      state: .limited(.excessiveMotion)),
        TrackingOption(label: "insufficientFeatures", state: .limited(.insufficientFeatures)),
        TrackingOption(label: "relocalizing",         state: .limited(.relocalizing)),
    ]

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            ForEach(options, id: \.label) { option in
                Button(action: {
                    arTrackingObject.update(state: option.state)
                }) {
                    Text(option.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isActive(option.state) ? .black : .white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isActive(option.state) ? Color.yellow : imperialBlue.opacity(0.6))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func isActive(_ state: ARCamera.TrackingState) -> Bool {
        switch state {
        case .normal:
            if case .normal = arTrackingObject.currentState { return true }
        case .notAvailable:
            if case .notAvailable = arTrackingObject.currentState { return true }
        case .limited(let reason):
            if case .limited(let current) = arTrackingObject.currentState {
                switch (current, reason) {
                case (.initializing, .initializing),
                     (.excessiveMotion, .excessiveMotion),
                     (.insufficientFeatures, .insufficientFeatures),
                     (.relocalizing, .relocalizing):
                    return true
                default: break
                }
            }
        @unknown default: break
        }
        return false
    }
}
