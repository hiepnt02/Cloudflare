//
//  PointRemoveFilterButtonView.swift
//  Quick3D
//
//  Created by HungNT on 20/5/26.
//

import SwiftUI

struct PointRemoveFilterButtonView: View {
    @EnvironmentObject var userManager: UserManager
    
    @Environment(\.isPortraitLayout) private var isPortraitLayout

    @Binding var isPointRemoveSelected: Bool
    let isIPhone: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(
            action: {
                isPointRemoveSelected.toggle()
                onTap()
            },
            label: {
                Text("REMOVE_POINT_CLOUD".localized(userManager.userLanguage))
                    .foregroundColor(isPointRemoveSelected ? Color.white : userManager.setting.textColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: isPortraitLayout, vertical: false)
                    .padding(.horizontal, isPortraitLayout ? 12 : 0)
                    // Ở dọc bỏ bề rộng cố định để chữ hiện đủ; ngang giữ nguyên kích thước cũ.
                    .frame(width: isPortraitLayout ? nil : (isIPhone ? 40 : 50),
                           height: isIPhone ? 32 : 42)
                    .border(.gray, width: 1)
                    .font(isIPhone ? .system(size: 12) : .system(size: 16))
            }
        )
        .buttonStyle(.plain)
        .background(isPointRemoveSelected ? userManager.setting.buttonColor : userManager.setting.themeColor)
        .padding(1)
    }
}
