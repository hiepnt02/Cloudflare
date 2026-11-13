//
//  ProgressLoadingView.swift
//  Quick3D
//
//  Created by HungNT on 3/2/26.
//

import SwiftUI

struct ProgressLoadingView: View {
    let text: String
    
    // Customization - Sử dụng default values trực tiếp
    var textColor: Color = .white.opacity(0.6)
    var textFont: Font = .system(size: 16, weight: .medium, design: .rounded)
    var spinnerColor: Color = .white // Đồng bộ với ProgressView
    var spinnerSize: CGFloat = 24
    var spacing: CGFloat = 12
    var bgOpacity: Double = 0.5
    
    // Chặn tương tác người dùng
    var isIgnoreTap: Bool = true
    
    var body: some View {
        ZStack {
            // Lớp nền mờ (Overlay)
            Color.black.opacity(bgOpacity)
                .ignoresSafeArea()
            
            VStack(spacing: spacing) {
                ProgressView()
                    .tint(spinnerColor) // Cách đổi màu spinner hiện đại
                    .scaleEffect(spinnerSize / 20) // Điều chỉnh kích thước
                
                if !text.isEmpty {
                    Text(text)
                        .font(textFont)
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.center)
                }
            }
        }
        // Chặn hoặc cho phép chạm xuyên qua lớp loading
        .allowsHitTesting(isIgnoreTap)
    }
}
