//
//  RTKProfileCard.swift
//  Quick3D
//
//  Created by MOR on 4/9/26.
//

import SwiftUI

/// Thẻ hiển thị một profile kết nối RTK.
///
/// `.selectable` dùng ở màn danh sách (radio + sửa + xoá), `.summary` dùng ở màn thiết bị
/// để tóm tắt profile đang chọn.
struct RTKProfileCard: View {
    enum Style {
        case selectable
        case summary
    }

    @EnvironmentObject private var userManager: UserManager

    let profile: RTKConnectionProfile
    var style: Style = .selectable
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    private var lang: String { userManager.userLanguage }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider().background(userManager.setting.dividerColor)
            body_
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8).fill(userManager.setting.itemBgColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(style == .selectable && isSelected ? skyBlue : lightGray, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard style == .selectable else { return }
            onSelect?()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if style == .selectable {
                // Cùng glyph và cùng màu nhấn với radio ở RTKDeviceOffsetView, màn kề bên
                // trong cùng luồng — trước đây card dùng largecircle.fill.circle/sapphireBlue
                // nên hai màn đặt cạnh nhau trông như hai hệ thiết kế khác nhau.
                Image(systemName: isSelected ? "record.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? skyBlue : grey)
            }

            Text(profile.name)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(userManager.setting.textColor)
                .lineLimit(1)

            Spacer(minLength: 8)

            if style == .selectable {
                Button {
                    onEdit?()
                } label: {
                    iconLabel("rtk_edit_btn", tint: userManager.setting.textColor)
                }
                .buttonStyle(.plain)

                Button {
                    onDelete?()
                } label: {
                    iconLabel("rtk_delete_btn", tint: userManager.setting.deleteButtonColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Icon nút trong header card.
    ///
    /// Tô lại màu thay vì dùng màu gốc của asset: bản vẽ edit là navy `#1C274C` (chìm trên
    /// theme tối) và bản vẽ delete là `#FF0000` (lệch với đỏ `materialRed` của app).
    ///
    /// Hai icon KHÔNG cùng tỷ lệ — edit 16×16, delete 12×16 — nên phải giữ aspect ratio;
    /// ép chung một khung vuông sẽ kéo méo icon delete. Khung 16 là cỡ glyph, khung 32 bên
    /// ngoài mới là vùng chạm.
    private func iconLabel(_ name: String, tint: Color) -> some View {
        Image(name)
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .frame(height: 16)
            .foregroundColor(tint)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
    }

    private var body_: some View {
        VStack(spacing: 8) {
            row("RTK_DEVICE_TYPE".localized(lang), UserSession.shared.rtkTypeSelected.displayName)
            row("RTK_OFFSET_TYPE".localized(lang), profile.cameraOffsetSegment.displayName(lang))
            row("RTK_NTRIP_VRS_PROVIDER".localized(lang), profile.ntripServiceProvider.localizedKey.localized(lang))
            row("RTK_HOSTNAME_IP".localized(lang), profile.hostnameOrIp)
            row("RTK_USERNAME".localized(lang), profile.username)
            row("RTK_MOUNTPOINT_LABEL".localized(lang), profile.mountPoint)
            row("RTK_COORDINATE_SYSTEM_LABEL".localized(lang), profile.coordinateSystem?.id ?? "-")
            row("MINIMUM_ELEVATION".localized(lang), profile.elevationValue.displayLabel)
            row("GNSS_CONSTELLATIONS".localized(lang), gnssSummary)
        }
    }

    private var gnssSummary: String {
        let ordered = GNSSEnum.allCases.filter { profile.gnssSet.contains($0) }
        return ordered.isEmpty ? "-" : ordered.map(\.title).joined(separator: ", ")
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(userManager.setting.colorTheme == .light ? abbeyGray : bombayGray)
                .frame(width: 132, alignment: .leading)

            Text(value.isEmpty ? "-" : value)
                .font(.system(size: 14))
                .foregroundColor(userManager.setting.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
    }
}
