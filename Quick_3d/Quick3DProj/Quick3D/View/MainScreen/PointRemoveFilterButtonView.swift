//
//  PointRemoveFilterButtonView.swift
//  Quick3D
//
//  Created by HungNT on 20/5/26.
//

import SwiftUI

struct PointRemoveFilterButtonView: View {
    @EnvironmentObject var userManager: UserManager
    
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
                    .frame(width: isIPhone ? 40 : 50, height: isIPhone ? 32 : 42)
                    .border(.gray, width: 1)
                    .font(isIPhone ? .system(size: 12) : .system(size: 16))
            }
        )
        .background(isPointRemoveSelected ? userManager.setting.buttonColor : userManager.setting.themeColor)
        .padding(1)
    }
}
