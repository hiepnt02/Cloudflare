//
//  HomeButton.swift
//  Quick3D
//
//  Created by HungNT on 23/12/25.
//

import SwiftUI

struct HomeButton: View {
    
    var iconColor: Color = .white
    var size: CGFloat = 52
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: borderNormal, style: .continuous)
                .fill(imperialBlue.opacity(0.5))
                .frame(width: size, height: size)
                .overlay(
                    Image("ic_home_fill_white")
                        .foregroundColor(iconColor)
                        .frame(width: size / 2, height: size / 2)
                )
        }
        .buttonStyle(SquishButtonStyle())
    }
}
