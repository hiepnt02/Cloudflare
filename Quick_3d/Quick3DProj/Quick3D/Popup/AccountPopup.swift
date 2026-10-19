//
//  AccountPopup.swift
//  Quick3D
//
//  Created by 横内浩志 on 2022/09/09.
//

import SwiftUI

struct AccountPopup: View {
    @Binding var isShow: Bool
    @EnvironmentObject var productData: ProductData
    @EnvironmentObject var userManager: UserManager
    private var isLogin: Bool {
        return userManager.userInfo != nil
    }
    @State private var isIPhone = UIDevice.current.isIphone
    var loginHandler: () -> Void
    var logoutHandler: () -> Void
    @State private var isShowSheet = false
    @State var isShowAccountView: Bool = false
    
    var body: some View {
        
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        
        ZStack {
            if isShow {
                // PopUp background color
                Color(userManager.setting.colorTheme == .light ? .black : .white)
                    .opacity(isShow ? 0.3 : 0)
                    .edgesIgnoringSafeArea(.all) 
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("ACCOUNT_INFO".localized(userManager.userLanguage))
                            .foregroundColor(userManager.setting.textColor)
                            .font(isIPhone ? .title3.bold() : .title2.bold())
                        
                        Spacer()
                        
                        Button(action: {
                            isShow = false
                        }, label: {
                            Image(systemName: "xmark")
                                .foregroundColor(userManager.setting.textColor)
                        })
                    }
                    .padding(.top, isIPhone ? 20: 30)
                    .padding(.bottom, 10)
                    
                    Divider()
                        .frame(height: 1)
                    //                            .background(.white)
                        .foregroundColor(userManager.setting.textColor)
                        .padding(.bottom, isIPhone ? 10 : 20)
                    
                    HStack() {
                        VStack() {
                            Text("NAME".localized(userManager.userLanguage))
                            //                                    .foregroundColor(Color.init(hex: 0x5F606F))
                                .foregroundColor(userManager.setting.textColor)
                                .font(isIPhone ? .body : .title3)
                                .frame(width:  isIPhone ? 120: 170, height: isIPhone ? 32 : 42, alignment: .leading)
                            
                            Text("EMAIL".localized(userManager.userLanguage))
                            //                                    .foregroundColor(Color.init(hex: 0x5F606F))
                                .foregroundColor(userManager.setting.textColor)
                                .font(isIPhone ? .body : .title3)
                                .frame(width: isIPhone ? 120: 170, height: isIPhone ? 32 : 42, alignment: .leading)
                            
                            Text("DISCLAIMER".localized(userManager.userLanguage))
                            //                                    .foregroundColor(Color.init(hex: 0x5F606F))
                                .foregroundColor(userManager.setting.textColor)
                                .font(isIPhone ? .body : .title3)
                                .frame(width: isIPhone ? 120: 170, height: isIPhone ? 32 : 42, alignment: .leading)
                            
                            Text("ACCOUNT_MANAGEMENT".localized(userManager.userLanguage))
                            //                                    .foregroundColor(Color.init(hex: 0x5F606F))
                                .foregroundColor(userManager.setting.textColor)
                                .font(isIPhone ? .body : .title3)
                                .frame(width: isIPhone ? 120: 170, height: isIPhone ? 32 : 42, alignment: .leading)
                            
                            Text("LANGUAGE".localized(userManager.userLanguage))
                            //                                    .foregroundColor(Color.init(hex: 0x5F606F))
                                .foregroundColor(userManager.setting.textColor)
                                .font(isIPhone ? .body : .title3)
                                .frame(width: isIPhone ? 120: 170, height: isIPhone ? 32 : 42, alignment: .leading)
                            
                            Text("VERSION".localized(userManager.userLanguage))
                            //                                    .foregroundColor(Color.init(hex: 0x5F606F))
                                .foregroundColor(userManager.setting.textColor)
                                .font(isIPhone ? .body : .title3)
                                .frame(width: isIPhone ? 120: 170, height: isIPhone ? 32 : 42, alignment: .leading)
                            
                            Text("LOGOUT".localized(userManager.userLanguage))
                            //                                    .foregroundColor(Color.init(hex: 0x5F606F))
                                .foregroundColor(userManager.setting.textColor)
                                .font(isIPhone ? .body : .title3)
                                .frame(width: isIPhone ? 120: 170, height: isIPhone ? 32 : 42, alignment: .leading)
                        }
                        
                        Divider()
                        
                        VStack() {
                            Text(userManager.userInfo?.name ?? "")
                                .font(isIPhone ? .body : .title3)
                            //                                    .foregroundColor(.white)
                                .foregroundColor(userManager.setting.textColor)
                                .frame(width: isIPhone ? 230: 330, height: isIPhone ? 32 : 42, alignment: .leading)
                            
                            Text(userManager.userInfo?.email ?? "")
                                .font(isIPhone ? .body : .title3)
                            //                                    .foregroundColor(.white)
                                .foregroundColor(userManager.setting.textColor)
                                .frame(width:  isIPhone ? 230: 330, height: isIPhone ? 32 : 42, alignment: .leading)
                            
                            Button(action: {
                                isShowSheet = true
                                self.isShow.toggle()
                            }) {
                                HStack() {
                                    Text("DISCLAIMER".localized(userManager.userLanguage))
                                    Image("link")
                                        .resizable()
                                        .renderingMode(.template)
                                    //                                            .foregroundColor(.white)
                                        .foregroundColor(userManager.setting.textColor)
                                        .frame(width: isIPhone ? 22 : 32, height: isIPhone ? 22 : 32)
                                        .scaledToFit()
                                }
                            }
                            .font(isIPhone ? .body : .title3)
                            //                                    .foregroundColor(.white)
                            .foregroundColor(userManager.setting.textColor)
                            .frame(width:  isIPhone ? 230: 330, height: isIPhone ? 32 : 42, alignment: .leading)
                            .accentColor(Color("LanguageColor"))
                            
                            Button(action: {
                                self.isShowAccountView = true
                                self.isShow.toggle()
                            }) {
                                HStack() {
                                    Text("ACCOUNT_MANAGEMENT".localized(userManager.userLanguage))
                                    //                                            .foregroundColor(.white)
                                        .foregroundColor(userManager.setting.textColor)
                                    Image("link")
                                        .resizable()
                                        .renderingMode(.template)
                                    //                                            .foregroundColor(.white)
                                        .foregroundColor(userManager.setting.textColor)
                                        .frame(width: isIPhone ? 22 : 32, height: isIPhone ? 22 : 32)
                                        .scaledToFit()
                                }
                            }
                            .font(isIPhone ? .body : .title3)
                            .frame(width:  isIPhone ? 230: 330, height: isIPhone ? 32 : 42, alignment: .leading)
                            
                            Menu {
                                ForEach(LanguageMode.allCases, id: \.self) { item in
                                    Button(item.title) {
                                        userManager.userLanguage = item.rawValue
                                    }
                                }
                            } label: {
                                HStack {
                                    Text((LanguageMode(rawValue: userManager.userLanguage) ?? .en).title)
                                        .accentColor(Color("LanguageColor"))
                                        .font(isIPhone ? .body : .title3)
                                    //                                            .foregroundColor(.white)
                                        .foregroundColor(userManager.setting.textColor)
                                    
                                    Spacer()
                                    
                                    Image("arrowDown")
                                    //                                            .foregroundColor(.white)
                                        .foregroundColor(userManager.setting.textColor)
                                }
                                .frame(width: isIPhone ? 230: 330, height: isIPhone ? 32 : 42, alignment: .leading)
                            }
                            
                            Text("\(version) (\(build))")
                                .accentColor(Color("LanguageColor"))
                            //                                    .foregroundColor(.white)
                                .foregroundColor(userManager.setting.textColor)
                                .font(isIPhone ? .body : .title3)
                                .frame(width: isIPhone ? 230: 330, height: isIPhone ? 32 : 42, alignment: .leading)
                            
                            if(isLogin == true) {
                                Button(action: {   //ログアウト
                                    self.isShow.toggle()
                                    logoutHandler()
                                }) {
                                    HStack() {
                                        Text("LOGOUT".localized(userManager.userLanguage))
                                        Image("Logout")
                                            .resizable()
                                            .renderingMode(.template)
                                        //                                                .foregroundColor(.white)
                                            .foregroundColor(userManager.setting.textColor)
                                            .frame(width: isIPhone ? 22 : 32, height: isIPhone ? 22 : 32)
                                            .scaledToFit()
                                    }
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .accentColor(Color.red)
                                .font(isIPhone ? .body : .title3)
                                .frame(width: isIPhone ? 230: 330, height: isIPhone ? 32 : 42, alignment: .leading)
                            } else {
                                Button(action: {   // ログイン
                                    self.isShow.toggle()
                                    loginHandler()
                                }) {
                                    HStack() {
                                        Text("LOGIN".localized(userManager.userLanguage))
                                        Image("Login-1")
                                            .resizable()
                                            .renderingMode(.template)
                                        //                                                .foregroundColor(.white)
                                            .foregroundColor(userManager.setting.textColor)
                                            .frame(width: isIPhone ? 22 : 32, height: isIPhone ? 22 : 32)
                                            .scaledToFit()
                                    }
                                }
                                
                                .buttonStyle(BorderlessButtonStyle())
                                .accentColor(Color.blue)
                                .font(.title3)
                                .frame(width: isIPhone ? 230: 330, height: isIPhone ? 32 : 42, alignment: .leading)
                            }
                        }
                        
                    }
                }
                .padding(.horizontal, isIPhone ? 20 : 30)
                .padding(.bottom,  isIPhone ? 20 : 30)
                //                    .background(.black)
                .background(userManager.setting.themeColor)
                .frame(width: isIPhone ? 500 : 700, height: isIPhone ? nil : 500)
                .border(.gray, width: 1)
            }
        }
        .sheet(isPresented: $isShowSheet) {
            DisclaimerAlert(isShow: $isShowSheet).background(.black)
        }
        .fullScreenCover(isPresented: $isShowAccountView) {
            AccountWebView()
        }
    }
}
