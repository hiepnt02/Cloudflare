//
//  MountpointSearchField.swift
//  Quick3D
//
//  Created by HungNT on 5/1/26.
//

import SwiftUI

struct MountpointSearchField: View {
    @EnvironmentObject private var userManager: UserManager
    
    @State private var textSearch = ""
    @State private var isEditing = false
    
    var onTextChanged: (String) -> Void
    var onCancel: () -> Void
    
    private var bgColor: Color {
        userManager.setting.colorTheme == .light ? .white : charcoalDark
    }
    private var strokeColor: Color {
        userManager.setting.colorTheme == .light ? .black : slateGrey
    }
    
    var body: some View {
        ZStack {
            HStack {
                Image("ic_search_gray")
                    .renderingMode(.template)
                    .resizable()
                    .foregroundColor(slateGrey)
                    .frame(width: 16, height: 16)
                    .padding(.leading, 8)
                    
                Spacer()
                    
                if isEditing && !textSearch.isEmpty {
                    Button(action: {
                        self.textSearch = ""
                        self.onCancel()
                        hideKeyboard()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(slateGrey)
                            .padding(.trailing, 8)
                    }
                }
            }
            .frame(height: 34)
            .background(bgColor)
            .cornerRadius(2)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(strokeColor, lineWidth: 1)
            )
            
            TextField(
                "SEARCH".localized(userManager.userLanguage),
                text: $textSearch,
                onEditingChanged: { editing in
                    self.isEditing = editing
                }
            )
            .textFieldStyle(.plain)
            .font(.system(size: 16))
            .foregroundColor(userManager.setting.textColor)
            .frame(height: 34)
            .padding(.horizontal, 30)
            .onChange(of: textSearch) { keyword in
                onTextChanged(keyword)
            }
        }
    }
}
