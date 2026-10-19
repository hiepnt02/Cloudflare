//
//  SelectFileFromGroupwarePopup.swift
//  Quick3D
//
//  Created by HungNT on 25/8/25.
//

import SwiftUI

// MARK: - Subview for each row in the list
struct GroupwareItemRow: View {
    let groupware: GroupwareModel
    let textColor: Color
    let onItemClick: (GroupwareModel) -> Void
    let onInfoClick: (CGRect) -> Void
    
    var body: some View {
        HStack {
            Text(groupware.name.fileNameWithoutExtension ?? "")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { onItemClick(groupware) }
            
            GeometryReader { geo in
                Button(action: { onInfoClick(geo.frame(in: .global)) }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(textColor.opacity(0.5))
                }
            }
            .frame(width: 20, height: 20)
            
            Text(groupware.name.fileExtension?.uppercased() ?? "")
                .frame(width: 110, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { onItemClick(groupware) }
            
            Text((Int(groupware.size) ?? 0).bytesToHumanReadable())
                .frame(width: 110, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { onItemClick(groupware) }
        }
        .font(.system(size: 16))
        .foregroundColor(textColor)
        .frame(height: 40)
    }
}

// MARK: - Main Popup View
struct GroupwarePopup: View {
    @EnvironmentObject var productData: ProductData
    @EnvironmentObject var userManager: UserManager
    
    @Binding var isShow: Bool
    @Binding var groupwareTypeSelected: GroupwareType
    @Binding var uploadCase: UploadCase
    @Binding var jobsite: JobSite.Site?
    
    var handler: (GroupwareModel) -> Void
    
    @State private var title: String = ""
    @State private var iconName: String = "icDashboard"
    @State private var listGroupware: [GroupwareModel] = []
    @State private var groupwareInfo: GroupwareModel? = nil
    @State private var isLoading: Bool = false
    
    @StateObject private var popoverManager = PopoverManager()
    
    private var textColor: Color { userManager.setting.textColor }
    private var themeColor: Color { userManager.setting.themeColor }
    
    var body: some View {
        if isShow {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { isShow = false }
                
                VStack(spacing: 0) {
                    headerSection
                    Divider().frame(height: 2).background(themeColor)
                    columnTitleSection
                    Divider().frame(height: 1).background(themeColor)
                    
                    if isLoading {
                        ProgressView().frame(maxHeight: .infinity)
                    } else if listGroupware.isEmpty {
                        Text("NO_DATA".localized(userManager.userLanguage))
                            .frame(maxHeight: .infinity)
                    } else {
                        contentView
                    }
                }
                .frame(width: UIScreen.main.bounds.width * (UserSession.isIPhone ? 0.75 : 0.53),
                       height: UIScreen.main.bounds.height * (UserSession.isIPhone ? 0.7 : 0.5))
                .padding(UserSession.isIPhone ? 20 : 30)
                .background(themeColor)
                .border(.gray, width: 1)
            }
            .overlay(popoverOverlay)
            .onAppear(perform: setupInitialData)
        }
    }
    
    // MARK: - Subviews
    private var headerSection: some View {
        HStack {
            Image(iconName)
                .resizable()
                .frame(width: UserSession.isIPhone ? 30 : 40, height: UserSession.isIPhone ? 30 : 40)
                .padding(.trailing, 10)
            
            Text(title)
                .foregroundColor(textColor)
                .font(.title2)
            
            Spacer()
            
            Button(action: { isShow = false }) {
                Image(systemName: "xmark").foregroundColor(textColor)
            }
        }
        .padding(.bottom, 10)
    }
    
    private var columnTitleSection: some View {
        HStack {
            Text("NAME".localized(userManager.userLanguage)).frame(maxWidth: .infinity, alignment: .leading)
            Text("EXTENSION".localized(userManager.userLanguage)).frame(width: 110, alignment: .leading)
            Text("SIZE".localized(userManager.userLanguage)).frame(width: 110, alignment: .leading)
        }
        .font(.system(size: 16, weight: .bold))
        .foregroundColor(textColor)
    }
    
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(listGroupware, id: \.nodeId) { item in
                    GroupwareItemRow(
                        groupware: item,
                        textColor: textColor,
                        onItemClick: { onItemClick($0) },
                        onInfoClick: { frame in
                            groupwareInfo = item
                            popoverManager.toggle(id: "\(item.nodeId)", frame: frame)
                        }
                    )
                    Divider().background(Color.gray)
                }
            }
        }
        .simultaneousGesture(DragGesture().onChanged { _ in popoverManager.hideAll() })
    }
    
    private var popoverOverlay: some View {
        Group {
            if let info = groupwareInfo, popoverManager.activePopoverID != nil {
                GroupwareInfoView(
                    fileName: info.name,
                    filePath: info.path,
                    offsetValue: CGSize(width: -80, height: -60)
                )
                .position(x: popoverManager.anchorFrame.midX, y: popoverManager.anchorFrame.midY)
            }
        }
    }
    
    // MARK: - Logic
    private func setupInitialData() {
        popoverManager.hideAll()
        isLoading = true
        
        switch groupwareTypeSelected {
        case .dashboard:
            title = "IMPORT_SMART_CONSTRUCTION_DASHBOARD".localized(userManager.userLanguage)
            iconName = "icDashboard"
            getGroupware(for: .dashboard, with: productData.lishDashboard)
        case .design:
            title = "IMPORT_SMART_CONSTRUCTION_DESIGN3D".localized(userManager.userLanguage)
            iconName = "icDesign3D"
            getGroupware(for: .design, with: productData.listDesign)
        }
    }
    
    private func getGroupware(for type: GroupwareType, with cachedData: [GroupwareModel]) {
        if !cachedData.isEmpty {
            self.listGroupware = cachedData
            self.isLoading = false
        } else {
            let caseType = (uploadCase == .Las) ? 2 : 1
            productData.getGroupwares(
                uploadCase: caseType,
                siteId: jobsite?.id ?? "",
                language: userManager.userLanguage
            ) {
                self.listGroupware = (type == .dashboard) ? productData.lishDashboard : productData.listDesign
                self.isLoading = false
            }
        }
    }
    
    private func onItemClick(_ groupware: GroupwareModel) {
        isShow = false
        handler(groupware)
    }
}
