//
//  ProjectListCell.swift
//  Quick3D
//
//  Created by HungNT on 26/5/26.
//

import SwiftUI
import Alamofire
import DeviceKit

struct ProjectListCell: View, Equatable {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var productData: ProductData

    var cat: Cat
    @Binding var isEditing: Bool
    @Binding var isSelected: Bool

    let thumbnailImage: UIImage?
    let jobSiteName: String
    /// Upload state of this project, see `CellUploadState`.
    let uploadState: CellUploadState
    // Built only when the menu is opened, so scrolling/refreshing the list does not
    // create the menu items of every cell.
    let actionMenuItems: () -> AnyView
    let onTap: () -> Void
    @Binding var isShowNoNetworkAlert: Bool
    @Binding var cellWidth: CGFloat
    /// Các cột đang được bật trong "Project List Column Settings" (QU3DW-1284).
    /// Truyền vào dưới dạng giá trị thay vì đọc qua `userManager` để `.equatable()`
    /// nhận ra thay đổi và dựng lại hàng.
    let visibleColumns: Set<ProjectListColumnToggle>
    /// Bề rộng thực của vùng nội dung danh sách, dùng để chia 24 phần cho khối cột
    /// (QU3DW-1284-v5). Mặc định là bề rộng màn hình để hàng vẫn vẽ đúng khi chưa có
    /// giá trị đo được từ `GeometryReader`.
    var contentWidth: CGFloat = UIScreen.main.bounds.width

    private var isIPhone: Bool { UIDevice.current.isIphone }
    private var listIconSize: CGFloat { isIPhone ? 36 : 50 }

    private var heightThumb: CGFloat { isIPhone ? 80 : 104 }

    /// Max number of lines of the title column. Kept at 4 so the text block
    /// (4 x ~15pt line height on iPhone, ~18pt on iPad) still stays below
    /// `heightThumb`, i.e. the title never makes the row taller than the thumbnail.
    private let titleLineLimit = 4
    
    /// Project titles coming from the field are often a single token joined by `_`
    /// (e.g. `2026_08_03_jobsite_A`). SwiftUI only breaks lines on spaces and
    /// hyphens, so such a title gets truncated instead of wrapped. Inserting a
    /// zero-width space after every `_` adds a break opportunity there without
    /// changing the visible text.
    private var wrappableTitle: String {
        cat.title.replacingOccurrences(of: "_", with: "_\u{200B}")
    }

    /// Used through `.equatable()` so a re-render of the parent cell does not re-render
    /// this cell unless one of its rendered inputs changed. Changes coming from
    /// `userManager` / `productData` still invalidate the cell through their publishers.
    static func == (lhs: ProjectListCell, rhs: ProjectListCell) -> Bool {
        lhs.cat == rhs.cat
            && lhs.isEditing == rhs.isEditing
            && lhs.isSelected == rhs.isSelected
            && lhs.thumbnailImage === rhs.thumbnailImage
            && lhs.jobSiteName == rhs.jobSiteName
            && lhs.uploadState == rhs.uploadState
            && lhs.cellWidth == rhs.cellWidth
            && lhs.visibleColumns == rhs.visibleColumns
            && lhs.contentWidth == rhs.contentWidth
    }

    private var columnSpacing: CGFloat {
        ProjectListColumnLayout.Metrics.columnSpacing(isIPhone: isIPhone)
    }

    /// Bảng bề rộng dùng chung với `ProjectColumnHeader`. Khối cột được chia 24 phần trên
    /// phần bề rộng còn lại sau khi trừ ô chọn, ảnh thumbnail, nút ba chấm và các khoảng cách.
    private var layout: ProjectListColumnLayout {
        ProjectListColumnLayout(
            visibleColumns: visibleColumns,
            availableWidth: ProjectListColumnLayout.Metrics.availableWidth(
                contentWidth: contentWidth,
                thumbnailWidth: cellWidth,
                visibleColumns: visibleColumns,
                isIPhone: isIPhone,
                isEditing: isEditing
            )
        )
    }

    private func isVisible(_ column: ProjectListColumnToggle) -> Bool {
        visibleColumns.contains(column)
    }

    /// Same alignment as the matching column of `ProjectColumnHeader`.
    private func alignment(for column: ProjectListColumnToggle) -> Alignment {
        ProjectColumnHeader.alignment(for: column)
    }

    private func textAlignment(for column: ProjectListColumnToggle) -> TextAlignment {
        ProjectColumnHeader.textAlignment(for: column)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: columnSpacing) {
                // Checkbox shown during multi-selection
                if isEditing {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(isSelected ? Color(hex: 0x0064BA) : .gray)
                        .font(.system(size: isIPhone ? 18 : 22))
                        .frame(width: ProjectListColumnLayout.Metrics.checkboxWidth(isIPhone: isIPhone))
                }

                // Thumbnail icon
                listTypeIcon
                    .contentShape(Rectangle())
                    .onTapGesture { onTap() }

                // Project Title — hiển thị đầy đủ, xuống dòng tuỳ ý (BR-7)
                if isVisible(.name) {
                    Text(wrappableTitle)
                        .font(.system(size: isIPhone ? 12 : 14))
                        .foregroundColor(userManager.setting.textColor)
                        .lineLimit(titleLineLimit)
                        .multilineTextAlignment(textAlignment(for: .name))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: layout.width(.name), alignment: alignment(for: .name))
                }

                // Jobsite
                if isVisible(.jobsite) {
                    Text(jobSiteName)
                        .font(.system(size: isIPhone ? 12 : 14))
                        .foregroundColor(userManager.setting.textColor.opacity(0.8))
                        .multilineTextAlignment(textAlignment(for: .jobsite))
                        .frame(width: layout.width(.jobsite), alignment: alignment(for: .jobsite))
                }

