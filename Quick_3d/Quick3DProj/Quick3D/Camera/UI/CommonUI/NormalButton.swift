//
//  NormalButton.swift
//  Quick3D
//
//  Created by HungNT on 29/12/25.
//

import SwiftUI

struct NormalButton: View {
    @EnvironmentObject private var userManager: UserManager
    
    var label: String
    var labelSize: CGFloat = 16
    var minHeight: CGFloat = 48
    var maxWidth: CGFloat? = nil
    var isStroke = false
    var backgroundColor: Color = sapphireBlue
    var isDisabled: Bool = false
    
    var onClick: () -> Void
    
    var body: some View {
        Button(action: {
            onClick()
        }) {
            Text(label)
                .font(.system(size: labelSize, weight: .medium))
                .foregroundColor(isStroke ? userManager.setting.textColor : .white)
                .padding(8)
                .frame(
                    minWidth: UIDevice.current.isIphone ? nil : 230,
                    maxWidth: UIDevice.current.isIphone ? .infinity : maxWidth,
                    minHeight: minHeight
                )
                .background(
                    Group {
                        if isStroke {
                            Rectangle()
                                .stroke(userManager.setting.textColor, lineWidth: 1)
                        } else {
                            backgroundColor
                        }
                    }
                )
                .contentShape(Rectangle())
                .opacity(isDisabled ? 0.5 : 1)
        }
        .buttonStyle(SquishButtonStyle())
        .disabled(isDisabled)
    }
}
