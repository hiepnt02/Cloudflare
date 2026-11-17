//
//  SelectSortView.swift
//  Quick3D
//
//  Created by HungNT on 19/6/26.
//

import SwiftUI
import UIKit

// UIButton with UIMenu to avoid _UIReparentingView warning from SwiftUI Menu inside UIHostingController
private struct SortMenuButton: UIViewRepresentable {
    @Binding var selectedSort: SortOption
    let language: String
    let onSelect: () -> Void

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton()
        button.showsMenuAsPrimaryAction = true
        button.backgroundColor = .clear
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        let actions = SortOption.allCases.map { option in
            UIAction(
                title: option.title(language),
                state: option == selectedSort ? .on : .off
            ) { _ in
                guard option != selectedSort else { return }
                selectedSort = option
                DispatchQueue.main.async { onSelect() }
            }
        }
        button.menu = UIMenu(children: actions)
    }
}

struct SelectSortView: View {
    @EnvironmentObject var userManager: UserManager

    @Binding var selectedSort: SortOption
    let isIPhone: Bool
    let onSelect: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                Text(selectedSort.title(userManager.userLanguage))
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
            .frame(width: isIPhone ? 120 : 190, height: isIPhone ? 32 : 42, alignment: .leading)
            .border(.gray, width: 1)

            SortMenuButton(
                selectedSort: $selectedSort,
                language: userManager.userLanguage,
                onSelect: onSelect
            )
            .frame(width: isIPhone ? 120 : 190, height: isIPhone ? 32 : 42)

            Text("SORT_BY".localized(userManager.userLanguage))
                .font(.system(size: isIPhone ? 12 : 15))
                .foregroundColor(userManager.setting.labelColor)
                .background(userManager.setting.bodyColor)
                .offset(x: 10, y: -8)
        }
        .frame(width: isIPhone ? 120 : 190, height: isIPhone ? 32 : 42)
    }
}
