//
//  LoginSheet.swift
//  Quick3D
//
//  Created by 木皿直規 on 2022/05/15.
//

import SwiftUI

struct LoginSheet: View {
    @Binding var isShow: Bool
    @EnvironmentObject var userManager: UserManager
    var loginHandler: () -> Void
    var logoutHandler: () -> Void
    private var isLogin: Bool {
        return userManager.userInfo != nil
    }

    @State var isShowDisclaimerAlert: Bool = false
    @State private var isShowSheet = false
    @State private var isIPhone: Bool = (UIDevice.current.userInterfaceIdiom == .phone) ? true : false

    var body: some View {

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String

        ZStack() {
            Rectangle()
                .foregroundColor(Color("TextBackgroundColor"))
                .border(Color.white, width: 3)

            VStack () {
                if(isIPhone == true) {
                    HStack {
                        Spacer()

                        Button(action: {
                            self.isShow.toggle()
                        } ) {
                            Image("closeOutline")  // 戻るボタン
                                .resizable()
                                .frame(width: 30, height: 30)
                        }
                    }
                    
                    Spacer()
                }
                
                Form {
                    if(isLogin == false) {
                        Button("LOGIN".localized(userManager.userLanguage)) {   // ログイン
                            self.isShow.toggle()
                            loginHandler()
                        }
                            .buttonStyle(BorderlessButtonStyle())
                            .accentColor(Color.blue)
                    }
                    
                    if(isLogin == true) {
                        Button(action: {
                        }, label: {
                            HStack() {
                                Text("Email".localized(userManager.userLanguage))
                                    .frame(height: 40, alignment: .center)
                                    .font(.system(size: 19))
                                    .accentColor(Color("LanguageColor"))
                                
                                Spacer()

                                Text(userManager.userInfo?.email ?? "")
                                    .frame(height: 40, alignment: .center)
                                    .font(.system(size: 19))
                                    .accentColor(Color("LanguageColor"))
                            }
                            
                        })
                    }
                    
                    Button("Manual".localized(userManager.userLanguage)) {  // ドキュメンテーション
                    }
                        .accentColor(Color("LanguageColor"))
                    
                    
                    Button("DISCLAIMER".localized(userManager.userLanguage)) {      //　免責事項
                                isShowSheet = true
                            }
                                .accentColor(Color("LanguageColor"))
                                .sheet(isPresented: $isShowSheet) {
                                    DisclaimerAlert(isShow: $isShowSheet)
                                }

                    Button(action: {
                     }) {
                        HStack() {
                            Text("LANGUAGE".localized(userManager.userLanguage))    // 言語
                                .accentColor(Color("LanguageColor"))
                                .contextMenu {
                                    Button(action: {
                                        userManager.userLanguage = LanguageMode.ja.rawValue
                                    }) {
                                        Text("日本語").accentColor(Color("LanguageColor"))
                                    }
                                    
                                    Button(action: {
                                        userManager.userLanguage = LanguageMode.en.rawValue
                                    }) {
                                        Text("English").accentColor(Color("LanguageColor"))
                                    }
                                    
                                    Button(action: {
                                        userManager.userLanguage = LanguageMode.fr.rawValue
                                    }) {
                                        Text("Français").accentColor(Color("LanguageColor"))
                                    }
                                    
                                    Button(action: {
                                        userManager.userLanguage = LanguageMode.de.rawValue
                                    }) {
                                        Text("Deutsch").accentColor(Color("LanguageColor"))
                                    }
                                    
                                    Button(action: {
                                        userManager.userLanguage = LanguageMode.cs.rawValue
                                    }) {
                                        Text("český jazyk").accentColor(Color("LanguageColor"))
                                    }
                                }
                            Spacer()
                            
                            switch userManager.userLanguage {
                            case LanguageMode.ja.rawValue: Text("日本語").accentColor(Color("LanguageColor"))
                            case LanguageMode.en.rawValue: Text("English").accentColor(Color("LanguageColor"))
                            case LanguageMode.fr.rawValue: Text("Français").accentColor(Color("LanguageColor"))
                            case LanguageMode.de.rawValue: Text("Deutsch").accentColor(Color("LanguageColor"))
                            case LanguageMode.cs.rawValue: Text("český jazyk").accentColor(Color("LanguageColor"))
                            default: Text("日本語").accentColor(Color("LanguageColor"))
                            }
                        }
                    }
                    
                    Button(action: {
                    }) {
                        HStack() {
                            Text("VERSION".localized(userManager.userLanguage)) // バージョン
                                .accentColor(Color("LanguageColor"))
                            Spacer()
                            Text("\(version) (\(build))")
                                .accentColor(Color("LanguageColor"))
                        }
                    }
                    
                    if(isLogin == true) {
                        Button("LOGOUT".localized(userManager.userLanguage)) {   //ログアウト
                            self.isShow.toggle()
                            logoutHandler()
                        }
                            .buttonStyle(BorderlessButtonStyle())
                            .accentColor(Color.red)
                    }
                }
            }
                .padding()
        }
            .cornerRadius(20)
            .shadow(radius: 20)
    }}
