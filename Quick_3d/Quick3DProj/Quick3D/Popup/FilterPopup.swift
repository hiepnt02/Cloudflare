//
//  FilterPopup.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 11/09/2022.
//

import SwiftUI
import Alamofire

struct FilterPopup: View {
    
    @State private var searchText = ""
    @State private var isPopupPresented: Bool = false
    
    @State private var selectedWork: String?
    
    @Binding var presentedAsModal: Bool
    
    @State private var newName: String = ""
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var productData: ProductData
    
    @Binding var currentSearchStr: String
    @Binding var currentStatus: Status
    @State private var toDate: Date? = Date()
    @State private var fromDate: Date?
    @State private var site: JobSite.Site?
    @State private var isShowFromDateSelect = false
    @State private var isShowToDateSelect = false
    @State private var isKeyboardShow = false
    private var isIPhone: Bool {
        UIDevice.current.isIphone
    }
    
    var handler: (_ fromDate: Date?, _ toDate: Date?, _ site: JobSite.Site?) -> Void
    
    var filteredSites: [JobSite.Site] {
        productData.jobSite?.sites.filter { $0.name.localizedCaseInsensitiveContains(searchText) } ?? []
    }
    
    var body: some View {
        ZStack {
            if presentedAsModal {
                Color(userManager.setting.colorTheme == .light ? .black : .white)
                .opacity(0.3)
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
                .frame(maxHeight: UIScreen.main.bounds.height * (isKeyboardShow ? 0.45 : 1.0))
                .frame(height: isIPhone ? 350 : 500)
            }
        }
    }
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack{
                HStack {
                    Text("FILTER_TITLE".localized(userManager.userLanguage))
                        .foregroundColor(userManager.setting.textColor)
                        .font(isIPhone ? .title3.bold() : .title2.bold())
                        .tag(0)
                    Spacer()
                    Button(action: {
                        self.presentedAsModal.toggle()
                        isPopupPresented = false
                    }, label: {
                        Image(systemName: "xmark")
                            .foregroundColor(userManager.setting.textColor)
                    })
                    .tag(1)
                }
                .padding(EdgeInsets(top: 30, leading: 0, bottom: 10, trailing: 0))
                
                Divider()
                    .frame(height: 1)
                    .background(Color.white)
                    .padding(.bottom, 20)
                
                HStack {
                    Text("SAVED_ON".localized(userManager.userLanguage))
                        .foregroundColor(userManager.setting.textColor)
                        .font(.title3)
                        .tag(2)
                    Spacer()
                }.padding(.bottom, 10)
                
                HStack {
                    Button(action: {
                        isShowFromDateSelect.toggle()
                    }, label: {
                        Text(fromDate?.toString(format: userManager.userLanguage == LanguageMode.ja.rawValue ? Constant.jpDateFormat : Constant.otherDateFormat) ?? "")
                            .foregroundColor(userManager.setting.textColor)
                            .frame(width: 198, height: 40)
                            .background(userManager.setting.textFieldColor)
                    })
                    .frame(width: 200, height: 42)
                    .border(userManager.setting.textFieldBorderColor, width: 1)
                    .overlay {
                        if fromDate != nil {
                            Button(
                                action: { fromDate = nil }
                            ) {
                                Text("✖")
                                    .font(.system(size: 20).bold())
                                    .foregroundColor(userManager.setting.textColor)
                                    .padding(.trailing, 10)
                            }
                            .frame(width: 30, height: 30)
                            .position(x: 185, y: 22)
                        }
                    }
                    Spacer()
                    Text(" ~ ")
                        .foregroundColor(userManager.setting.textColor)
                    Spacer()
                    
                    Button(action: {
                        
                        isShowToDateSelect.toggle()
                        
                    }, label: {
                        Text(toDate?.toString(format: userManager.userLanguage == LanguageMode.ja.rawValue ? Constant.jpDateFormat : Constant.otherDateFormat) ?? "")
                            .foregroundColor(userManager.setting.textColor)
                            .frame(width: 198, height: 40)
                            .background(userManager.setting.textFieldColor)
                        
                    })
                    .frame(width: 200, height: 42)
                    .border(userManager.setting.textFieldBorderColor, width: 1)
                    .overlay {
                        if toDate != nil {
                            Button(
                                action: { toDate = nil }
                            ) {
                                Text("✖")
                                    .font(.system(size: 20).bold())
                                    .foregroundColor(userManager.setting.textColor)
                                    .padding(.trailing, 10)
                            }
                            .frame(width: 30, height: 30)
                            .position(x: 185, y: 22)
                        }
                    }
                }.padding(.bottom, 30)
                
                HStack {
                    Text("CHOOSE_PHOTOGRAPHER".localized(userManager.userLanguage))
                        .foregroundColor(userManager.setting.textColor)
                        .font(.title3)
                        .tag(3)
                    Spacer()
                    Menu {
                        ForEach(userList, id: \.self) { user in
                            Button(user.name) {
                                productData.selectedUser = user
                            }
                        }
                    } label: {
                        Text("\(productData.selectedUser?.name ?? "")")
                            .foregroundColor(userManager.setting.textColor)
                            .padding(.all, 10.0)
                            .padding(.trailing, 30)
                            .frame(width: 380, height: 42, alignment: .leading)
                    }
                    .border(.gray, width: 1)
                    .overlay {
                        if productData.selectedUser != nil {
                            Button(
                                action: { productData.selectedUser = nil }
                            ) {
                                Text("✖")
                                    .font(.system(size: 20).bold())
                                    .foregroundColor(userManager.setting.textColor)
                            }
                            .frame(width: 40, height: 40)
                            .position(x: 360, y: 20)
                        } else {
                            Image("arrowDown")
                                .renderingMode(.template)
                                .foregroundColor(userManager.setting.textColor)
                                .allowsHitTesting(false)
                                .position(x: 360, y: 20)
                        }
                    }
                }
                .padding(.bottom, 15)
                // MARK: 検索プルダウン
                ZStack(){
                    HStack {
                        Text("JOBSITE_NAME".localized(userManager.userLanguage))
                            .foregroundColor(userManager.setting.textColor)
                            .font(.title3)
                            .tag(4)
                            .offset(y: -15) // 適切な値を試してください
                        
                        Spacer()
                        
                        TextField("", text: $searchText)
                            .frame(width: 370, height: 42, alignment: .leading)
                            .padding(.leading, 10)
                            .border(Color.gray, width: 1)
                            .padding(.bottom, 30)
                            .foregroundColor(userManager.setting.textColor)
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
                                    .frame(width: 380, alignment: .leading)
                                    .border(Color.gray, width: 1)
                                    .position(x: 190, y: isIPhone ? -40 + (searchText.isEmpty ? 0 : filteredSites.count > 1 ? 0 : 20) : -80 + (searchText.isEmpty ? 0 : filteredSites.count > 1 ? 40 : 60))
                                : nil
                            )
                            .overlay {
                                if site != nil {
                                    Button(
                                        action: {
                                            site = nil
                                            searchText = ""
                                            isPopupPresented = false
                                            
                                        }
                                    ) {
                                        Text("✖")
                                            .font(.system(size: 20).bold())
                                            .foregroundColor(userManager.setting.textColor)
                                    }
                                    .frame(width: 40, height: 40)
                                    .position(x: 360, y: 20)
                                } else {
                                    Image("arrowDown")
                                        .renderingMode(.template)
                                        .foregroundColor(userManager.setting.textColor)
                                        .allowsHitTesting(false)
                                        .position(x: 360, y: 20)
                                }
                            }
                    }
                    .padding(.bottom, 15)
                }
                
