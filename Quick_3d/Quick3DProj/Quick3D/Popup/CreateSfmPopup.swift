//
//  JobSitePopup.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 26/04/2022.
//

import SwiftUI

struct CreateSfmPopup: View {
    @State private var isPopupPresented: Bool = false
    var filteredSites: [JobSite.Site] {
        productData.jobSite?.sites.filter { $0.name.localizedCaseInsensitiveContains(searchText) } ?? []
    }
    
    @State var value: JobSite.Site?
    @Binding var show: Bool
    @EnvironmentObject var productData: ProductData
    @EnvironmentObject var userManager: UserManager
    
    @State private var projectName: String = ""
    @State private var searchText = ""
    
    var handler: (String,String, Bool, Bool, Bool) -> Void
    
    @State var isShowJobSiteView: Bool = false
    @State private var isIPhone = UIDevice.current.isIphone
    @State private var disableButton = true
    @State private var useARMarker = false
    @State private var isKeyboardShow = false;
    @State private var coordinateSetting: Bool = false;
    @State private var linkDashboard: Bool = false;
    
    @State private var linkTipIsShown = false;
    @State private var uploadTipIsShown = false;
    
    @State private var anyDetailIsShown = false;
    @FocusState private var focusState: Bool
    
    func hideDetails() {
        self.anyDetailIsShown = false;
        self.linkTipIsShown = false;
        self.uploadTipIsShown = false;
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
                    .foregroundColor(.white)
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
                .background(.black, in: Rectangle(), fillStyle: FillStyle(eoFill: true))
                .foregroundColor(.white)
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
                    contentView.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) {notification in
                        // Bool変数を変更
                        isKeyboardShow = true
                    }.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) {_ in
                        // Bool変数を変更
                        isKeyboardShow = false
                    }
                }
                .frame(width: UIScreen.main.bounds.width * 0.70,
                       height: UIScreen.main.bounds.height * (isKeyboardShow ? 0.45 : 0.70))
//                .offset(x: 0, y: isKeyboardShow ? -UIScreen.main.bounds.height * 0.1 : 0)
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
                Text("SFMProcessing".localized(userManager.userLanguage))
                    .foregroundColor(.white)
                    .font(.title2.bold())
                
                Spacer()
                
                Button(action: {
                    show = false
                    isPopupPresented = false
                    projectName = ""
                    searchText = ""
                    
                }, label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                    
                })
            }
            .padding(.top, isIPhone ? 20: 30)
            .padding(.bottom, 10)
            
            Divider()
                .frame(height: 2)
                .background(.white)
                .padding(.bottom, isIPhone ? 10 : 20)
            
            Text("PROJECT_NAME_INPUT".localized(userManager.userLanguage))
                .lineLimit(2)
                .foregroundColor(.white)
                .frame(minHeight: isIPhone ? 20 : 30, alignment: .leading)
                .font(isIPhone ? .title3 : .title2)
                .padding(.bottom, isIPhone ? 10 : 20)
            
            TextField("PROJECT_NAME".localized(userManager.userLanguage), text: $projectName)
                        .foregroundColor(.white)
