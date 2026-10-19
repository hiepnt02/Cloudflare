//
//  DesignUploadPopup.swift
//  Quick3D
//
//  Created by ryoma.terai on 2024/09/09.
//

import SwiftUI
import UIKit
import MobileCoreServices

struct DesignUploadPopup: View {
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
    
    var handler: (String, Bool, Cat?, URL?, String) -> Void
    
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
                    .foregroundColor(userManager.userSetting.getTextColor())
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
                .background(userManager.userSetting.getThemeColor(), in: Rectangle(), fillStyle: FillStyle(eoFill: true))
                .foregroundColor(userManager.userSetting.getTextColor())
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
            if show {
                // PopUp background color
                Color(.black)
                    .colorInvert()
                    .opacity(show ? 0.3 : 0)
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView(showsIndicators: false) {
                    contentView.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) {_ in
                        // Bool変数を変更
                        isKeyboardShow = true
                    }.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) {_ in
                        // Bool変数を変更
                        isKeyboardShow = false
                    }
                }
                .frame(width: UIScreen.main.bounds.width * 0.70,
                       height: UIScreen.main.bounds.height * (isKeyboardShow ? 0.55 : 0.80))
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
            HStack {
                Text("DESIGN_DATA_UPLOAD".localized(userManager.userLanguage))
                    .foregroundColor(userManager.userSetting.getTextColor())
                    .font(.title2.bold())
                
                Spacer()
                
                Button(action: {
                    show = false
                    searchText = ""
                    projectName = ""
                    isPopupPresented = false
                }, label: {
                    Image(systemName: "xmark")
                        .foregroundColor(userManager.userSetting.getTextColor())
                    
                })
            }
            .padding(.top, isIPhone ? 20: 30)
            .padding(.bottom, 10)
            
            Divider()
                .frame(height: 2)
                .background(userManager.userSetting.getThemeColor())
                .padding(.bottom, isIPhone ? 10 : 20)
            Text("XML_SELECT_FILE".localized(userManager.userLanguage))
                .lineLimit(2)
                .foregroundColor(userManager.userSetting.getTextColor())
                .frame(minHeight: isIPhone ? 20 : 30, alignment: .leading)
                .font(isIPhone ? .title3 : .title2)
                .padding(.bottom, isIPhone ? 10 : 20)
            
            HStack {
                Button(action: {
                    isShowDocumentPicker = true
                }) {
                    Text("SELECT_FILE".localized(userManager.userLanguage))
                        .foregroundColor(.white)
                        .font(isIPhone ? .body : .title3)
                        .frame(width: 200, height: isIPhone ? 40 : 55, alignment: .center)
                }
                .background(.gray)
                .padding(.bottom, isIPhone ? 20 : 30)
                .fullScreenCover(isPresented: $isShowDocumentPicker) {
                    DocumentPicker { url in
                        // ファイルが選択された後の処理
                        selectedFileURL = url
                        if let lastSlashIndex = selectedFileURL!.absoluteString.lastIndex(of: "/") {
                            selectedFileName = String(selectedFileURL!.absoluteString[selectedFileURL!.absoluteString.index(after: lastSlashIndex)...])
                        }
                    }
                }
                
                Text((selectedFileName != nil) ? selectedFileName!.removingPercentEncoding ?? selectedFileName! : "")
                    .foregroundColor(userManager.userSetting.getTextColor())
                    .frame(minHeight: isIPhone ? 20 : 30, alignment: .leading)
                    .font(isIPhone ? .title3 : .title2)
                    .padding(.leading,20)
                    .padding(.bottom, isIPhone ? 20 : 30)
                
            }
            
