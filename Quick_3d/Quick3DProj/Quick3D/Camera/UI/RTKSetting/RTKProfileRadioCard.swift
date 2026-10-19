//
//  RTKProfileRadioCard.swift
//  Quick3D
//
//  Created by MOR on 6/10/26.
//

import SwiftUI

/// Một dòng profile kết nối RTK trong danh sách chọn ngay trên màn thiết bị.
///
/// Đang chọn thì mở rộng xem chi tiết, chưa chọn thì thu về hai dòng.
struct RTKProfileRadioCard: View {
    @EnvironmentObject private var userManager: UserManager

    let profile: RTKConnectionProfile
    let isSelected: Bool
    let isLocked: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var lang: String { userManager.userLanguage }

    static func subtitle(for profile: RTKConnectionProfile, lang: String) -> String {
        [profile.ntripServiceProvider.localizedKey.localized(lang), profile.mountPoint, profile.username]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if isSelected {
                Divider().background(userManager.setting.dividerColor)
                details
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8).fill(userManager.setting.itemBgColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? skyBlue : lightGray, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isLocked else { return }
            onSelect()
        }
        .opacity(isLocked && !isSelected ? 0.5 : 1)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: isSelected ? "record.circle" : "circle")
                .font(.system(size: 20))
                .foregroundColor(isSelected ? skyBlue : grey)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(userManager.setting.textColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(Self.subtitle(for: profile, lang: lang))
                    .font(.system(size: 13))
                    .foregroundColor(labelColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            menu
        }
    }

    private var menu: some View {
        Menu {
            Button {
                onEdit()
            } label: {
                Label("RTK_PROFILE_EDIT".localized(lang), systemImage: "pencil")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("REMOVE".localized(lang), systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(userManager.setting.textColor)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .disabled(isLocked)
    }

    private var details: some View {
        VStack(spacing: 8) {
            row("RTK_HOSTNAME_IP".localized(lang), profile.hostnameOrIp)
            row("RTK_COORDINATE_SYSTEM_LABEL".localized(lang), profile.coordinateSystem?.id ?? "-")
            row("MINIMUM_ELEVATION".localized(lang), profile.elevationValue.displayLabel)
            row("GNSS_CONSTELLATIONS".localized(lang), gnssSummary)
        }
    }

    private var gnssSummary: String {
        let ordered = GNSSEnum.allCases.filter { profile.gnssSet.contains($0) }
        return ordered.isEmpty ? "-" : ordered.map(\.title).joined(separator: ", ")
    }

    private var labelColor: Color {
        userManager.setting.colorTheme == .light ? abbeyGray : bombayGray
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(labelColor)
                .frame(width: 132, alignment: .leading)

            Text(value.isEmpty ? "-" : value)
                .font(.system(size: 14))
                .foregroundColor(userManager.setting.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
    }
}
