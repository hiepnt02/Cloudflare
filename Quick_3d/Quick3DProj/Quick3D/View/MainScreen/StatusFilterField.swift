//
//  StatusFilterField.swift
//  Quick3D
//
//  Created by HungNT on 20/5/26.
//

import SwiftUI

struct StatusFilterField: View {
    @EnvironmentObject var userManager: UserManager

    @Binding var selectedStatus: Status
    @Binding var isPopupStatusPresented: Bool
    @Binding var tfStatusPosition: CGPoint
    @Binding var tfStatusWidth: CGFloat
    @Binding var tfStatusHeight: CGFloat
    let isIPhone: Bool

    private var title: String {
        selectedStatus.dropdownTitle(in: userManager.userLanguage)
    }

    var body: some View {
        Button(action: { isPopupStatusPresented.toggle() }) {
            HStack(spacing: 0) {
                Text(title)
                    .lineLimit(1)
                    .font(.system(size: isIPhone ? 12 : 15))
                    .foregroundColor(userManager.setting.textColor)
                    .padding(.leading, 10.0)
                    .frame(height: isIPhone ? 32 : 42, alignment: .leading)
                Spacer()
                Image("arrowDown")
                    .renderingMode(.template)
                    .foregroundColor(userManager.setting.textColor)
                    .rotationEffect(.degrees(isPopupStatusPresented ? 180 : 0))
                    .padding(.trailing, isIPhone ? 0 : 10.0)
            }
            .frame(width: isIPhone ? 115 : 190, height: isIPhone ? 32 : 42, alignment: .leading)
            .contentShape(Rectangle())
        }
        .border(.gray, width: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("STATUS".localized(userManager.userLanguage)))
        .accessibilityValue(Text(title))
        .accessibilityAddTraits(.isButton)
        .overlay(alignment: .topLeading) {
            Text("STATUS".localized(userManager.userLanguage))
                .font(.system(size: isIPhone ? 12 : 15))
                .foregroundColor(userManager.setting.labelColor)
                .background(userManager.setting.themeColor)
                .font(.subheadline)
                .offset(x: 10, y: -8)
                .accessibilityHidden(true)
        }
        .overlay(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        tfStatusPosition = geometry.frame(in: .global).origin
                        tfStatusWidth = geometry.size.width
                        tfStatusHeight = geometry.size.height
                    }
                    .onChange(of: geometry.frame(in: .global).origin) { newPos in
                        tfStatusPosition = newPos
                    }
                    .onChange(of: geometry.size) { newSize in
                        tfStatusWidth = newSize.width
                        tfStatusHeight = newSize.height
                    }
            }
        )
    }
}