//                .foregroundColor(userManager.userSetting.getTextColor())
                .disableAutocorrection(true)
                .padding(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color(.lightGray), lineWidth: 1)
                        .overlay(alignment: .bottom) {
                            if focusState {
                                Rectangle()
                                    .frame(height: 4)
                                    .foregroundColor(.blue)
                            }
                        }
                )
                .modifier(ClearButton(text: $projectName))
                .font(.body)
                .padding(.bottom, 30)
                .focused($focusState)
            
            Text("PLS_SELECT_JOBSITE".localized(userManager.userLanguage))
                .lineLimit(2)
                .foregroundColor(.white)
                .frame(minHeight: isIPhone ? 20 : 30, alignment: .leading)
                .font(isIPhone ? .title3 : .title2)
                .padding(.bottom, isIPhone ? 10 : 20)
            
            ZStack(){
                TextField("", text: $searchText)
                    .frame(height: isIPhone ? 40 : 55, alignment: .leading)
                    .padding(.leading, 10)
                    .border(Color.gray, width: 1)
                    .padding(.bottom, 30)
                    .foregroundColor(.white)
                    .onTapGesture {
                        // テキストフィールドがタップされた時にキーボードを表示
                        UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil, for: nil)
                        // テキストフィールドがタップされたときにカスタムポップアップを表示
                        isPopupPresented = true
                        
                    }
                    .overlay(
                        isPopupPresented ?
                        VStack(){
                            if searchText.isEmpty {
                                VStack(spacing: 0) {
                                    siteScrollView(productData.jobSite?.sites ?? [])
                                }
                            } else {
                                VStack(spacing: 0) {
                                    
                                    filteredSiteScrollView()
                                }
                            }
                        }
                            .frame(alignment: .leading)
                            .border(Color.gray, width: 1)
                            .position(x: isIPhone ? 320 : 320, y: isIPhone ? -40 + (searchText.isEmpty ? 0 : filteredSites.count > 1 ? 0 : 20) : -60 + (searchText.isEmpty ? 0 : filteredSites.count > 1 ? 20 : 40))
                        : nil
                        
                    )
                    .overlay {
                        if value != nil {
                            Button(
                                action: {
                                    value = nil
                                    searchText = ""
                                    isPopupPresented = false
                                    disableButton = true
                                }
                            ) {
                                Text("✖")
                                    .font(.system(size: 20).bold())
                                    .foregroundColor(.white)
                            }
                            .frame(width: 40, height: 40)
                            .position(x: 620, y: isIPhone ? 20 : 30)
                        } else {
                            Image("arrowDown")
                                .renderingMode(.template)
                                .foregroundColor(.white)
                                .allowsHitTesting(false)
                                .position(x: 620, y: isIPhone ? 20 : 30)
                        }
                    }
                    .padding(.top, 30)
            }
            
            Button(action: {
                self.isShowJobSiteView.toggle()
            }) {
                Text("CREATE_NEW_SITE".localized(userManager.userLanguage))
                    .foregroundColor(.white)
                    .font(isIPhone ? .body : .title3)
                    .frame(width: 200, height: isIPhone ? 40 : 55, alignment: .center)
            }
            .background(.gray)
            .padding(.bottom, isIPhone ? 20 : 30)
            .fullScreenCover(isPresented: $isShowJobSiteView) {
                JobSiteWebView() {
                    productData.fetchJobSiteData()
                }
            }
            
            if productData.displayARSelection {
                Text("SELECT_PROCESSING_METHOD".localized(userManager.userLanguage))
                    .foregroundColor(.white)
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
                    .foregroundColor(.white)
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
                    .foregroundColor(.white)
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
            }.padding(.bottom, isIPhone ? 10 : 20)
            .zIndex(uploadTipIsShown ? 1 : 0)
            
            HStack(spacing: 20) {
                Button(action: {
                    withAnimation(.linear(duration: 0.3)) {
                        show = false
                        isPopupPresented = false
                        projectName = ""
                        searchText = ""
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
        .background(.black)
        .frame(width: isIPhone ? 680 : 700)
        .border(.gray, width: 1)
        .onAppear(){
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
                            .foregroundColor(.white)
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
        .background(.black)
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
                                    .foregroundColor(.white)
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
                .background(.black)
            }
        }
    }
}

extension CreateSfmPopup {
    private func addAction() {
        guard !projectName.isEmpty else {
            return
        }
        focusState = false
        let regex = "^(?!-).*[^.\\s]$"
        guard projectName.validateRegex(regex) && !projectName.contains("/") else {
            APAlert.shared.showAlert(title: "", message: "PROHIBITED_CHARACTER_MESSAGE".localized(userManager.userLanguage), buttonTitle: "CLOSE".localized(userManager.userLanguage))
            return
        }
        
        guard let value = value else { return }
        disableButton = true
        isPopupPresented = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.linear(duration: 0.3)) {
                show = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.disableButton = false
                }
            }
            handler(value.id, projectName,useARMarker, coordinateSetting, linkDashboard)
            projectName = ""
            searchText = ""
        }
    }
}
