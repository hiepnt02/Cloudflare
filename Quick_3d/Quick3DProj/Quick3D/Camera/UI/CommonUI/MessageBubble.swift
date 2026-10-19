//
//  MessageBubble.swift
//  Quick3D
//
//  Created by Admin on 8/6/26.
//

import SwiftUI

struct MessageBubble: View {
    
    struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.midX, y: 0))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: 0, y: rect.maxY))
                path.closeSubpath()
            }
        }
    }
    
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text(text)
                    .font(.system(size: 10))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .foregroundColor(.white)
                    .background(.red)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )
            }
            .padding(.trailing, 3)
            Spacer()
        }
    }
}


