//
//  GsxUpdateSummaryPopup.swift
//  Quick3D
//

import SwiftUI

struct GsxUpdateSummaryChoices: Equatable {
    enum Choice: Equatable {
        case delete
        case keep
    }

    private var choices: [String: Choice] = [:]

    func choice(for projectId: String) -> Choice? {
        choices[projectId]
    }

    mutating func choose(_ choice: Choice, for projectId: String) {
        choices[projectId] = choice
    }

    func apply(to summary: GsxUpdateSummary) -> (delete: [String], keep: [String]) {
        let removed = summary.removed.map(\.projectId)
        return (
            delete: removed.filter { choices[$0] == .delete },
            keep: removed.filter { choices[$0] == .keep }
        )
    }
}

struct GsxUpdateSummaryPopup: View {

    enum Section: Equatable {
        case updates
        case removed
    }

    static func sections(for summary: GsxUpdateSummary) -> [Section] {
        var sections: [Section] = []
        if !summary.updates.isEmpty { sections.append(.updates) }
        if !summary.removed.isEmpty { sections.append(.removed) }
        return sections
    }

    @EnvironmentObject var userManager: UserManager

    let summary: GsxUpdateSummary?
    var onDone: (_ delete: [String], _ keep: [String]) -> Void

    @State private var choices = GsxUpdateSummaryChoices()
    @State private var listHeight: CGFloat = 0

    private var isIPhone: Bool { UserSession.isIPhone }
    private var popupWidth: CGFloat { isIPhone ? 300 : 420 }
    private var maxListHeight: CGFloat { UIScreen.main.bounds.height * (isIPhone ? 0.45 : 0.5) }

    var body: some View {
        ZStack {
            if let summary {
                Color(userManager.setting.colorTheme == .light ? .black : .white)
                    .opacity(0.3)
                    .edgesIgnoringSafeArea(.all)

                contentView(summary)
                    .frame(width: popupWidth)
                    .background(userManager.setting.themeColor)
                    .border(.gray, width: 1)
            }
        }
    }

    private func finish(delete: [String], keep: [String]) {
        choices = GsxUpdateSummaryChoices()
        onDone(delete, keep)
    }

    private func contentView(_ summary: GsxUpdateSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(localized("GSX_UPDATE_SUMMARY_TITLE"))
                    .foregroundColor(userManager.setting.textColor)
                    .font(.system(size: isIPhone ? 15 : 18, weight: .bold))

                Spacer(minLength: 0)

                Button {
                    finish(delete: [], keep: [])
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(userManager.setting.textColor)
                }
            }

            Divider()

            sectionList(summary)

            Button {
                let applied = choices.apply(to: summary)
                finish(delete: applied.delete, keep: applied.keep)
            } label: {
                Text(localized("GSX_UPDATE_SUMMARY_DONE"))
                    .font(.system(size: isIPhone ? 14 : 16))
                    .foregroundColor(.white)
                    .frame(height: isIPhone ? 32 : 40)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .background(.blue)
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, isIPhone ? 14 : 18)
        .padding(.vertical, isIPhone ? 12 : 16)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func sectionList(_ summary: GsxUpdateSummary) -> some View {
        ScrollView(showsIndicators: listHeight > maxListHeight) {
            VStack(alignment: .leading, spacing: isIPhone ? 14 : 16) {
                ForEach(Self.sections(for: summary), id: \.self) { section in
                    switch section {
                    case .updates:
                        updatesSection(summary.updates)
                    case .removed:
                        removedSection(summary.removed)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: SummaryHeightKey.self, value: proxy.size.height)
                }
            )
        }
        .frame(height: min(max(listHeight, 1), maxListHeight))
        .onPreferenceChange(SummaryHeightKey.self) { listHeight = $0 }
    }

    private func updatesSection(_ items: [GsxUpdateSummary.Item]) -> some View {
        VStack(alignment: .leading, spacing: isIPhone ? 6 : 8) {
            sectionHeader(localized("GSX_UPDATE_SUMMARY_NEW_VERSION"))
            Text(localized("GSX_UPDATE_SUMMARY_NEW_VERSION_HINT"))
                .foregroundColor(userManager.setting.textColor.opacity(0.7))
                .font(.system(size: isIPhone ? 11 : 13))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(items) { item in
                projectName(item.displayName)
            }
        }
    }

    private func removedSection(_ items: [GsxUpdateSummary.Item]) -> some View {
        VStack(alignment: .leading, spacing: isIPhone ? 6 : 8) {
            sectionHeader(localized("GSX_UPDATE_SUMMARY_REMOVED"))
            ForEach(items) { item in
                HStack(spacing: 8) {
                    projectName(item.displayName)
                    choiceButton(.delete, titleKey: "GSX_FILE_REMOVED_DELETE", projectId: item.projectId)
                    choiceButton(.keep, titleKey: "GSX_FILE_REMOVED_KEEP", projectId: item.projectId)
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .foregroundColor(userManager.setting.textColor)
            .font(.system(size: isIPhone ? 13 : 15, weight: .bold))
    }

    private func projectName(_ name: String) -> some View {
        Text(name)
            .foregroundColor(userManager.setting.textColor)
            .font(.system(size: isIPhone ? 13 : 15, weight: .semibold))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func choiceButton(_ choice: GsxUpdateSummaryChoices.Choice, titleKey: String, projectId: String) -> some View {
        let isSelected = choices.choice(for: projectId) == choice
        let tint: Color = choice == .delete ? .red : .blue
        return Button {
            choices.choose(choice, for: projectId)
        } label: {
            Text(localized(titleKey))
                .font(.system(size: isIPhone ? 12 : 14))
                .foregroundColor(isSelected ? .white : tint)
                .padding(.horizontal, 10)
                .frame(height: isIPhone ? 26 : 32)
                .background(isSelected ? tint : Color.clear)
                .overlay(Rectangle().stroke(tint, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .fixedSize()
    }

    private func localized(_ key: String) -> String {
        key.localized(userManager.userLanguage)
    }
}

private struct SummaryHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
