//
//  ProgressLoadingView.swift
//  Quick3D
//
//  Created by HungNT on 3/2/26.
//

import SwiftUI

struct ProgressLoadingView: View {
    let text: String
    
    // Customization - use default values directly
    var textColor: Color = .white.opacity(0.6)
    var textFont: Font = .system(size: 16, weight: .medium, design: .rounded)
    var spinnerColor: Color = .white // Kept in sync with ProgressView
    var spinnerSize: CGFloat = 24
    var spacing: CGFloat = 12
    var bgOpacity: Double = 0.5
    
    // Block user interaction
    var isIgnoreTap: Bool = true
    
    var body: some View {
        ZStack {
            // Dimmed background layer (Overlay)
            Color.black.opacity(bgOpacity)
                .ignoresSafeArea()
            
            VStack(spacing: spacing) {
                ProgressView()
                    .tint(spinnerColor) // Modern way to change the spinner color
                    .scaleEffect(spinnerSize / 20) // Adjust the size
                
                if !text.isEmpty {
                    Text(text)
                        .font(textFont)
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.center)
                }
            }
        }
        // Block or allow taps to pass through the loading layer
        .allowsHitTesting(isIgnoreTap)
    }
}
