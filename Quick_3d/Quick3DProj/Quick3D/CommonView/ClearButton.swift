//
//  ClearButton.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 17/04/2022.
//

import SwiftUI

struct ClearButton: ViewModifier
{
    @Binding var text: String
    @EnvironmentObject var userManager: UserManager

    public func body(content: Content) -> some View
    {
        ZStack(alignment: .trailing)
        {
            content

            if !text.isEmpty
            {
                Button(action:
                {
                    self.text = ""
                })
                {
                    Image(systemName: "xmark")
                        .foregroundColor(userManager.setting.textColor)
                }
                .padding(.trailing, 8)
            }
        }
    }
}
