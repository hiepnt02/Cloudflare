//
//  LoadingButton.swift
//  Quick3D
//
//  Created by HungNT on 16/1/26.
//
import SwiftUI

struct LoadingButton: View {
    @EnvironmentObject private var userManager: UserManager
    @Environment(\.isEnabled) private var isEnabled

    var label: String
    var labelSize: CGFloat = 16
    var minHeight: CGFloat = 48
    var isStroke = false
    var backgroundColor: Color = sapphireBlue
    @Binding var isShowLoading: Bool

    var onClick: () -> Void

    private var contentColor: Color {
        isStroke ? userManager.setting.textColor : .white
    }

    var body: some View {
        Button(action: onClick) {
            HStack {
                if isShowLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(contentColor)
                        .scaleEffect(0.8)
                        .frame(width: 20, height: 20)
                }

                Text(label)
                    .font(.system(size: labelSize, weight: .medium))
                    .foregroundColor(contentColor)
            }
            .padding(8)
            .frame(
                minWidth: UIDevice.current.isIphone ? nil : 230,
                maxWidth: UIDevice.current.isIphone ? .infinity : nil,
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
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(SquishButtonStyle())
    }
}
