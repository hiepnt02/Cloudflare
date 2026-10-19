//
//  ZipUploadPopup.swift
//  Quick3D
//
//  Created by ryoma.terai on 2024/09/12.
//

import SwiftUI
import UIKit
import MobileCoreServices
import UniformTypeIdentifiers


struct ZipUploadPopup: View {
    @State private var isPopupPresented: Bool = false
    var filteredSites: [JobSite.Site] {
        productData.jobSite?.sites.filter { $0.name.localizedCaseInsensitiveContains(searchText) } ?? []
    }
    
    @Binding var show: Bool
    @Binding var cat: Cat?
    @EnvironmentObject var productData: ProductData
    @EnvironmentObject var userManager: UserManager
    
    @Binding var projectName: String
    @Binding var searchText:String
    @Binding var value: JobSite.Site?
    
    var handler: (String, Bool, Cat?, URL?, String, Bool, Bool, Bool) -> Void
    
    @State var isShowJobSiteView: Bool = false
    @State private var isIPhone = UIDevice.current.isIphone
    @State private var disableButton: Bool = false
    @State private var useARMarker = false
    @State private var isKeyboardShow = false;
    @State private var coordinateSetting: Bool = false;
    @State private var linkDashboard: Bool = false;
    @State private var shouldInterpolate: Bool = true;
    
    @State private var addvancedSettingIsExpanded = false;
    
    @State private var linkTipIsShown = false;
    @State private var uploadTipIsShown = false;
    @State private var interpolateTipIsShown = false;
    
    @State private var anyDetailIsShown = false;
    
    @FocusState private var focusState: Bool
    
    @State private var isShowDocumentPicker = false
    @State private var selectedFileURL: URL?
    @State private var selectedFileName: String? = ""
    
    func hideDetails() {
        self.anyDetailIsShown = false;
        self.linkTipIsShown = false;
        self.uploadTipIsShown = false;
        self.interpolateTipIsShown = false;
    }
    
