//
//  ProjectListColumnSettingsSection.swift
//  Quick3D
//
//  QU3DW-1284
//

import SwiftUI

struct ProjectListColumnSettingsSection: View {

    @EnvironmentObject var userManager: UserManager

    @State private var isExpanded = false

    private var isIPhone: Bool {
        UIDevice.current.isIphone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerButton

            if isExpanded {
                columnGrid
            }
        }
    }

    private var headerButton: some View {
        Button(action: {
            withAnimation(.none) {
                isExpanded.toggle()
            }
        }, label: {
            HStack(spacing: 0) {
                Text(ProjectListColumnToggle.groupTitleLocalizationKey
                    .localized(userManager.userLanguage))
                    .foregroundColor(userManager.setting.textColor)
                    .font(.system(size: isIPhone ? 15 : 17, weight: .bold))

                let chevronIcon = isExpanded ? "\u{f077}" : "\u{f078}"
                Text(chevronIcon)
                    .foregroundColor(userManager.setting.textColor)
                    .font(.custom(CustomFonts.FAFreeSolid, size: 16))
                    .fixedSize(horizontal: false, vertical: true)
                    .dynamicTypeSize(DynamicTypeSize.medium)
                    .frame(width: 30, height: 30)

                Spacer()
            }
            .contentShape(Rectangle())
        })
        .buttonStyle(PlainButtonStyle())
    }

    private var columnGrid: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), alignment: .leading),
                count: 3
            ),
            alignment: .leading,
            spacing: isIPhone ? 10 : 14
        ) {
            ForEach(ProjectListColumnToggle.allCases, id: \.self) { column in
                columnRow(column)
            }
        }
        .padding(.top, isIPhone ? 6 : 10)
    }

    private func columnRow(_ column: ProjectListColumnToggle) -> some View {
        let label = column.localizationKey.localized(userManager.userLanguage)
        let isLocked = column.isAlwaysVisible

        return HStack(spacing: 8) {
            Toggle(isOn: binding(for: column)) {}
                .labelsHidden()
                .fixedSize()
                .disabled(isLocked)
                .accessibilityLabel(Text(label))

            Text(label)
                .foregroundColor(userManager.setting.textColor.opacity(isLocked ? 0.4 : 1))
                .font(.system(size: isIPhone ? 13 : 15))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    private func binding(for column: ProjectListColumnToggle) -> Binding<Bool> {
        Binding(
            get: { userManager.setting.isVisible(column) },
            set: { isOn in userManager.setting.setVisible(isOn, for: column) }
        )
    }
}
