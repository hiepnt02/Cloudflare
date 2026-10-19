//
//  LoginView.swift
//  Quick3D
//
//  Created by 木皿直規 on 2022/04/17
import SwiftUI

//-------------------------------------------------
// LoginAlert ログイン画面
//-------------------------------------------------
struct LoginAlert: View {
    @Binding var isShow: Bool
    
    @EnvironmentObject var userManager: UserManager
    var loginHandler: () -> Void
    var logoutHandler: () -> Void
    private var isLogin: Bool {
        return userManager.userInfo != nil
    }
    
    @State var langID = 0
    @State var isShowDisclaimerAlert: Bool = false
    @State private var isShowSheet = false
    @State private var isIPhone: Bool = (UIDevice.current.userInterfaceIdiom == .phone) ? true : false

    var body: some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String

        ZStack() {
            Rectangle()
                .foregroundColor(Color.white)
       
            Form {
                if(isLogin == false) {
                    Button("Login") {   // ログイン
                        self.isShow.toggle()
                        loginHandler()
                    }
                        .accentColor(Color.blue)
                }
                
                if(isLogin == true) {
                    Button(action: {
                    }, label: {
                        HStack() {
                            Text("Email")
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
                
                Button("Manual") {  // ドキュメンテーション
                }
                    .accentColor(Color("LanguageColor"))
                
                
                Button("Disclaimer") {      //　免責事項
                            isShowSheet = true
                        }
                            .accentColor(Color("LanguageColor"))
                            .sheet(isPresented: $isShowSheet) {
                                DisclaimerAlert(isShow: $isShowSheet)
                            }

                Button(action: {
                 }) {
                    HStack() {
                        Text("LANGUAGE")    // 言語
                            .accentColor(Color("LanguageColor"))
                            .contextMenu {
                                Button(action: {
                                    langID = 0
                                    UserDefaults.standard.set(LanguageMode.ja.rawValue, forKey: "languageKey")     //ja:日本語
                                }) {
                                    Text("日本語").accentColor(Color("LanguageColor"))
                                }
                                
                                Button(action: {
                                    langID = 1
                                    UserDefaults.standard.set(LanguageMode.en.rawValue, forKey: "languageKey")     // en:英語
                                }) {
                                    Text("English").accentColor(Color("LanguageColor"))
                                }
                                
                                Button(action: {
                                    langID = 2
                                    UserDefaults.standard.set(LanguageMode.fr.rawValue, forKey: "languageKey")     // fr:フランス語
                                }) {
                                    Text("Français").accentColor(Color("LanguageColor"))
                                }
                                
                                Button(action: {
                                    langID = 3
                                    UserDefaults.standard.set(LanguageMode.de.rawValue, forKey: "languageKey")     //de:ドイツ語
                                }) {
                                    Text("Deutsch").accentColor(Color("LanguageColor"))
                                }
                                
                                Button(action: {
                                    langID = 4
                                    UserDefaults.standard.set(LanguageMode.cs.rawValue, forKey: "languageKey")     //cz:チェコ語
                                }) {
                                    Text("český jazyk").accentColor(Color("LanguageColor"))
                                }
                            }
                        Spacer()
                        
                        switch langID {
                        case 0: Text("日本語").accentColor(Color("LanguageColor"))
                        case 1: Text("English").accentColor(Color("LanguageColor"))
                        case 2: Text("Français").accentColor(Color("LanguageColor"))
                        case 3: Text("Deutsch").accentColor(Color("LanguageColor"))
                        case 4: Text("český jazyk").accentColor(Color("LanguageColor"))
                        default: Text("日本語").accentColor(Color("LanguageColor"))
                        }
                    }
                }
                
                Button(action: {
                }) {
                    HStack() {
                        Text("Version") // バージョン
                            .accentColor(Color("LanguageColor"))
                        Spacer()
                        Text("\(version) (\(build))")
                            .accentColor(Color("LanguageColor"))
                    }
                }
                
                if(isLogin == true) {
                    Button("Logout") {   //ログアウト
                        self.isShow.toggle()
                        logoutHandler()
                    }
                    .accentColor(Color.red)
                }
            }

            Button(action: {
                self.isShow.toggle()
            } ) {
                Image("closeOutline")  // 戻るボタン
                    .resizable()
                    .frame(width: 30, height: 30)
            }
                .offset(x: 240, y: -183)
        }
//        .frame(width: isLogin ? userManager.userInfo!.emailWidth + 140 : 400, height: isLogin ? 350 : 350)
//        .frame(width: isIPhone ? 500 : 500, height: isIPhone ? 320 : 320)
//        .cornerRadius(20)
//        .shadow(radius: 20)
        /*
            .onAppear {
                if isIPhone == false {
                    UITableView.appearance().isScrollEnabled = false
                }
            }
        */
            .offset(x: isIPhone ? 0 : 0, y: isIPhone ? 50 : 50)

    }
}

/*
 struct LoginAlert_Previews: PreviewProvider {
 let str = "abc@xyz.com"
 
 static var previews: some View {
 LoginAlert(isShow: .constant(0 != 0), idString: $str)
 .previewDevice("iPad Pro (11-inch)")
 .previewInterfaceOrientation(.landscapeRight)
 }
 }
 */


