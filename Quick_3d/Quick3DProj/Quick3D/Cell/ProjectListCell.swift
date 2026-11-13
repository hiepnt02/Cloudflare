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
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: isIPhone ? 8 : 12) {
                // Checkbox shown during multi-selection
                if isEditing {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(isSelected ? Color(hex: 0x0064BA) : .gray)
                        .font(.system(size: isIPhone ? 18 : 22))
                }

                // Thumbnail icon
                listTypeIcon
                    .contentShape(Rectangle())
                    .onTapGesture { onTap() }

                // Project Title
                Text(wrappableTitle)
                    .font(.system(size: isIPhone ? 12 : 14))
                    .foregroundColor(userManager.setting.textColor)
                    .lineLimit(titleLineLimit)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                // Jobsite
                Text(jobSiteName)
                    .font(.system(size: isIPhone ? 12 : 14))
                    .foregroundColor(userManager.setting.textColor.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(width: isIPhone ? 60 : 80, alignment: .center)
                

                // Photographer (User Name)
                Text(productData.name(for: cat.userId ?? UserSession.shared.userInfo?.userId) ?? "")
                    .font(.system(size: isIPhone ? 12 : 14))
                    .foregroundColor(userManager.setting.textColor.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(width: isIPhone ? 70 : 130, alignment: .center)

                // Positioning badge (RTK / GPS)
                if let useVidoc = cat.useVidoc {
                    Text(useVidoc ? "RTK" : "GPS")
                        .font(.system(size: isIPhone ? 11 : 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(userManager.setting.getGpsRtkButtonColor(useVidoc ? 1 : 0))
                        .cornerRadius(4)
                        .frame(width: isIPhone ? 40 : 54, alignment: .center)
                } else {
                    Spacer().frame(width: isIPhone ? 40 : 54)
                }

                // Project creation date and time: date on the first line, time on the
                // second one, so the column stays narrow.
                VStack(alignment: .center, spacing: 2) {
                    let dateDisplay = (productData.sortOption == .uploadDate) ? cat.createDate : cat.captureDate
                    let isJapanese = userManager.userLanguage == LanguageMode.ja.rawValue
                    let dateStr = dateDisplay.toString(format: isJapanese ? Constant.jpDateFormat : Constant.otherDateFormat)
                    let timeStr = dateDisplay.toString(format: Constant.timeFormat)

                    Text(dateStr)
                        .font(.system(size: isIPhone ? 11 : 13))
                        .foregroundColor(userManager.setting.textColor.opacity(0.8))
                        .lineLimit(1)

                    Text(timeStr)
                        .font(.system(size: isIPhone ? 11 : 13))
                        .foregroundColor(userManager.setting.textColor.opacity(0.8))
                        .lineLimit(1)
                }
                .frame(width: isIPhone ? 70 : 100, alignment: .center)
                
                Text(cat.numberOfImage == 0 ? "-" : "\(cat.numberOfImage)")
                    .font(.system(size: isIPhone ? 11 : 13))
                    .foregroundColor(userManager.setting.textColor.opacity(0.8))
                    .frame(width: isIPhone ? 60 : 80, alignment: .center)

                // Processing status / upload progress
                if uploadState.isUploading {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("UPLOADING".localized(userManager.userLanguage))
                            .font(.system(size: isIPhone ? 11 : 13))
                            .foregroundColor(userManager.setting.textColor)
                        ProgressView(value: uploadState.percentage, total: 1)
                            .frame(width: isIPhone ? 60 : 110)
                    }
                    .frame(width: isIPhone ? 80 : 100, alignment: .leading)
                } else {
                    let statusText = cat.statusList?.sfmStatus(for: userManager.userLanguage)
                    let defaultText = productData.uploadProjectQueue.isInQueue(catId: cat.id) ? "PREPARING_FOR_DATA_UPLOAD" : "UPLOAD_WAITING"
                    Text((statusText ?? defaultText).localized(userManager.userLanguage))
                        .font(.system(size: isIPhone ? 11 : 13))
                        .foregroundColor(userManager.setting.textColor.opacity(0.8))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: isIPhone ? 80 : 100, alignment: .leading)
                }

                // Additional vertical three-dot menu button
                if isEditing {
                    Spacer().frame(width: isIPhone ? 20 : 30)
                } else {
                    if ConnectivityMonitor.shared.isCurrentlyConnected() {
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
            }
            .padding(.horizontal, isIPhone ? 8 : 12)
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
