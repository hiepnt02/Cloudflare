//
//  PoupTitle.swift
//  Quick3D
//
//  Created by HungNT on 29/12/25.
//

import SwiftUI

struct PopupTitle: View {
    @EnvironmentObject private var userManager: UserManager
    
    var title: String
    @Binding var isShow: Bool
    var bottomPadding: CGFloat = contentPadding

    var onClose: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: UIDevice.current.isIphone ? 16 : 20))
                .foregroundColor(userManager.setting.textColor)
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    isShow = false
                    onClose()
                }
            })
            {
                Image("closeIcon")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(userManager.setting.iconColor)
            }
            .frame(width: UIDevice.current.isIphone ? 18 : 24, height: UIDevice.current.isIphone ? 18 : 24)
            .contentShape(Rectangle())
        }
        .padding(.top, contentPadding)
        .padding(.horizontal, contentPadding)
        .padding(.bottom, bottomPadding)
    }
}
