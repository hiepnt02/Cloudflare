//
//  LicensePopup.swift
//  Quick3D
//
//  Created by jin.katsuragi on 2024/02/13.
//

import SwiftUI
import Alamofire

struct LicenseAlertPopup: View {
    
    @State private var bgColor = Color.black
    
    @Binding var isShow: Bool
    @EnvironmentObject var userManager: UserManager
    
    @EnvironmentObject var themeManager: ThemeManager
    @State var pointCloudBgcolor: Color
    
    private var isIPhone: Bool {
        UIDevice.current.isIphone
    }
    
    var body: some View {
        ZStack {
            Color(userManager.setting.colorTheme == .light ? .black : .white)
                .opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
        }
        
        if isIPhone {
            ScrollView(showsIndicators: false) {
                contentView
            }
            .frame(width: 581, height: 340)
        } else {
            contentView
        }
    }
    
    private var contentView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("LICENSE_ALERT".localized(userManager.userLanguage))
                    .foregroundColor(userManager.setting.textColor)
                    .font(isIPhone ? .title3.bold() : .title2.bold())
                Spacer()
                
                Button(action: {
                    self.isShow.toggle()
                }, label: {
                    Image(systemName: "xmark")
                        .foregroundColor(userManager.setting.textColor)
                })
            }
            .padding(.bottom, 10)
            
            Divider()
                .frame(height: 1)
                .background(Color.white)
                .padding(.bottom, isIPhone ? 10 : 20)
            
            HStack {
                Text("LICENSE_ALERT_CONTENT_1".localized(userManager.userLanguage))
                    .foregroundColor(userManager.setting.textColor)
                //                    .font(isIPhone ? .title3.bold() : .title2.bold())
                    .font(isIPhone ? .title3 : .title2)
            }
            .padding(.bottom, isIPhone ? 10 : 20)
            
            HStack {
                Button(
                    action: {
                        userManager.showLicenseRegister.toggle()
                    }
                ){
                    Text("LICENSE_ALERT_CONTENT_2".localized(userManager.userLanguage))
                        .frame(alignment: .center)
                        .foregroundColor(userManager.setting.textColor)
                    //                    .font(isIPhone ? .title3.bold() : .title2.bold())
                        .font(isIPhone ? .title3 : .title2)
                }
            }
            .padding(.bottom, isIPhone ? 10 : 20)
            
            HStack {
                Text("LICENSE_ALERT_CONTENT_3".localized(userManager.userLanguage))
                    .foregroundColor(userManager.setting.textColor)
                //                    .font(isIPhone ? .title3.bold() : .title2.bold())
                    .font(isIPhone ? .title3 : .title2)
            }
            .padding(.bottom, isIPhone ? 10 : 20)
            HStack(spacing: 25) {
                Button(
                    action: {
                        self.isShow.toggle()
                    },
                    label: {
                        Text("CLOSE".localized(userManager.userLanguage))
                            .frame(height: 40, alignment: .center)
                        //                            .frame(minWidth: 0, maxWidth: .infinity)
                            .frame(width: isIPhone ? 300 : 350)
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
        .padding(.horizontal, 30)
        .padding(.vertical, isIPhone ? 15 : 30)
        .frame(width: isIPhone ? 581 : 720)
        .background(userManager.setting.textColor)
        .border(.gray, width: 1)
    }
}


