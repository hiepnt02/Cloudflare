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
    
    let userList: [User]
    let isIPhone: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Menu {
            ForEach(userList, id: \.self) { user in
                Button(user.name) {
                    productData.selectedUser = user
                    DispatchQueue.main.async {
                        onSelect()
                    }
                }
            }
        } label: {
            HStack(spacing: 0) {
                Text("\(productData.selectedUser?.name ?? "")")
                    .lineLimit(1)
                    .font(.system(size: isIPhone ? 12 : 15))
                    .foregroundColor(userManager.setting.textColor)
                    .padding(.leading, 10.0)
                    .frame(height: isIPhone ? 32 : 42, alignment: .leading)
                Spacer()
                Image("arrowDown")
                    .renderingMode(.template)
                    .foregroundColor(userManager.setting.textColor)
                    .padding(.trailing, isIPhone ? 0 : 10.0)
            }
        }
        .frame(width: isIPhone ? 115 : 190, height: isIPhone ? 32 : 42, alignment: .leading)
        .border(.gray, width: 1)
        .overlay(alignment: .topLeading) {
            Text("PHOTOGRAPHER".localized(userManager.userLanguage))
                .font(.system(size: isIPhone ? 12 : 15))
                .foregroundColor(userManager.setting.labelColor)
                .background(userManager.setting.themeColor)
                .font(.subheadline)
                .offset(x: 10, y: -8)
        }
    }
}
