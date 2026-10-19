//
//  SearchListPopup.swift
//  Quick3D
//
//  Created by HungNT on 13/5/25.
//

import SwiftUI

struct SearchListPopup<T: Hashable & DropdownDisplayable>: View {
    @EnvironmentObject var userManager: UserManager

    @Binding var isShow: Bool

    @Binding var viewPosition: CGPoint
    @Binding var viewWidth: CGFloat
    @Binding var viewHeight: CGFloat

    var listOriginal: [T]
    @Binding var searchKey: String
    var handler: (T) -> Void

    private static var rowFontSize: CGFloat { 16 }
    private static var rowFont: UIFont { .systemFont(ofSize: rowFontSize) }

    private let colorBgDark = Color(hex: 0x3c3c3c)

    var body: some View {
        if isShow {
            GeometryReader { container in
                let items = listFiltered
                let layout = layout(for: items, in: container)

                Rectangle()
                    .fill(.clear)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissKeyboard()
                        isShow = false
                    }
                    .overlay(alignment: .topLeading) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(items.enumerated()), id: \.element) { index, element in
                                    row(element, isLast: index == items.count - 1, layout: layout)
                                }
                            }
                            .frame(width: layout.frame.width, alignment: .leading)
                        }
                        .frame(width: layout.frame.width, height: layout.frame.height)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .foregroundColor(
                                    (userManager.setting.colorTheme == .light)
                                        ? .white : colorBgDark
                                )
                                .shadow(radius: 8)
                        )
                        .offset(x: layout.frame.x, y: layout.frame.y)
                    }
            }
            .zIndex(10)
        }
    }

    private var listFiltered: [T] {
        guard !searchKey.isEmpty else { return listOriginal }

        return listOriginal.filter {
            $0.dropdownTitle(in: userManager.userLanguage)
                .localizedCaseInsensitiveContains(searchKey)
        }
    }

    private func row(_ element: T, isLast: Bool, layout: DropdownLayout) -> some View {
        let title = element.dropdownTitle(in: userManager.userLanguage)

        return VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: Self.rowFontSize))
                .foregroundColor(userManager.setting.textColor)
                .lineLimit(DropdownLayout.Constants.maxLines)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DropdownLayout.Constants.horizontalPadding)
                .frame(
                    maxWidth: .infinity,
                    minHeight: layout.rowHeight(for: title, width: layout.frame.width),
                    alignment: .leading
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissKeyboard()
                    isShow = false
                    handler(element)
                }

            if !isLast {
                Rectangle()
                    .frame(height: DropdownLayout.Constants.separatorHeight)
                    .foregroundColor(Color.gray)
            }
        }
    }

    private func layout(for items: [T], in container: GeometryProxy) -> DropdownLayout {
        let containerOrigin = container.frame(in: .global).origin
        let anchor = CGRect(
            x: viewPosition.x - containerOrigin.x,
            y: viewPosition.y - containerOrigin.y,
            width: viewWidth,
            height: viewHeight
        )

        return DropdownLayout(
            titles: items.map { $0.dropdownTitle(in: userManager.userLanguage) },
            font: Self.rowFont,
            anchor: anchor,
            container: container.size,
            isIPhone: UserSession.isIPhone
        )
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}
