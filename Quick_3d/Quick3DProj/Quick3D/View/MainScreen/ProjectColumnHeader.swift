//
//  ListColumnHeader.swift
//  Quick3D
//
//  Created by HungNT on 26/5/26.
//

import Foundation
import SwiftUI

struct ProjectColumnHeader: View {
    @EnvironmentObject var userManager: UserManager

    let isIPhone: Bool
    var contentWidth: CGFloat = UIScreen.main.bounds.width
    @Binding var isEditing: Bool

    private var columnSpacing: CGFloat {
        ProjectListColumnLayout.Metrics.columnSpacing(isIPhone: isIPhone)
    }

    private var thumbnailWidth: CGFloat {
        ProjectListColumnLayout.Metrics.thumbnailWidth(contentWidth: contentWidth, isIPhone: isIPhone)
    }

    private var layout: ProjectListColumnLayout {
        ProjectListColumnLayout(
            setting: userManager.setting,
            availableWidth: ProjectListColumnLayout.Metrics.availableWidth(
                contentWidth: contentWidth,
                thumbnailWidth: thumbnailWidth,
                visibleColumns: userManager.setting.visibleProjectColumns,
                isIPhone: isIPhone,
                isEditing: isEditing
            )
        )
    }

    /// Shared with `ProjectListCell` so each cell column lines up with its header.
    static func alignment(for column: ProjectListColumnToggle) -> Alignment {
        (column == .name || column == .status) ? .leading : .center
    }

    static func textAlignment(for column: ProjectListColumnToggle) -> TextAlignment {
        (column == .name || column == .status) ? .leading : .center
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: columnSpacing) {

                // Leading space while editing (use padding instead of Spacer to optimize rendering)
                if isEditing {
                    Color.clear
                        .frame(width: ProjectListColumnLayout.Metrics.checkboxWidth(isIPhone: isIPhone))
                }

                Color.clear.frame(width: thumbnailWidth)

                // Iterate over the columns to render them automatically
                ForEach(layout.visibleColumnsInDisplayOrder, id: \.self) { column in
                    Text(column.localizationKey.localized(userManager.userLanguage))
                        .font(.system(size: isIPhone ? 13 : 17, weight: .bold))
                        .foregroundColor(userManager.setting.textColor.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(Self.textAlignment(for: column))
                        .frame(width: layout.width(column), alignment: Self.alignment(for: column))
                }

                // Trailing space
                Color.clear
                    .frame(width: ProjectListColumnLayout.Metrics.trailingWidth(isIPhone: isIPhone))
            }
            .padding(.horizontal, ProjectListColumnLayout.Metrics.horizontalPadding(isIPhone: isIPhone))
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(userManager.setting.themeColor)

            Divider()
                .background(Color.gray.opacity(0.5))
        }
    }
}
