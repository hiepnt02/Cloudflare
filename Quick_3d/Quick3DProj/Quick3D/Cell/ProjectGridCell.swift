//
//  ProjectGridCell.swift
//  Quick3D
//
//  Created by HungNT on 26/5/26.
//

import SwiftUI
import Alamofire
import DeviceKit

struct ProjectGridCell: View {
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
    @Binding var isShowNoNetworkAlert: Bool
    
    @State private var isShowingRemovedToolTip = false
    @State private var isShowingEditingToolTip = false
    
    private var isIPhone: Bool { UIDevice.current.isIphone }

    var body: some View {
        ZStack(alignment: .topLeading) {
            userManager.setting.projectCellColor

            VStack(alignment: .leading, spacing: 0) {
                headerSection
                contentSection
            }
        }
        .border(Color(hex: 0x0064BA), width: isSelected ? 1 : 0)
    }

    private var headerSection: some View {
        Group {
            if isEditing || (uploadProject.isUploading && uploadProject.projectId == cat.id) {
                gridHeaderLabel(isEditingMode: true)
            } else {
                if ConnectivityMonitor.shared.isCurrentlyConnected() {
                    Menu {
                        actionMenuItems
                    } label: {
                        gridHeaderLabel(isEditingMode: false)
                    }
                } else {
                    gridHeaderLabel(isEditingMode: false)
                        .contentShape(Rectangle())
                }
            }
        }
    }

