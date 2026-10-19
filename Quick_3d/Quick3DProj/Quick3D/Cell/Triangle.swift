//
//  Triangle.swift
//  Quick3D
//
//  Created by HungNT on 13/5/26.
//

import SwiftUI

// MARK: - Helper Views
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX - 10, y: rect.maxY - 10))
        path.addLine(to: CGPoint(x: rect.midX + 10, y: rect.maxY - 10))
        path.closeSubpath()
        return path
    }
}
