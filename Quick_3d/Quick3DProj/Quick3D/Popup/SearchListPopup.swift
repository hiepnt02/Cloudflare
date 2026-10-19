//
//  SearchListPopup.swift
//  Quick3D
//
//  Created by HungNT on 13/5/25.
//

import SwiftUI

struct SearchListPopup<T: Hashable>: View {
    @EnvironmentObject var userManager: UserManager

    @Binding var isShow: Bool

    @Binding var viewPosition: CGPoint
    @Binding var viewWidth: CGFloat
    @Binding var viewHeight: CGFloat

    var listOriginal: [T]
    @Binding var searchKey: String
    var handler: (T) -> Void

    @State private var listFiltered: [T] = []
    @State private var scrollHeight: CGFloat = 0

    private let colorBgDark = Color(hex: 0x3c3c3c)
    private let scrollWidth: CGFloat = 260
    private let itemHeight: CGFloat = 40

    var body: some View {
        if isShow {
            Rectangle()
                .fill(.clear)
                .frame(
                    maxWidth: .infinity, maxHeight: .infinity,
                    alignment: .topLeading
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(
                        #selector(
                            UIResponder
                                .resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                    isShow = false
                }
                .overlay(alignment: .topLeading) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(listFiltered, id: \.self) { element in
                                if let obj = element as? JobSite.Site {
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(obj.name)
                                            .font(.system(size: 16))
                                            .foregroundColor(userManager.setting.textColor)
                                            .padding(.horizontal, 8)
                                            .frame(height: itemHeight)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                UIApplication.shared.sendAction(
                                                    #selector(
                                                        UIResponder
                                                            .resignFirstResponder
                                                    ),
                                                    to: nil, from: nil, for: nil
                                                )
                                                isShow = false
                                                self.handler(element)
                                            }

                                        if listFiltered.count > 1 {
                                            Rectangle()
                                                .frame(height: 0.5)
                                                .foregroundColor(Color.gray)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(width: scrollWidth, alignment: .leading)
                    }
                    .frame(
                        width: scrollWidth,
                        height: scrollHeight
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .foregroundColor(
                                (userManager.setting.colorTheme == .light)
                                    ? .white : colorBgDark
                            )
                            .shadow(radius: 8)
                    )
                    .offset(
                        x: viewPosition.x - viewWidth / 2 + 60,
                        y: viewPosition.y + viewHeight
                    )
                }
                .zIndex(10)
                .ignoresSafeArea()
                .onChange(of: searchKey) { _ in
                    filterList()
                }
                .onAppear {
                    filterList()
                }
        }
    }

    private func filterList() {
        if searchKey.isEmpty {
            listFiltered = listOriginal
        } else {
            listFiltered = listOriginal.filter {
                if let obj = $0 as? JobSite.Site {
                    return obj.name.localizedCaseInsensitiveContains(searchKey)
                }
                return true
            }
        }

        scrollHeight = CGFloat(
            listFiltered.count < (UserSession.isIPhone ? 5 : 7)
                ? (Int(itemHeight) * listFiltered.count)
                : UserSession.isIPhone ? 200 : 280)
    }
}