                // Photographer (User Name)
                if isVisible(.photographer) {
                    Text(productData.name(for: cat.userId ?? UserSession.shared.userInfo?.userId) ?? "")
                        .font(.system(size: isIPhone ? 12 : 14))
                        .foregroundColor(userManager.setting.textColor.opacity(0.8))
                        .multilineTextAlignment(textAlignment(for: .photographer))
                        .frame(width: layout.width(.photographer), alignment: alignment(for: .photographer))
                }

                // Positioning badge (RTK / GPS)
                if isVisible(.type) {
                    if let useVidoc = cat.useVidoc {
                        Text(useVidoc ? "RTK" : "GPS")
                            .font(.system(size: isIPhone ? 11 : 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(userManager.setting.getGpsRtkButtonColor(useVidoc ? 1 : 0))
                            .cornerRadius(4)
                            .frame(width: layout.width(.type), alignment: alignment(for: .type))
                    } else {
                        Spacer().frame(width: layout.width(.type))
                    }
                }

                // Hai cột ngày luôn độc lập với tuỳ chọn sắp xếp (BR-1).
                if isVisible(.capturedDate) {
                    dateColumn(.capturedDate, date: cat.captureDate)
                }

                if isVisible(.uploadDate) {
                    dateColumn(.uploadDate, date: cat.createDate)
                }

                if isVisible(.photo) {
                    Text(cat.numberOfImage == 0 ? "-" : "\(cat.numberOfImage)")
                        .font(.system(size: isIPhone ? 11 : 13))
                        .foregroundColor(userManager.setting.textColor.opacity(0.8))
                        .frame(width: layout.width(.photo), alignment: alignment(for: .photo))
                }

                // Processing status / upload progress
                if isVisible(.status) {
                    if uploadState.isActive {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(uploadState.statusTextKey.localized(userManager.userLanguage))
                                .font(.system(size: isIPhone ? 11 : 13))
                                .foregroundColor(userManager.setting.textColor)
                            ProgressView(value: uploadState.percentage, total: 1)
                                .frame(width: layout.width(.status))
                        }
                        .frame(width: layout.width(.status), alignment: alignment(for: .status))
                    } else {
                        let statusText = cat.statusList?.sfmStatus(for: userManager.userLanguage)
                        Text((statusText ?? "UPLOAD_WAITING").localized(userManager.userLanguage))
                            .font(.system(size: isIPhone ? 11 : 13))
                            .foregroundColor(userManager.setting.textColor.opacity(0.8))
                            .multilineTextAlignment(textAlignment(for: .status))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: layout.width(.status), alignment: alignment(for: .status))
                    }
                }

                // Additional vertical three-dot menu button — làn có bề rộng cố định,
                // trùng với làn tương ứng bên `ProjectColumnHeader`.
                Group {
                    if isEditing {
                        Color.clear
                    } else if ConnectivityMonitor.shared.isCurrentlyConnected() {
                        Menu {
                            actionMenuItems()
                        } label: {
                            verticalMenuIcon
                        }
                    } else {
                        verticalMenuIcon
                            .onTapGesture { isShowNoNetworkAlert = true }
                    }
                }
                .frame(width: ProjectListColumnLayout.Metrics.trailingWidth(isIPhone: isIPhone))
            }
            .padding(.horizontal, ProjectListColumnLayout.Metrics.horizontalPadding(isIPhone: isIPhone))
            .padding(.vertical, isIPhone ? 10 : 14)

            Divider()
                .background(Color.gray.opacity(0.3))
        }
        .background(userManager.setting.projectCellColor)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .strokeBorder(Color(hex: 0x0064BA), lineWidth: isSelected ? 1 : 0)
        )
    }

    /// Một cột ngày: ngày ở dòng đầu, giờ ở dòng sau, để cột giữ được bề ngang hẹp.
    private func dateColumn(_ column: ProjectListColumnToggle, date: Date) -> some View {
        let isJapanese = userManager.userLanguage == LanguageMode.ja.rawValue
        let dateStr = date.toString(format: isJapanese ? Constant.jpDateFormat : Constant.otherDateFormat)
        let timeStr = date.toString(format: Constant.timeFormat)

        return VStack(alignment: .center, spacing: 2) {
            Text(dateStr)
                .font(.system(size: isIPhone ? 11 : 13))
                .foregroundColor(userManager.setting.textColor.opacity(0.8))
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)

            Text(timeStr)
                .font(.system(size: isIPhone ? 11 : 13))
                .foregroundColor(userManager.setting.textColor.opacity(0.8))
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: layout.width(column), alignment: alignment(for: column))
    }

    private var verticalMenuIcon: some View {
        Image("VerticalMenu")
            .resizable()
            .renderingMode(.template)
            .scaleEffect(0.7)
            .foregroundColor(userManager.setting.iconColor)
            .frame(width: isIPhone ? 24 : 32, height: isIPhone ? 24 : 32)
    }

    private var listTypeIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.4))
                .frame(width: cellWidth, height: heightThumb)

            if cat.statusList?.getIsAR == true {
                Image("arImage")
                    .resizable()
                    .scaledToFill()
                    .frame(width: cellWidth, height: heightThumb)
                    .clipped()
                    .cornerRadius(4)
            } else if let img = thumbnailImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cellWidth, height: heightThumb)
                    .clipped()
                    .cornerRadius(4)
            } else {
                Image(systemName: "cube.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: isIPhone ? 18 : 24, height: isIPhone ? 18 : 24)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(width: cellWidth, height: heightThumb)
    }
}
