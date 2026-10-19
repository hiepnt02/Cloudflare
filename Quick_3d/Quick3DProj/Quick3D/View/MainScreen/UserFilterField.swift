//
//  UserFilterField.swift
//  Quick3D
//
//  Created by HungNT on 20/5/26.
//

import SwiftUI

struct UserFilterField: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var productData: ProductData

    @Binding var isPopupUserPresented: Bool
    @Binding var tfUserPosition: CGPoint
    @Binding var tfUserWidth: CGFloat
    @Binding var tfUserHeight: CGFloat
    let isIPhone: Bool

    private var title: String {
        productData.selectedUser?.dropdownTitle(in: userManager.userLanguage) ?? ""
    }

    var body: some View {
        Button(action: { isPopupUserPresented.toggle() }) {
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
                    .rotationEffect(.degrees(isPopupUserPresented ? 180 : 0))
                    .padding(.trailing, isIPhone ? 0 : 10.0)
            }
            .frame(width: isIPhone ? 115 : 190, height: isIPhone ? 32 : 42, alignment: .leading)
            .contentShape(Rectangle())
        }
        .border(.gray, width: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("PHOTOGRAPHER".localized(userManager.userLanguage)))
        .accessibilityValue(Text(title))
        .accessibilityAddTraits(.isButton)
        .overlay(alignment: .topLeading) {
            Text("PHOTOGRAPHER".localized(userManager.userLanguage))
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
                        tfUserPosition = geometry.frame(in: .global).origin
                        tfUserWidth = geometry.size.width
                        tfUserHeight = geometry.size.height
                    }
                    .onChange(of: geometry.frame(in: .global).origin) { newPos in
                        tfUserPosition = newPos
                    }
                    .onChange(of: geometry.size) { newSize in
                        tfUserWidth = newSize.width
                        tfUserHeight = newSize.height
                    }
            }
        )
    }
}
