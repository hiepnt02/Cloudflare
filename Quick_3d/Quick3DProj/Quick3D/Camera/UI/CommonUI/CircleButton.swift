//
//  CircleButton.swift
//  Quick3D
//
//  Created by Admin on 26/9/25.
//

import SwiftUI

import SwiftUI

struct CircleButton: View {
    // 1. Chuyển các thuộc tính ít thay đổi thành let để SwiftUI dễ dàng so sánh view
    //let icon: String
    let icon: Image
    let iconSize: CGFloat
    
    let backgroundColor: Color
    let foregroundColor: Color
    
    let isShowStroke: Bool
    let strokeColor: Color
    
    let buttonSize: CGFloat
    
    let action: () -> Void
    
    // 2. Khởi tạo tập trung để tránh gọi UIDevice nhiều lần trong body
    init(
        icon: Image,
        iconSize: CGFloat = (UIDevice.current.userInterfaceIdiom == .phone) ? 32 : 40,
        backgroundColor: Color = .black,
        foregroundColor: Color = .white,
        isShowStroke: Bool = true,
        strokeColor: Color = .white,
        buttonSize: CGFloat = (UIDevice.current.userInterfaceIdiom == .phone) ? 40 : 56,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconSize = iconSize
        
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        
        self.isShowStroke = isShowStroke
        self.strokeColor = strokeColor
        
        self.buttonSize = buttonSize
        
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background Circle
                Circle()
                    .fill(backgroundColor)
                
                // Stroke Layer - Chỉ render khi cần
                if isShowStroke {
                    Circle()
                        .strokeBorder(strokeColor, lineWidth: 2)
                }
                
                // Icon Layer
                //Image(icon)
                icon
                    .renderingMode(.template) // Tối ưu cho việc đổi màu foreground
                    .imageScale(.medium) // Giúp icon đồng nhất quy chuẩn
                    .font(.system(size: iconSize))
                    .foregroundColor(foregroundColor)
                    .frame(width: iconSize, height: iconSize)
            }
            .frame(width: buttonSize, height: buttonSize)
            // 3. Sử dụng compositingGroup để gom nhóm shadow, tránh render shadow cho từng layer con
            .compositingGroup()
            .shadow(radius: 5)
        }
        // 4. Giới hạn vùng tương tác để tối ưu hit-testing
        .contentShape(Circle())
        .buttonStyle(PlainButtonStyle())
    }
}
