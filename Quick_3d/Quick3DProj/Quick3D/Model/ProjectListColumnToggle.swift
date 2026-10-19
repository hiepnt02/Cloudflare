//
//  ProjectListColumnToggle.swift
//  Quick3D
//
//  QU3DW-1284
//

import CoreGraphics
import Foundation

enum ProjectListColumnToggle: CaseIterable {
    case name
    case jobsite
    case photographer
    case photo
    case type
    case status
    case capturedDate
    case uploadDate

    static let groupTitleLocalizationKey = "PROJECT_LIST_COLUMN_SETTINGS"

    var isAlwaysVisible: Bool {
        self == .name
    }

    var localizationKey: String {
        switch self {
        case .name:         return "NAME"
        case .jobsite:      return "JOBSITE"
        case .photographer: return "PHOTOGRAPHER"
        case .photo:        return "NUMBER_OF_PHOTOS"
        case .type:         return "TYPE"
        case .status:       return "STATUS"
        case .capturedDate: return "SORT_CAPTURED_DATE"
        case .uploadDate:   return "SORT_UPLOAD_DATE"
        }
    }
}

struct ProjectListColumnLayout {

    static let totalParts = 24

    static let displayOrder: [ProjectListColumnToggle] = [
        .name, .jobsite, .photographer, .type, .capturedDate, .uploadDate, .photo, .status
    ]

    static func ratio(_ column: ProjectListColumnToggle) -> Int {
        switch column {
        case .name:         return 4
        case .photographer: return 3
        case .jobsite:      return 3
        case .type:         return 2
        case .uploadDate:   return 3
        case .capturedDate: return 3
        case .photo:        return 2
        case .status:       return 4
        }
    }

    enum Metrics {
        static func horizontalPadding(isIPhone: Bool) -> CGFloat { isIPhone ? 8 : 12 }
        static func columnSpacing(isIPhone: Bool) -> CGFloat { isIPhone ? 8 : 12 }
        static func checkboxWidth(isIPhone: Bool) -> CGFloat { isIPhone ? 22 : 26 }
        static func trailingWidth(isIPhone: Bool) -> CGFloat { isIPhone ? 24 : 32 }
        static func listOuterPadding(isIPhone: Bool) -> CGFloat { isIPhone ? 20 : 30 }

        static func thumbnailWidth(contentWidth: CGFloat, isIPhone: Bool) -> CGFloat {
            max(0, (contentWidth - 150) / (isIPhone ? 4 : 5))
        }

        static func availableWidth(
            contentWidth: CGFloat,
            thumbnailWidth: CGFloat,
            visibleColumns: Set<ProjectListColumnToggle>,
            isIPhone: Bool,
            isEditing: Bool
        ) -> CGFloat {
            let columnCount = ProjectListColumnLayout.displayOrder
                .filter { visibleColumns.contains($0) }.count
            let itemCount = (isEditing ? 1 : 0) + 1 + columnCount + 1
            let gaps = CGFloat(max(0, itemCount - 1)) * columnSpacing(isIPhone: isIPhone)

            let deductions = listOuterPadding(isIPhone: isIPhone) * 2
                + horizontalPadding(isIPhone: isIPhone) * 2
                + (isEditing ? checkboxWidth(isIPhone: isIPhone) : 0)
                + thumbnailWidth
                + trailingWidth(isIPhone: isIPhone)
                + gaps

            return max(0, contentWidth - deductions)
        }
    }

    private let visibleColumns: Set<ProjectListColumnToggle>

    private let availableWidth: CGFloat

    // MARK: - Hệ tỉ lệ 24 phần

    init(visibleColumns: Set<ProjectListColumnToggle>, availableWidth: CGFloat) {
        self.visibleColumns = visibleColumns
        self.availableWidth = availableWidth
    }

    init(setting: UserSetting, availableWidth: CGFloat) {
        self.init(visibleColumns: setting.visibleProjectColumns, availableWidth: availableWidth)
    }

    func isVisible(_ column: ProjectListColumnToggle) -> Bool {
        visibleColumns.contains(column)
    }

    var visibleColumnsInDisplayOrder: [ProjectListColumnToggle] {
        Self.displayOrder.filter { visibleColumns.contains($0) }
    }

    func parts(_ column: ProjectListColumnToggle) -> Int {
        let visible = visibleColumnsInDisplayOrder
        guard visible.contains(column), let lastColumn = visible.last else { return 0 }

        let totalRatio = visible.reduce(0) { $0 + Self.ratio($1) }
        guard totalRatio > 0 else { return 0 }

        guard column == lastColumn else {
            return Self.formulaParts(column, totalRatio: totalRatio)
        }

        let othersParts = visible.dropLast().reduce(0) {
            $0 + Self.formulaParts($1, totalRatio: totalRatio)
        }
        return max(0, Self.totalParts - othersParts)
    }

    private static func formulaParts(_ column: ProjectListColumnToggle, totalRatio: Int) -> Int {
        let exact = CGFloat(ratio(column)) / CGFloat(totalRatio) * CGFloat(totalParts)
        return Int(exact.rounded())
    }

    func width(_ column: ProjectListColumnToggle) -> CGFloat {
        guard availableWidth > 0 else { return 0 }

        let visible = visibleColumnsInDisplayOrder
        guard visible.contains(column), let lastColumn = visible.last else { return 0 }

        let unit = availableWidth / CGFloat(Self.totalParts)
        guard column == lastColumn else { return CGFloat(parts(column)) * unit }

        let othersWidth = visible.dropLast().reduce(CGFloat(0)) { $0 + CGFloat(parts($1)) * unit }
        return max(0, availableWidth - othersWidth)
    }
}

extension ProjectListColumnToggle {

    var settingKeyPath: WritableKeyPath<UserSetting, Bool>? {
        switch self {
        case .name:         return nil
        case .jobsite:      return \.displayListColumnSetting.showJobsite
        case .photographer: return \.displayListColumnSetting.showPhotographer
        case .photo:        return \.displayListColumnSetting.showImages
        case .type:         return \.displayListColumnSetting.showType
        case .status:       return \.displayListColumnSetting.showStatus
        case .capturedDate: return \.displayListColumnSetting.showCaptureDate
        case .uploadDate:   return \.displayListColumnSetting.showUploadDate
        }
    }
}

extension UserSetting {

    func isVisible(_ column: ProjectListColumnToggle) -> Bool {
        guard let keyPath = column.settingKeyPath else { return true }
        return self[keyPath: keyPath]
    }

    mutating func setVisible(_ isOn: Bool, for column: ProjectListColumnToggle) {
        guard let keyPath = column.settingKeyPath else { return }
        self[keyPath: keyPath] = isOn
    }

    var visibleProjectColumns: Set<ProjectListColumnToggle> {
        Set(ProjectListColumnToggle.allCases.filter { isVisible($0) })
    }
}
