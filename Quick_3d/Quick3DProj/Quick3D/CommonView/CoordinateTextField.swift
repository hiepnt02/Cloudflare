//
//  CoordinateTextField.swift
//  Quick3D
//
//  Created by HungNT on 3/7/25.
//

import Combine
import SwiftUI

struct CoordinateTextField: View {
    @EnvironmentObject var userManager: UserManager

    var listData: [String: String] = [:]
    @Binding var isShowPopup: Bool
    @Binding var inputText: String
    @FocusState var isFocus: Bool
    
    // Should return Coordinate Value each time user has selected Coordinate
    var handler: (
        String // Key of coordinate selected
    ) -> Void
    @State var filteredCoors: [String: String] = [:]
    @State private var scrollHeight: CGFloat = 0
    
    private let itemHeight: CGFloat = UserSession.isIPhone ? 40 : 55
    private let maxItem: Int = 6
    private let popupMaxHeight: CGFloat = UserSession.isIPhone ? 160 : 275
    private let offsetY: CGFloat = UserSession.isIPhone ? 45 : 60

    var body: some View {
        HStack(spacing: 0) {
            TextField("PLS_SELECT".localized(userManager.userLanguage), text: $inputText)
                .font(.body)
                .foregroundColor(userManager.setting.textColor)
                .focused($isFocus)
                .padding(.leading, 10)

            if !inputText.isEmpty {
                Button(
                    action: {
                        inputText = ""
                        handler("")
                    }
                ) {
                    Text("✖")
                        .font(.system(size: 20).bold())
                        .foregroundColor(userManager.setting.textColor)
                }
                .frame(width: 40, height: 40)
            }

            Button(action: {
                isShowPopup.toggle()
                isFocus = false
                if isShowPopup {
                    filterList()
                }
            }) {
                Image("arrowDown")
                    .renderingMode(.template)
                    .foregroundColor(userManager.setting.textColor)
                    .rotationEffect(.degrees(isShowPopup ? 180 : 0))
            }
            .frame(width: 40, height: 40)
        }
        .foregroundColor(userManager.setting.textColor)
        .frame(height: itemHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color(.lightGray), lineWidth: 1)
        )
        .overlay(alignment: .bottomLeading) {
            if isShowPopup {
                self.listCoordinateView()
            }
        }
        .padding(.leading, 10)
        .onChange(of: inputText) { value in
            filterList()
        }
        .onChange(of: isFocus) { focus in
            if focus {
                filterList()
                isShowPopup = true
            }
            
            if !focus && filteredCoors.isEmpty {
                inputText = ""
                isShowPopup = false
                handler("")
            }
        }
    }

    func listCoordinateView() -> some View {
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredCoors.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    VStack(alignment: .leading, spacing: 0) {
                        Button(action: {
                            inputText = value
                            isFocus = false
                            isShowPopup = false
                            handler(key)
                        }) {
                            Text(value)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                                .foregroundColor(
                                    userManager.setting.textColor
                                )
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }

                        if filteredCoors.count > 1 {
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundColor(Color.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(height: scrollHeight)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color(.lightGray), lineWidth: 1)
                .background((userManager.setting.colorTheme == .light) ? .white : Color.colorBgDark)
        )
        .frame(alignment: .bottomLeading)
        .offset(y: -offsetY)
        .zIndex(30)
    }
    
    private func filterList() {
        if inputText.isEmpty {
            filteredCoors = listData
        } else {
            filteredCoors = listData.filter { $0.value.localizedCaseInsensitiveContains(inputText) }
        }
       
        scrollHeight = filteredCoors.count <= maxItem ? (40 * CGFloat(filteredCoors.count)) : popupMaxHeight
    }
}