    func customPopover(isShown: Binding<Bool>, content: String, frameValue: (width: CGFloat, height: CGFloat), offsetValue: (x: CGFloat, y: CGFloat)) -> some View{
        Button(
            action: {
                if isShown.wrappedValue {
                    hideDetails();
                }
                else{
                    hideDetails();
                    self.anyDetailIsShown = true;
                    isShown.wrappedValue = true;
                }
            },
            label: {
                let questionIcon = "";
                Text(questionIcon)
                    .foregroundColor(userManager.setting.textColor)
                    .font(.custom(CustomFonts.FAFreeSolid, size: 20))
                    .fixedSize(horizontal: false, vertical: true)
                    .dynamicTypeSize(DynamicTypeSize.medium)
                    .frame(width: 30, height: 30)
                    .padding(.trailing, 20)
            }
        )
        .overlay(
            isShown.wrappedValue ?
            Text(content)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: frameValue.width, height: frameValue.height)
                .padding(.all, 5)
                .background(userManager.setting.themeColor, in: Rectangle(), fillStyle: FillStyle(eoFill: true))
                .foregroundColor(userManager.setting.textColor)
                .border(Color.gray, width: 1)
                .font(.caption.bold())
                .dynamicTypeSize(DynamicTypeSize.medium)
                .offset(x: offsetValue.x, y: offsetValue.y)
                .onTapGesture {}
            :
                nil
        )
    }
    
    var body: some View {
        ZStack {
                    contentView.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) {_ in
                        // Bool変数を変更
                        isKeyboardShow = true
                    }.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) {_ in
                        // Bool変数を変更
                        isKeyboardShow = false
                    }
            }
        .onTapGesture {
            if self.anyDetailIsShown{
                hideDetails();
            }
        }
    }
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ZIP_SELECT_FILE".localized(userManager.userLanguage))
                .lineLimit(2)
                .foregroundColor(userManager.setting.textColor)
                .frame(minHeight: isIPhone ? 20 : 30, alignment: .leading)
                .font(isIPhone ? .title3 : .title2)
                .padding(.bottom, isIPhone ? 10 : 20)
            
            ButtonSelectFile(
                buttonText: nil,
                fileTypes: [FileTypes[FileType.zip]!]
            ) { fileUrl, fileName in
                selectedFileURL = fileUrl
                selectedFileName = fileName
            }
            .padding(.bottom, UserSession.isIPhone ? 20 : 30)
            
            if productData.displayARSelection {
                Text("SELECT_PROCESSING_METHOD".localized(userManager.userLanguage))
                    .foregroundColor(userManager.setting.textColor)
                    .font(isIPhone ? .body : .title2)
                    .padding(.bottom, isIPhone ? 10 : 20)
                
                RadioButtonGroup(items: ["WITH_AR_MARKER".localized(userManager.userLanguage), "NO_AR_MARKER".localized(userManager.userLanguage)], direction: .horizon, selectedIndex: useARMarker ? 0 : 1) { index in
                    useARMarker = index == 0
                }
                .padding(.bottom, isIPhone ? 20 : 30)
                .padding(.leading, 10)
            }
            
            HStack() {
                Text("ALIGN_SMART_DASHBOARD".localized(userManager.userLanguage))
                    .foregroundColor(userManager.setting.textColor)
                    .font(.system(size: isIPhone ? 14 : 17))
                    .padding(.leading, 10)
                
                Spacer()
                
                customPopover(
                    isShown: $linkTipIsShown,
                    content:
                        "NOTE_SETTING".localized(userManager.userLanguage)
                    + "\n"
                    + "ONLY_FOLLOWING_CASES".localized(userManager.userLanguage)
                    + "\n"
                    + "・" + "WHEN_SETTING_DASHBOARD_COORDINATE_SYSTEM".localized(userManager.userLanguage)
                    + "\n"
                    + "・" + "WHEN_SHOOTING_VIDOC".localized(userManager.userLanguage),
                    frameValue: (width: 400, height: 110),
                    offsetValue: (x: -235, y: -75)
                )
                .zIndex(3)
                
                Toggle(isOn: $coordinateSetting) {}
                    .onChange(of: coordinateSetting){ checked in
                        // 座標系連携がoffならDashboard連携もoff
                        if !checked {
                            linkDashboard = false
                        }
                    }
                    .frame(width: 30)
                    .padding(.trailing, 30)
            }
            .padding(.bottom, isIPhone ? 7 : 10)
            .zIndex(linkTipIsShown ? 1 : 0)
            
            HStack() {
                Text("UPLORD_SYSTEM_SETTING".localized(userManager.userLanguage))
                    .foregroundColor(userManager.setting.textColor)
                    .font(.system(size: isIPhone ? 14 : 17))
                    .padding(.leading, 10)
                
                Spacer()
                
                customPopover(
                    isShown: $uploadTipIsShown,
                    content:"UPLORD_SETTING".localized(userManager.userLanguage)
                    + "\n"
                    + "ONLY_FOLLOWING_CASES".localized(userManager.userLanguage)
                    + "\n"
                    + "・" + "WHEN_ALIGN_TO_DASHBOARD_COORDINATE_SYSTEM".localized(userManager.userLanguage),
                    frameValue: (width: 400, height: 80),
                    offsetValue: (x: -235, y: -60)
                )
                .zIndex(3)
                
                Toggle(isOn: $linkDashboard){}
                    .onChange(of: linkDashboard){ checked in
                        // Dashboard連携がonなら座標系連携もon
                        if checked {
                            coordinateSetting = true
                        }
                    }
                    .frame(width: 30)
                    .padding(.trailing, 30)
            }
            .padding(.bottom, isIPhone ? 10 : 20)
            .zIndex(uploadTipIsShown ? 1 : 0)
            
            Button(action: {
                withAnimation(.none) {
                    addvancedSettingIsExpanded.toggle();
                }
            }, label: {
                HStack{
                    Text("【" + "ADVANCED_SETTINGS".localized(userManager.userLanguage) + "】")
                        .foregroundColor(userManager.setting.textColor)
                        .font(.system(size: isIPhone ? 14 : 17))
                        .padding(.leading, 10)
                    
                    let chevronIcon = addvancedSettingIsExpanded ? "" : "";
                    Text(chevronIcon)
                        .foregroundColor(userManager.setting.textColor)
                        .font(.custom(CustomFonts.FAFreeSolid, size: 20))
                        .fixedSize(horizontal: false, vertical: true)
                        .dynamicTypeSize(DynamicTypeSize.medium)
                        .frame(width: 30, height: 30)
                        .padding(.trailing, 20)
                    
                    Spacer()
                }
                .padding(.bottom, isIPhone ? 10 : 20)
                .contentShape(Rectangle())
            })
            .buttonStyle(PlainButtonStyle())
            
            HStack() {
                if (addvancedSettingIsExpanded){
                    Text("INTERPOLATE_SETTING_C1".localized(userManager.userLanguage))
                        .foregroundColor(userManager.setting.textColor)
                        .font(.system(size: isIPhone ? 14 : 17))
                        .padding(.leading, 10)
                    
                    Spacer()
                    
                    customPopover(
                        isShown: $interpolateTipIsShown,
                        content:"INTERPOLATE_SETTING_D1".localized(userManager.userLanguage)
                        + "\n"
                        + "INTERPOLATE_SETTING_D2".localized(userManager.userLanguage),
                        frameValue: (width: 400, height: 80),
                        offsetValue: (x: -235, y: -60)
                    )
                    .zIndex(3)
                    
                    Toggle(isOn: $shouldInterpolate){}
                        .frame(width: 30)
                        .padding(.trailing, 30)
                        .disabled(!linkDashboard)
                }
                
                else{
                    EmptyView();
                }
            }
            .padding(.bottom, isIPhone ? 10 : 20)
            .zIndex(uploadTipIsShown ? 1 : 0)
            
            HStack(spacing: 20) {
                Button(action: {
                    withAnimation(.linear(duration: 0.3)) {
                        show = false
                        isPopupPresented = false
                        searchText = ""
                        projectName = ""
                    }
                }, label: {
                    Text("CANCEL".localized(userManager.userLanguage))
                        .font(isIPhone ? .headline.bold() : .title3.bold())
                        .foregroundColor(userManager.setting.textColor)
                        .frame(height: isIPhone ? 40 : 55, alignment: .center)
                        .frame(minWidth: 0, maxWidth: .infinity)
                })
                .background(userManager.setting.themeColor)
                .buttonStyle(PlainButtonStyle())
                .border(userManager.setting.textColor, width: 1)
                
                Button(action: addAction
                       , label: {
                    Text("UPLOAD".localized(userManager.userLanguage))
                        .font(isIPhone ? .headline.bold() : .title3.bold())
                        .foregroundColor(.white)
                        .frame(height: isIPhone ? 40 : 55, alignment: .center)
                        .frame(minWidth: 0, maxWidth: .infinity)
                })
                .background(.blue)
                .buttonStyle(PlainButtonStyle())
                .disabled(selectedFileURL == nil)
            }
            .padding(.top, 10)
            .padding(.bottom, isIPhone ? 10 : 20)
        }
        .onAppear(){
            hideDetails();
            shouldInterpolate = true;
            addvancedSettingIsExpanded = false;
            coordinateSetting = userManager.setting.coordinateSetting
            linkDashboard = userManager.setting.linkDashboard
        }
    }
    
    // MARK: 検索フィールドがemptyの時の画面
    func siteScrollView(_ sites: [JobSite.Site]) -> some View {
        
        return ScrollView {
            VStack(spacing: 0) {
                ForEach(sites, id: \.self) { site in
                    VStack(spacing: 0) {
                        Text(site.name)
                            .foregroundColor(userManager.setting.textColor)
                            .onTapGesture {
                                self.value = site
                                isPopupPresented = false
                                searchText = site.name
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                disableButton = false
                            }
                            .frame(alignment: .leading)//iPad
                            .padding(10)
                        
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.gray)
                            .frame(alignment: .leading)//iPad
                    }
                }
            }
        }
        .background(userManager.setting.themeColor)
        .frame(height: isIPhone ? 80 : 120)
    }
    
    // MARK: 検索フィールドで検索された時の画面
    func filteredSiteScrollView() -> some View {
        let filteredSites = productData.jobSite?.sites.filter { $0.name.localizedCaseInsensitiveContains(searchText) } ?? []
        
        return Group {
            if filteredSites.isEmpty {
                // 検索に一致するサイトがない場合の表示
                Color.clear.frame(height: 0)
                
            } else {
                // 検索に一致するサイトがある場合の表示
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredSites, id: \.self) { site in
                            VStack(spacing: 0) {
                                Text(site.name)
                                    .foregroundColor(userManager.setting.textColor)
                                    .onTapGesture {
                                        self.value = site
                                        isPopupPresented = false
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        searchText = site.name
                                        disableButton = false
                                    }
                                    .frame(alignment: .leading)
                                    .padding(10)
                                
                                if filteredSites.count > 1 {
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(Color.gray)
                                        .frame(alignment: .leading)
                                }
                            }
                        }
                    }
                }
                .frame(width: 640, height: filteredSites.count > 1 ? 80 : 40)
                .background(userManager.setting.themeColor)
            }
        }
    }
}

extension ZipUploadPopup {
    private func addAction() {
        guard !projectName.isEmpty else { return }
        guard let value = value else { return }
        disableButton = true
        isPopupPresented = false
        
        guard ProductUtil.validationCheck(projectName) else {
            APAlert.shared.showAlert(title: "", message: "PROHIBITED_CHARACTER_MESSAGE".localized(userManager.userLanguage), buttonTitle: "CLOSE".localized(userManager.userLanguage))
            disableButton = false
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.linear(duration: 0.3)) {
                show = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.disableButton = false
                }
            }
            if cat != nil {
                cat?.title = projectName
                cat?.jobsiteId = value.id
            }
            handler(value.id, useARMarker, cat, selectedFileURL, selectedFileName!,coordinateSetting, linkDashboard, shouldInterpolate)
            searchText = ""
            projectName = ""
            selectedFileURL = nil
            selectedFileName = ""
        }
    }
}
