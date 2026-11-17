//
//  ARVisibleScaleView.swift
//  Quick3D
//
//  Created by HungNT on 8/1/26.
//

import SwiftUI

struct ARVisibleScaleView: View {
    
    let title: String
    var isVisible: Bool
    @Binding var scale: CGFloat
    
    var onVisibilityChanged: (Bool) -> Void
    var onScaleChanged: (CGFloat) -> Void
    var isVisibilityLocked: Bool = false
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                onVisibilityChanged(!isVisible)
            }) {
                Image(isVisible ? "eye" : "eye-off")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(isVisible ? .white : .white.opacity(0.5))
                    .frame(width: 16, height: 16)
            }
            .disabled(isVisibilityLocked)
            .opacity(isVisibilityLocked ? 0.5 : 1.0)

            Text(title)
                .font(.system(size: 16))
                .foregroundColor(Color.white)
                .opacity(isVisible ? 1.0 : 0.5)
                .lineLimit(2)
                .truncationMode(.tail)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            CameraSlider(
                value: $scale,
                range: 0...1.0,
                step: 0.0001,
                trackHeight: 8,
                bgTrackColor: lightGray,
                activeTrackColor: lavender,
                strokeDotColor: lavender,
                dotSize: 24
            )
            .padding(.leading, 12)
            .padding(.trailing, 40)
            .frame(width: UIScreen.main.bounds.width * (UIDevice.current.isIphone ? 0.6 : 0.33))
            .disabled(!isVisible)
            .opacity(isVisible ? 1.0 : 0.5)
            .onChange(of: scale) { newValue in
                guard isVisible else { return }
                onScaleChanged(newValue)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

enum ViewARVisibilityLock {
    // Chỉ khóa khi đang hiện, tránh kẹt ở trạng thái vừa ẩn vừa opacity 0
    static func isLocked(_ isVisible: Bool, _ opacity: CGFloat) -> Bool {
        isVisible && opacity <= 0
    }
}
