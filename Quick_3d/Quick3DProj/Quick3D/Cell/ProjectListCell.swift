//
//  ProjectListCell.swift
//  Quick3D
//
//  Created by HungNT on 26/5/26.
//

import SwiftUI
import Alamofire
import DeviceKit

struct ProjectListCell: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var productData: ProductData
    @EnvironmentObject var uploadProject: UploadProject

    var cat: Cat
    @Binding var isEditing: Bool
    @Binding var isSelected: Bool
    
    let thumbnailImage: UIImage?
    let jobSiteName: String
    let actionMenuItems: AnyView
    let onTap: () -> Void
    let onLongPress: () -> Void
    @Binding var isShowNoNetworkAlert: Bool
    @Binding var cellWidth: CGFloat

    private var isIPhone: Bool { UIDevice.current.isIphone }
    private var listIconSize: CGFloat { isIPhone ? 36 : 50 }
    
    private var heightThumb: CGFloat { isIPhone ? 80 : 104 }

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

                // Project Title
                Text(cat.title)
                    .font(.system(size: isIPhone ? 13 : 15))
                    .foregroundColor(userManager.setting.textColor)
                    .lineLimit(4)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                // Jobsite
                Text(jobSiteName)
                    .font(.system(size: isIPhone ? 12 : 14))
                    .foregroundColor(userManager.setting.textColor.opacity(0.8))
                    .frame(width: isIPhone ? 60 : 80, alignment: .leading)
                

                // Photographer (User Name)
                Text(productData.name(for: cat.userId ?? UserSession.shared.userInfo?.userId) ?? "")
                    .font(.system(size: isIPhone ? 12 : 14))
                    .foregroundColor(userManager.setting.textColor.opacity(0.8))
                    .frame(width: isIPhone ? 70 : 130, alignment: .leading)

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

                // Project creation date and time
                VStack(alignment: .leading, spacing: 2) {
                    let dateDisplay = (productData.sortOption == .uploadDate) ? cat.createDate : cat.captureDate
                    let dateStr = dateDisplay.toString(format: userManager.userLanguage == LanguageMode.ja.rawValue ? Constant.jpTimeFormat : Constant.globalTimeFormat)
                    
                    Text(dateStr)
                        .font(.system(size: isIPhone ? 11 : 13))
                        .foregroundColor(userManager.setting.textColor.opacity(0.8))
                        .lineLimit(1)
                }
                .frame(width: isIPhone ? 70 : 100, alignment: .leading)
                
                Text(cat.numberOfImage == 0 ? "-" : "\(cat.numberOfImage)")
                    .font(.system(size: isIPhone ? 11 : 13))
                    .foregroundColor(userManager.setting.textColor.opacity(0.8))
                    .frame(width: isIPhone ? 60 : 80, alignment: .leading)

                // Processing status / upload progress
                if uploadProject.isUploading && uploadProject.projectId == cat.id {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("UPLOADING".localized(userManager.userLanguage))
                            .font(.system(size: isIPhone ? 11 : 13))
                            .foregroundColor(userManager.setting.textColor)
                        ProgressView(value: uploadProject.uploadPercentage, total: 1)
                            .frame(width: isIPhone ? 60 : 110)
                    }
                    .frame(width: isIPhone ? 80 : 100, alignment: .leading)
                } else {
                    let statusText = cat.statusList?.sfmStatus(for: userManager.userLanguage)
                    let defaultText = productData.uploadProjectQueue.isInQueue(catId: cat.id) ? "PREPARING_FOR_DATA_UPLOAD" : "UPLOAD_WAITING"
                    Text((statusText ?? defaultText).localized(userManager.userLanguage))
                        .font(.system(size: isIPhone ? 11 : 13))
                        .foregroundColor(userManager.setting.textColor.opacity(0.8))
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: isIPhone ? 80 : 100, alignment: .leading)
                }

                // Additional vertical three-dot menu button
                if isEditing {
                    Spacer().frame(width: isIPhone ? 20 : 30)
                } else {
                    if ConnectivityMonitor.shared.isCurrentlyConnected() {
                        Menu {
                            actionMenuItems
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
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .onLongPressGesture { onLongPress() }

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