                HStack(spacing: 25) {
                    Button(
                        action: { self.presentedAsModal.toggle()
                            isPopupPresented = false
                        },
                        label: {
                            Text("CANCEL".localized(userManager.userLanguage))
                                .frame(height: 40, alignment: .center)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .foregroundColor(.white)
                                .background(.black.opacity(0.7))
                                .font(.footnote.bold())
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(Color(.white), lineWidth: 1)
                                )
                        }
                    )
                    .buttonStyle(PlainButtonStyle())
                    .tag(5)
                    
                    Button(
                        action: search,
                        label: {
                            Text("SEARCH".localized(userManager.userLanguage))
                                .frame(height: 40, alignment: .center)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .font(.footnote.bold())
                                .foregroundColor(.white)
                                .background(.blue)
                                .cornerRadius(2)
                        }
                    )
                    .buttonStyle(PlainButtonStyle())
                    .tag(6)
                }
            }
            .frame(width: isIPhone ? 500 : 700)
            .padding(.horizontal, 30)
            .padding(.bottom,  isIPhone ? 20 : 30)
            .background(userManager.setting.themeColor)
            .border(.gray, width: 1)
            
            .overlay(
                isShowFromDateSelect ?
                ZStack {
                    userManager.setting.textColor.opacity(0.01)
                        .ignoresSafeArea(.all)
                        .frame(width: isIPhone ? 300 : 350)
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture {
                        isShowFromDateSelect = false
                    }
                : nil
            )
            
            .overlay(
                isShowToDateSelect ?
                ZStack {
                    userManager.setting.textColor.opacity(0.01)
                        .ignoresSafeArea(.all)
                        .frame(width: isIPhone ? 300 : 350)
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture {
                        isShowToDateSelect = false
                    }
                : nil
            )
        }
        .onAppear {
            self.productData.fetchJobSiteData()
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
                                self.site = site
                                isPopupPresented = false
                                searchText = site.name
                            }
                            .frame(width: 370, alignment: .leading)//iPad
                            .padding(10)
                        
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.gray)
                            .frame(width: 370, alignment: .leading)//iPad
                    }
                }
            }
        }
        .background(userManager.setting.themeColor)
        .frame(height: isIPhone ? 80 : 160)
    }
    
    // MARK: 検索フィールドで検索された時の画面
    func filteredSiteScrollView() -> some View {
        let filteredSites = productData.jobSite?.sites.filter { $0.name.localizedCaseInsensitiveContains(searchText) } ?? []
        
        return Group {
            if filteredSites.isEmpty {
                // 検索に一致するサイトがない場合の表示
                Color.clear
                    .frame(height: 0)
                
            } else {
                // 検索に一致するサイトがある場合の表示
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredSites, id: \.self) { site in
                            VStack(spacing: 0) {
                                Text(site.name)
                                    .foregroundColor(userManager.setting.textColor)
                                    .onTapGesture {
                                        self.site = site
                                        isPopupPresented = false
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        searchText = site.name
                                    }
                                    .frame(width: 370, alignment: .leading)
                                    .frame(width: isIPhone ? nil : 370, alignment: .leading)
                                    .padding(10)
                                
                                if filteredSites.count > 1 {
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(Color.gray)
                                        .frame(width: 370, alignment: .leading)
                                }
                            }
                        }
                    }
                }
                .frame(height: filteredSites.count > 1 ? 80 : 40)
                .background(userManager.setting.themeColor)
            }
        }
    }
    
    // キーボードの高さを取得する
    private func getKeyboardHeight() -> CGFloat {
        let keyboardWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        return ((keyboardWindow?.frame.height)! - 100 )
    }
    
    private var userList: [User] {
        var initialList: [User] = [.init(name: "ALL".localized(userManager.userLanguage))]
        if let filterUser = productData.userList.first(where: { $0.userId == userManager.userInfo?.userId }) {
            initialList.append(.init(userId: userManager.userInfo?.userId, name: filterUser.name))
        }
        
        var list = productData.userList
        list.removeAll(where: { $0.userId == userManager.userInfo?.userId })
        list.removeAll(where: { $0.name.isEmpty })
        initialList.append(contentsOf: list)
        initialList = initialList.reversed()
        return initialList
    }
}


extension FilterPopup {
    private func search() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.linear(duration: 0.3)) {
                presentedAsModal = false
                isPopupPresented = false
            }
            handler(fromDate, toDate, site)
        }
    }
}