//            Text("PROJECT_NAME_INPUT".localized(userManager.userLanguage))
//                .lineLimit(2)
//                .foregroundColor(userManager.userSetting.getTextColor())
//                .frame(minHeight: isIPhone ? 20 : 30, alignment: .leading)
//                .font(isIPhone ? .title3 : .title2)
//                .padding(.bottom, isIPhone ? 10 : 20)
//            
//            TextField("PROJECT_NAME".localized(userManager.userLanguage), text: $projectName)
//                .foregroundColor(userManager.userSetting.getTextColor())
//                .disableAutocorrection(true)
//                .padding(15)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 2)
//                        .stroke(Color(.lightGray), lineWidth: 1)
//                        .overlay(alignment: .bottom) {
//                            if focusState {
//                                Rectangle()
//                                    .frame(height: 4)
//                                    .foregroundColor(.blue)
//                            }
//                        }
//                )
//                .modifier(ClearButton(text: $projectName))
//                .font(.body)
//                .padding(.bottom, 30)
//                .focused($focusState)
//            
//            Text("PLS_SELECT_JOBSITE".localized(userManager.userLanguage))
//                .lineLimit(2)
//                .foregroundColor(userManager.userSetting.getTextColor())
//                .frame(minHeight: isIPhone ? 20 : 30, alignment: .leading)
//                .font(isIPhone ? .title3 : .title2)
//                .padding(.bottom, isIPhone ? 10 : 20)
//            
//            ZStack(){
//                TextField("", text: $searchText)
//                    .frame(height: isIPhone ? 40 : 55, alignment: .leading)
//                    .padding(.leading, 10)
//                    .border(Color.gray, width: 1)
//                    .padding(.bottom, 30)
//                    .foregroundColor(userManager.userSetting.getTextColor())
//                    .onTapGesture {
//                        // テキストフィールドがタップされた時にキーボードを表示
//                        UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil, for: nil)
//                        // テキストフィールドがタップされたときにカスタムポップアップを表示
//                        isPopupPresented = true
//                    }
//                    .overlay(
//                        isPopupPresented ?
//                        VStack(){
//                            if searchText.isEmpty {
//                                VStack(spacing: 0) {
//                                    siteScrollView(productData.jobSite?.sites ?? [])
//                                }
//                            } else {
//                                VStack(spacing: 0) {
//                                    
//                                    filteredSiteScrollView()
//                                }
//                            }
//                        }
//                            .frame(alignment: .leading)
//                            .border(Color.gray, width: 1)
//                            .position(x: isIPhone ? 320 : 320, y: isIPhone ? -40 + (searchText.isEmpty ? 0 : filteredSites.count > 1 ? 0 : 20) : -60 + (searchText.isEmpty ? 0 : filteredSites.count > 1 ? 20 : 40))
//                        : nil
//                        
//                    )
//                    .overlay {
//                        if value != nil {
//                            Button(
//                                action: {
//                                    value = nil
//                                    searchText = ""
//                                    isPopupPresented = false
//                                    disableButton = true
//                                }
//                            ) {
//                                Text("✖")
//                                    .font(.system(size: 20).bold())
//                                    .foregroundColor(userManager.userSetting.getTextColor())
//                            }
//                            .frame(width: 40, height: 40)
//                            .position(x: 620, y: isIPhone ? 20 : 30)
//                        } else {
//                            Image("arrowDown")
//                                .renderingMode(.template)
//                                .foregroundColor(userManager.userSetting.getTextColor())
//                                .allowsHitTesting(false)
//                                .position(x: 620, y: isIPhone ? 20 : 30)
//                        }
//                    }
//                    .padding(.top, 30)
//            }
//            
//            Button(action: {
//                self.isShowJobSiteView.toggle()
//            }) {
//                Text("CREATE_NEW_SITE".localized(userManager.userLanguage))
//                    .foregroundColor(.white)
//                    .font(isIPhone ? .body : .title3)
//                    .frame(width: 200, height: isIPhone ? 40 : 55, alignment: .center)
//            }
//            .background(.gray)
//            .padding(.bottom, isIPhone ? 20 : 30)
//            .fullScreenCover(isPresented: $isShowJobSiteView) {
//                JobSiteWebView() {
//                    productData.fetchJobSiteData()
//                }
//            }
//            
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
                        .foregroundColor(.white)
                        .frame(height: isIPhone ? 40 : 55, alignment: .center)
                        .frame(minWidth: 0, maxWidth: .infinity)
                })
                .background(.black.opacity(0.7))
                .buttonStyle(PlainButtonStyle())
                .border(.gray, width: 1)
                
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
                .disabled(disableButton)
            }
            .padding(.top, 10)
            .padding(.bottom, isIPhone ? 10 : 20)
        }
        .padding(.all, isIPhone ? 20 : 30)
        .background(userManager.userSetting.getThemeColor())
        .frame(width: isIPhone ? 680 : 700)
        .border(.gray, width: 1)
        .onAppear(){
            hideDetails();
            shouldInterpolate = true;
            addvancedSettingIsExpanded = false;
            coordinateSetting = userManager.userSetting.coordinateSetting
            linkDashboard = userManager.userSetting.linkDashboard
        }
    }
    
    // MARK: 検索フィールドがemptyの時の画面
    func siteScrollView(_ sites: [JobSite.Site]) -> some View {
        
        return ScrollView {
            VStack(spacing: 0) {
                ForEach(sites, id: \.self) { site in
                    VStack(spacing: 0) {
                        Text(site.name)
                            .foregroundColor(userManager.userSetting.getTextColor())
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
        .background(userManager.userSetting.getThemeColor())
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
                                    .foregroundColor(userManager.userSetting.getTextColor())
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
                .background(userManager.userSetting.getThemeColor())
            }
        }
    }
}

extension DesignUploadPopup {
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
            handler(value.id, useARMarker, cat, selectedFileURL, selectedFileName!)
            searchText = ""
            projectName = ""
            selectedFileURL = nil
            selectedFileName = ""
        }
    }
}
