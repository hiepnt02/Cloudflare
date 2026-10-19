//
//  ARStepOptionsView.swift
//  Quick3D
//

import SwiftUI

struct ARStepPulldownAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

struct ARStepOptionsView: View {
    @EnvironmentObject private var userManager: UserManager

    static let rowHeight: CGFloat = 40
    static let maxWidth: CGFloat = 210
    static var fullHeight: CGFloat {
        let count = CGFloat(ARPositionStepEnum.allCases.count)
        return count * rowHeight + (count - 1)
    }

    let selected: ARPositionStepEnum
    let width: CGFloat
    let height: CGFloat
    let onSelect: (ARPositionStepEnum) -> Void

    var body: some View {
        let items = ARPositionStepEnum.allCases
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        onSelect(item)
                    } label: {
                        HStack(spacing: 8) {
                            Text(item.getText(userManager.userLanguage))
                                .font(.system(size: 14))
                                .foregroundColor(userManager.setting.textColor)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if selected == item {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12))
                                    .foregroundColor(sapphireBlue)
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(height: Self.rowHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < items.count - 1 {
                        Divider().background(lightGray)
                    }
                }
            }
        }
        .frame(width: width, height: height)
        .background(RoundedRectangle(cornerRadius: 4).fill(userManager.setting.themeColor))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(lightGray, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}
