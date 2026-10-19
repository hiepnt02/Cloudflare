//
//  StartView.swift
//  Quick3D
//
//  Created by jin.katsuragi on 2024/05/29.
//

import SwiftUI
import ARKit
import Introspect
import Alamofire

struct StartView: View {
    @Binding var navigateToProjectDetail: Bool
    @Binding var navigateCat: Cat?
    @Binding var isShowRenameAlert: Bool
    
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var productData: ProductData
    
    @State private var isActiveContent = false
    @State private var isShowPrivacyPolicy = false
    @State private var isShowLoginWebview = false
    
    private var isLogin: Bool {
        return userManager.userInfo != nil
    }
    
    var body: some View {
        NavigationView{
            ZStack{
                Image("login_bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                
                VStack(spacing: 0) {
                    NavigationLink(
                        destination: MainScreen(
                            navigateToProjectDetail: $navigateToProjectDetail,
                            navigateCat: $navigateCat,
                            isActiveContent: $isActiveContent,
                            isShowLoginWebview: $isShowLoginWebview,
                            isShowRenameAlert: $isShowRenameAlert
                        ),
                        isActive: $isActiveContent,
                        label: {EmptyView()}
                    )
                    
                    Image("logo_white")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 90)
                    
                    Button(action: {
                        isShowLoginWebview = true;
                    }, label: {
                        Text("LOGIN".localized(userManager.userLanguage))
                            .font(.system(size: UIDevice.current.isIphone ? 24 : 30))
                            .padding(.horizontal, 60)
                            .padding(.vertical, 20)
                            .foregroundColor( Color( UIColor(red: 37/255, green: 63/255, blue: 200/25, alpha: 1.0) ) )
                            .background(Color.white)
                            .cornerRadius(8)
                    })
                    .padding(.top, 50)
                    
                    Button(action: {
                        let urlStr = "https://www.earthbrain.com/privacy-policy/";
                        let url = NSURL(string: urlStr)
                        UIApplication.shared.open(url! as URL, options: [:], completionHandler: nil)
                    }, label: {
                        Text("PRIVACY_POLICY".localized(userManager.userLanguage))
                            .font(.system(size: UIDevice.current.isIphone ? 20 : 26))
                            .foregroundColor(Color.white)
                            .underline()
                            .accentColor(Color.blue)
                    })
                    .padding(.top,30)
                    
                    Button(action: {
                        let urlStr = "https://terms.smartconstruction.com" +
                        (userManager.userLanguage == "ja" ? "/jp/terms-of-use" : "/na/terms-of-use");
                        let url = NSURL(string: urlStr)
                        UIApplication.shared.open(url! as URL, options: [:], completionHandler: nil)
                    }, label: {
                        Text("TERMS_OF_SERVICE".localized(userManager.userLanguage))
                            .font(.system(size: UIDevice.current.isIphone ? 20 : 26))
                            .foregroundColor(Color.white)
                            .underline()
                            .accentColor(Color.blue)
                    })
                    .padding(.top, 10)
                }
            }
            .sheet(isPresented: $isShowLoginWebview) {
                // LoginWebViewの再帰を防ぐ
                LoginWebView { sessionId in
                    isShowLoginWebview = false
                    userManager.loginProcess(with: sessionId) { success in
                        if success {
                            let dispatchGroup = DispatchGroup()
                            
                            dispatchGroup.enter()
                            DispatchQueue.main.async {
                                productData.fetchJobSiteData(){
                                    print("group1")
                                    dispatchGroup.leave()
                                }
                            }
                            
                            // 各非同期関数をDispatchGroupに追加します
                            dispatchGroup.enter()
                            DispatchQueue.main.async {
                                userManager.getUserInfo {
                                    productData.initialSelectedUser()
                                    productData.fetchUsers()
                                    Task {
                                        try? await productData.fetchProjectList(
                                            status: .all,
                                            searchStr: "",
                                            fromDate: nil,
                                            toDate: Date(),
                                            site: nil,
                                            isRemoved: false,
                                            rtkFilterMode: 2
                                        )
                                        
                                        print("group2")
                                        dispatchGroup.leave()
                                    }
                                }
                            }
                            
                            dispatchGroup.enter()
                            DispatchQueue.main.async {
                                userManager.getSetting() {
                                    print("group3")
                                    dispatchGroup.leave()
                                }
                            }
                            
                            dispatchGroup.notify(queue: .main) {
                                print("All functions completed")
                                isActiveContent = true
                            }
                        } else {
                            isActiveContent = false
                        }
                    }
                }
            }
        }
        .onLoad {
            print("startView, onLoad")
            if isLogin {
                isActiveContent = true;
            }
        }
        .navigationViewStyle(.stack)
    }
}
