//
//  DropDownView.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 26/07/2023.
//

import SwiftUI

struct DropdownOption: Hashable {
    public static func == (lhs: DropdownOption, rhs: DropdownOption) -> Bool {
        return lhs.key == rhs.key
    }

    var key: Int
    var val: String
}

struct DropdownOptionElement: View {
    var item: DropdownOption
    var showSeparator: Bool
    var onSelect: ((_ item: DropdownOption) -> Void)?
    @EnvironmentObject var userManager: UserManager

    var body: some View {
        Button(action: {
            if let onSelect = self.onSelect {
                onSelect(self.item)
            }
        }) {
            VStack {
                HStack {
                    Text(self.item.val)
//                        .foregroundColor(.white)
                        .foregroundColor(userManager.setting.textColor)
                        .padding(.horizontal, 20)
                    Spacer()
                }
                .padding(.top, 15)
                
                Spacer()
                
                if showSeparator {
                    Divider()
                }
            }
            .contentShape(Rectangle())
        }
        .frame(width: 240, height: 50)
    }
}

struct Dropdown: View {
    var options: [DropdownOption]
    var onSelect: ((_ item: DropdownOption) -> Void)?
    let dropdownCornerRadius: CGFloat = 15
    @EnvironmentObject var userManager: UserManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, item in
                DropdownOptionElement(item: item, showSeparator: index < options.count - 1, onSelect: self.onSelect)
            }
        }
        .background(userManager.setting.dropdownColor)
        .overlay(
            userManager.setting.colorTheme == .light ?
                RoundedRectangle(cornerRadius: dropdownCornerRadius)
                .stroke(Color.gray, lineWidth: 0.3) : RoundedRectangle(cornerRadius: dropdownCornerRadius)
                .stroke(Color.white, lineWidth: 0.3)
        )

    }
}

struct DropdownButton: View {
    @Binding var shouldShowDropdown: Bool
    var displayText: String
    var options: [DropdownOption]
    var onTap: (() -> Void)?
    var onSelect: ((_ item: DropdownOption) -> Void)?
    var textColor: Color
    
    var body: some View {
        Button(action: {
            onTap?()
            self.shouldShowDropdown.toggle()
        }) {
            HStack {
                Text(displayText)
                    .multilineTextAlignment(.leading)
                    .padding(.all, 10.0)
                    .foregroundColor(textColor)

                Spacer()

                Image("arrowDown")
                    .renderingMode(.template)
                    .padding(.trailing, 10)
                    .foregroundColor(textColor)

            }
            .foregroundColor(.white)
            .contentShape(Rectangle())
        }
        .frame(width: 240, height: 42)
        .border(.gray, width: 1)
        .overlay(alignment: .topLeading) {
            VStack {
                if self.shouldShowDropdown {
                    Dropdown(options: self.options, onSelect: self.onSelect)
//                        .border(.gray, width: 1)
                }

            }
            .position(x: 130, y: 95)
        }

    }
}
