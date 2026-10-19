//
//  SearchFieldView.swift
//  Quick3D
//
//  Created by HungNT on 20/5/26.
//

import SwiftUI

struct SearchFieldView: View {
    @EnvironmentObject var userManager: UserManager
    
    @Binding var inputStr: String
    @Binding var searchStr: String
    @FocusState var focusStateSearch: Bool
    let isIPhone: Bool
    let onSearchTriggered: () -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                hideKeyboard()
                searchStr = inputStr
                onSearchTriggered()
            }, label: {
                Image("search")
                    .renderingMode(.template)
                    .foregroundColor(.gray)
                    .frame(width: isIPhone ? 20 : 30, height: isIPhone ? 20 : 30)
                    .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 5))
            })
            ZStack(alignment: .leading) {
                if inputStr.isEmpty {
                    Text("JOBSITE_PROJECT_SEARCH".localized(userManager.userLanguage))
                        .foregroundColor(.gray.opacity(0.7))
                        .font(.system(size: isIPhone ? 10 : 15))
                }
                TextField("", text: $inputStr)
                    .font(.system(size: isIPhone ? 10 : 15))
                    .foregroundColor(userManager.setting.textColor)
                    .focused($focusStateSearch)
                    .onSubmit {
                        hideKeyboard()
                    }
            }
            Spacer()
            if !inputStr.isEmpty {
                Button(action: {
                    inputStr = ""
                    searchStr = ""
                    onSearchTriggered()
                }) {
                    Text("✖")
                        .font(.system(size: 20).bold())
                        .foregroundColor(userManager.setting.textColor)
                        .padding(.trailing, 10)
                }
                .frame(width: 30, height: 30, alignment: .trailing)
            }
        }
        .frame(width: isIPhone ? 135 : 250, height: isIPhone ? 32 : 42)
        .border(.gray, width: 1)
        .overlay(alignment: .bottom) {
            if focusStateSearch {
                Rectangle()
                    .frame(height: 4)
                    .foregroundColor(.blue)
            }
        }
        .onChange(of: focusStateSearch) { value in
            guard !value, searchStr != inputStr else { return }
            searchStr = inputStr
            onSearchTriggered()
        }
    }
}
