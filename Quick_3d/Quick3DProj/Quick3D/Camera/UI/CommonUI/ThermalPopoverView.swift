//
//  ThermalPopoverView.swift
//  Quick3D
//
//  Created by HungNT on 30/6/26.
//

import SwiftUI

struct ThermalPopoverView: View {
    let text: String
    var offsetValue: CGSize

    var body: some View {
        VStack(spacing: 0) {
            TriangleArrow()
                .fill(rubyRed)
                .frame(width: 15, height: 15)
                .offset(x: 70, y: 0)
            
            Text(text)
                .font(.system(size: 10))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .foregroundColor(.white)
                .background(rubyRed)
                .clipShape(
                    RoundedRectangle(cornerRadius: 16)
                )
        }
        .offset(x: offsetValue.width, y: offsetValue.height)
    }
}

struct TriangleArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
