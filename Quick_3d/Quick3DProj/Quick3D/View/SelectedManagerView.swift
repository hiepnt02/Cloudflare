//
//  SelectedManagerView.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 02/06/2022.
//

import SwiftUI

struct SelectedManagerView: View {
    @EnvironmentObject var userManager: UserManager
    let selectedCount: Int
    let allowTap: Bool
    var didTapDelete: () -> Void
    var didTapCancel: () -> Void
    @State private var isIPhone: Bool = (UIDevice.current.userInterfaceIdiom == .phone) ? true : false

    var body: some View {
        HStack(spacing: 20) {
            Spacer()
            Button(action: {
                didTapCancel()
            }, label: {
                Text("CANCEL".localized(userManager.userLanguage))
                    .foregroundColor(userManager.setting.colorTheme == .light ? .black : .white)
                    .font(isIPhone ? .footnote : .title2)
                    .frame(height: isIPhone ? 30 : 50)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .background(userManager.setting.colorTheme == .light ? .white : .black)
                    .border(.gray, width: 1)
                    .contentShape(Rectangle())
            })
            

            Button(action: {
                didTapDelete()
            }, label: {
                Text(String(format: "\("ITEM_SELECTED".localized(userManager.userLanguage))", selectedCount))
                    .foregroundColor(.white)
                    .font(isIPhone ? .footnote : .title2)
                    .frame(height: isIPhone ? 30 : 50)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .background(Color.init(hex: 0x0064BA))
                    .contentShape(Rectangle())
            })
        }
        .frame(width: isIPhone ? 500 : 700 , height: isIPhone ? 30 : 50)
        .offset(x: 0, y: UIScreen.maxHeight/2 - (isIPhone ? 20 : 40))
    }
}
