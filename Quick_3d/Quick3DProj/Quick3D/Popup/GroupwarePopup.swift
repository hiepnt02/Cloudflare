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
    
    private var textColor: Color { userManager.userSetting.getTextColor() }
    private var themeColor: Color { userManager.userSetting.getThemeColor() }
    
    var body: some View {
        if isShow {
            ZStack {
                // PopUp background color
                Color(.black)
                    .colorInvert()
                    .opacity(isShow ? 0.3 : 0)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    HStack {
                        Image(iconName)
                            .resizable()
                            .frame(
                                width: UserSession.isIPhone ? 30 : 40,
                                height: UserSession.isIPhone ? 30 : 40
                            )
                            .padding(.trailing, 10)
                        
                        Text(title)
                            .foregroundColor(userManager.setting.textColor)
                            .font(.title2)
                        
                        Spacer()
                        
                        Button(action: {
                            isShow = false
                        }, label: {
                            Image(systemName: "xmark")
                                .foregroundColor(userManager.setting.textColor)
                            
                        })
                    }
                    .padding(.bottom, 10)
                    
                    Divider()
                        .frame(height: 2)
                        .background(userManager.setting.themeColor)
                    
                    headerView()
                    
                    Divider()
                        .frame(height: 1)
                        .background(userManager.setting.themeColor)
                    
                    if !isLoading {
                        if !listGroupware.isEmpty {
                            contentView
                        } else {
                            noDataTextView
                        }
                    } else {
                        contentView
                    }
                }
                .frame(
                    width: UIScreen.main.bounds.width * (UserSession.isIPhone ? 0.75 : 0.53),
                    height: UIScreen.main.bounds.height * (UserSession.isIPhone ? 0.7 : 0.5)
                )
                .padding(.all, UserSession.isIPhone ? 20 : 30)
                .background(userManager.setting.themeColor)
                .border(.gray, width: 1)
            }
            .overlay(popoverOverlay)
            .onAppear(perform: setupInitialData)
        }
    }
    
    // MARK: - Subviews
    private var headerSection: some View {
        HStack {
            Text("NAME".localized(userManager.userLanguage))
                .foregroundColor(userManager.setting.textColor)
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("EXTENSION".localized(userManager.userLanguage))
                .foregroundColor(userManager.setting.textColor)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 110, alignment: .leading)
            
            Text("SIZE".localized(userManager.userLanguage))
                .foregroundColor(userManager.setting.textColor)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 110, alignment: .leading)
        }
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
    
    private func loadingView() -> some View {
        HStack {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(userManager.setting.textColor)
                .scaleEffect(0.8)
                .frame(width: 15, height: 15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    private func itemGroupware(groupware: GroupwareModel) -> some View {
        HStack {
            Text(groupware.name.split(separator: ".")[0])
                .font(.system(size: 16))
                .foregroundColor(userManager.setting.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 10)
            
            Text(groupware.name.split(separator: ".")[1].uppercased())
                .font(.system(size: 16))
                .foregroundColor(userManager.setting.textColor)
                .frame(width: 110, alignment: .leading)
            
            Text((Int(groupware.size) ?? 0).bytesToHumanReadable())
                .font(.system(size: 16))
                .foregroundColor(userManager.setting.textColor)
                .frame(width: 110, alignment: .leading)
        }
        .frame(height: itemHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
            isShow = false
            self.handler(groupware)
        }
    }
    
    private var noDataTextView: some View {
        Text("NO_DATA".localized(userManager.userLanguage))
            .font(.system(size: 16))
            .foregroundColor(userManager.setting.textColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
