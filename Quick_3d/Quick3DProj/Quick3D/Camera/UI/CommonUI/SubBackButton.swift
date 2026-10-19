//
//  SubMenuToolbarView.swift
//  Quick3D
//
//  Created by HungNT on 5/1/26.
//

import SwiftUI

struct SubBackButton: View {
    @EnvironmentObject private var userManager: UserManager
    
    var title: String = ""
    var isBoldTitle: Bool = false
    var onBack: () -> Void

    var body: some View {
        Button(action: onBack) {
            HStack(spacing: 8) {
                Image("ic_arrow_back_white")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIDevice.current.isIphone ? 18 : 24,
                           height: UIDevice.current.isIphone ? 18 : 24)
                
                Text(title)
                    .font(.system(size: 16))
                    .fontWeight(isBoldTitle ? .bold : .regular)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundColor(userManager.setting.textColor)
        }
    }
}