    private func gridHeaderLabel(isEditingMode: Bool) -> some View {
        HStack(spacing: 0) {
            Text(cat.title)
                .lineLimit(1)
                .font(.system(size: isIPhone ? 18 : 24))
                .padding(.leading, isIPhone ? 5 : 10)
                .padding(.trailing, isIPhone ? -4 : -8)
                .foregroundColor(userManager.setting.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image("VerticalMenu")
                .resizable()
                .renderingMode(.template)
                .scaleEffect(0.7)
                .foregroundColor(isEditingMode ? .white : userManager.setting.iconColor)
                .frame(width: isIPhone ? 30 : 40, height: isIPhone ? 30 : 40)
        }
        .frame(height: isIPhone ? 30 : 50)
        .contentShape(Rectangle())
        .zIndex(10)
        .onTapGesture {
            if !ConnectivityMonitor.shared.isCurrentlyConnected() {
                isShowNoNetworkAlert = true
            }
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            imageThumbnailOverlay

            VStack(alignment: .leading, spacing: isIPhone ? 2 : 6) {
                dateTimeAndSourceRow
                jobSiteAndRemovePointRow
                userNameLabel
                statusAndProgressRow
                uploadStatusFooter
            }
            .padding(.horizontal, isIPhone ? 5 : 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private var imageThumbnailOverlay: some View {
        ZStack(alignment: .bottomTrailing) {
            let height: CGFloat = isIPhone ? 80 : 104

            if cat.statusList?.getIsAR == true {
                Image("arImage")
                    .resizable()
                    .scaledToFill()
                    .frame(height: height)
                    .clipped()
                    .background(Color(.lightGray.withAlphaComponent(0.3)))
                    .overlay(alignment: .bottomTrailing) { rtkGpsBadge }
            } else if let img = thumbnailImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: height)
                    .clipped()
                    .background(Color(.lightGray.withAlphaComponent(0.3)))
                    .overlay(alignment: .bottomTrailing) { rtkGpsBadge }
            } else {
                Rectangle()
                    .fill(.gray)
                    .frame(height: height)
            }
        }
    }

    private var rtkGpsBadge: some View {
        Group {
            if let useVidoc = cat.useVidoc {
                Text(useVidoc ? "RTK" : "GPS")
                    .padding(2)
                    .foregroundColor(.white)
                    .background(userManager.setting.getGpsRtkButtonColor(useVidoc ? 1 : 0))
            }
        }
    }

    private var dateTimeAndSourceRow: some View {
        HStack(spacing: isIPhone ? 1 : 10) {
            let dateDisplay = (productData.sortOption == .uploadDate) ? cat.createDate : cat.captureDate
            let dateStr = dateDisplay.toString(format: userManager.userLanguage == LanguageMode.ja.rawValue ? Constant.jpTimeFormat : Constant.globalTimeFormat)

            Text(dateStr)
                .font(.system(size: isIPhone ? 12 : 14))
                .lineLimit(1)
                .foregroundColor(userManager.setting.textColor)

            Spacer()

            HStack(spacing: 1) {
                Image(cat.localSourceImage)
                    .colorMultiply(cat.localSourceColor(colorTheme: userManager.setting.colorTheme))
                Image(cat.remoteSourceImage)
                    .colorMultiply(cat.remoteSourceColor(colorTheme: userManager.setting.colorTheme))
            }
        }
        .padding(.top, 10)
    }

    private var jobSiteAndRemovePointRow: some View {
        HStack(spacing: isIPhone ? 1 : 10) {
            Text(jobSiteName)
                .lineLimit(1)
                .font(.system(size: isIPhone ? 12 : 14))
                .foregroundColor(userManager.setting.textColor)

            Spacer()

            if cat.statusList?.isPointRemove == true {
                removePointIcon
            }
        }
    }

    private var removePointIcon: some View {
        Image(cat.removePointImage(colorTheme: userManager.setting.colorTheme))
            .onLongPressGesture(minimumDuration: 1.0) { isPressing in
                withAnimation { isShowingRemovedToolTip = isPressing }
            } perform: {}
            .overlay(alignment: .topTrailing) {
                if isShowingRemovedToolTip {
                    tooltipView(text: "REMOVED_POINT_CLOUD".localized(userManager.userLanguage), offset: -30)
                }
            }
    }

    private var userNameLabel: some View {
        Text(productData.name(for: cat.userId ?? UserSession.shared.userInfo?.userId) ?? "")
            .lineLimit(1)
            .font(.system(size: isIPhone ? 12 : 14))
            .foregroundColor(userManager.setting.textColor)
    }

    private var statusAndProgressRow: some View {
        HStack(spacing: isIPhone ? 4 : 6) {
            if uploadProject.isUploading && uploadProject.projectId == cat.id {
                VStack {
                    Spacer().frame(height: isIPhone ? 14 : 21)
                    ProgressView(value: uploadProject.uploadPercentage, total: 1)
                }
            } else {
                statusIndicatorGroup
            }

            Spacer()

            if cat.isEditing {
                editingStatusIcon
            }
        }
    }

    private var statusIndicatorGroup: some View {
        HStack(spacing: isIPhone ? 4 : 6) {
            if let status = cat.statusList {
                StatusView(index: 1, status: status.isUploaded ? .completed : (status.isUploadFail ? .error : .normal))
                StatusView(index: 2, status: status.isSfmCompleted ? .completed : (status.isSfmFail ? .error : .normal))
                StatusView(index: 3, status: status.isHelmertCompleted ? .completed : (status.isHelmertFail ? .error : .normal))
                StatusView(index: 4, status: status.isVerificationCompleted ? .completed : .normal)
                StatusView(index: 5, status: status.isDashboardUploaded ? .dashboard_upload : .normal)
            } else {
                ForEach(1...5, id: \.self) { i in
                    StatusView(index: i, status: .normal)
                }
            }
        }
    }

    private var editingStatusIcon: some View {
        Image("editing")
            .resizable()
            .renderingMode(.template)
            .foregroundColor(userManager.setting.colorTheme == .light ? Color(red: 20/255, green: 10/255, blue: 148/255) : .white)
            .rotationEffect(.degrees(180))
            .frame(width: isIPhone ? 18 : 25, height: isIPhone ? 18 : 25)
            .onLongPressGesture(minimumDuration: 1.0) { isPressing in
                withAnimation { isShowingEditingToolTip = isPressing }
            } perform: {}
            .overlay(alignment: .topTrailing) {
                if isShowingEditingToolTip {
                    tooltipView(text: "WHILE_EDIT".localized(userManager.userLanguage), offset: -35)
                }
            }
    }

    private var uploadStatusFooter: some View {
        Group {
            if uploadProject.isUploading && uploadProject.projectId == cat.id {
                HStack {
                    Text("UPLOADING".localized(userManager.userLanguage))
                        .font(.system(size: isIPhone ? 10 : 12))
                    Spacer()
                    Text("\(Int(uploadProject.uploadPercentage * 100))%")
                        .font(.system(size: isIPhone ? 12 : 14))
                }
                .foregroundColor(userManager.setting.textColor)
                .padding(.bottom, 10)
            } else {
                let statusText = cat.statusList?.sfmStatus(for: userManager.userLanguage)
                let defaultText = productData.uploadProjectQueue.isInQueue(catId: cat.id) ? "PREPARING_FOR_DATA_UPLOAD" : "UPLOAD_WAITING"

                Text((statusText ?? defaultText).localized(userManager.userLanguage))
                    .font(.system(size: isIPhone ? 11 : 14))
                    .foregroundColor(userManager.setting.textColor)
                    .padding(.bottom, 10)
            }
        }
    }

    private func tooltipView(text: String, offset: CGFloat) -> some View {
        ZStack {
            GeometryReader { geometry in
                Text(text)
                    .font(.caption)
                    .padding(4)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: true, vertical: false)
                    .cornerRadius(8)
                    .frame(width: geometry.size.width, alignment: .trailing)
                    .offset(y: offset)
            }
            Triangle()
                .fill(Color.gray)
                .frame(width: 30, height: 10)
                .offset(y: -20)
        }
    }
}
