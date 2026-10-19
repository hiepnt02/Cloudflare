//
//  FilterPopup.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 11/09/2022.
//

import SwiftUI
import Alamofire

struct SettingPopup: View {
    
    @State private var bgColor = Color.black
    
    @Binding var isShow: Bool
    @EnvironmentObject var userManager: UserManager
    @State private var isShowDefaultSelection = false
    @State private var isShowColorSelection = false
    @State private var isShowPointSelection = false
    
    @State private var linkTipIsShown = false;
    @State private var uploadTipIsShown = false;
    
    @State private var anyDetailIsShown = false;
    
    @EnvironmentObject var themeManager: ThemeManager
    @State var pointCloudBgcolor: Color
    
    private var isIPhone: Bool {
        UIDevice.current.isIphone
    }
    
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
            Color(userManager.setting.colorTheme == .light ? .black : .white)
                .opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    if self.anyDetailIsShown{
                        hideDetails();
                    }
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
    }
    
    private var contentView: some View {
        VStack(spacing: 0) {
            Group{
                
                HStack {
                    Text("Setting".localized(userManager.userLanguage))
                        .foregroundColor(userManager.setting.textColor)
                        .font(isIPhone ? .title3.bold() : .title2.bold())
                    Spacer()
                    Button(action: {
                        self.isShow.toggle()
                        userManager.updateSetting()
                        print(userManager.setting)
                        
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
                    Text("【" + "GENERAL".localized(userManager.userLanguage) + "】")
                        .foregroundColor(userManager.setting.textColor)
                        .font(isIPhone ? .title3.bold() : .title2.bold())
                    Spacer()
                }
                .padding(.bottom, isIPhone ? 10 : 20)
                
                //表示
                HStack {
                    Text("SHOW".localized(userManager.userLanguage))
                        .foregroundColor(userManager.setting.textColor)
                        .font(.system(size: isIPhone ? 15 : 17))
                        .padding(.leading, 10)
                    Spacer()
                }
                .padding(.bottom, isIPhone ? 7 : 10)
                
                //色
                VStack(spacing: 8) {
                    HStack {
                        Text("THEME".localized(userManager.userLanguage))
                            .foregroundColor(userManager.setting.textColor)
                            .font(.system(size: isIPhone ? 15 : 17))
                        Spacer()
                        
                        DropdownButton(
                            shouldShowDropdown: $isShowColorSelection,
                            displayText: userManager.setting.getColorThemeLabel(for: userManager.userLanguage),
                            options: [.init(key: 0, val: "light".localized(userManager.userLanguage)),
                                      .init(key: 1, val: "dark".localized(userManager.userLanguage))],
                            onTap: {
                                isShowDefaultSelection = false
                                isShowPointSelection = false
                            },
                            onSelect: { item in
                                userManager.setting.colorTheme = item.key == 0 ? .light : .dark
                                
                                isShowColorSelection = false
                                
                                if userManager.setting.colorTheme == .light && themeManager.isDarkMode {
                                    
                                } else if userManager.setting.colorTheme == .dark && !themeManager.isDarkMode{
                                    
                                    // 何もしない
                                }else{
                                    themeManager.toggleDarkMode()
                                }
                            },
                            textColor: userManager.setting.textColor
                        )
                    }
                }
                .zIndex(2)
                .padding(.horizontal, 30)
                .padding(.bottom, isIPhone ? 10 : 20)
            }
            .onTapGesture {
                if self.anyDetailIsShown{
                    hideDetails()
                }
            }
            
            // 点群色
            VStack(spacing: 8) {
                HStack {
                    ColorPicker("POINT_CLOUD_BACKGROUND_COLOR".localized(userManager.userLanguage), selection: $pointCloudBgcolor)
                        .onChange(of: pointCloudBgcolor) { newColor in
                            
                            // 選択値が変更されたときのアクション
                            // ここで新しい色を保存
                            if let hexString = pointCloudBgcolor.toHexString() {
                                //ColorをhexStringに変換して代入
                                userManager.setting.pointCloudBgcolor = hexString
                                //アルファ値の変更
                                userManager.setting.pointCloudBgalpha = Double(pointCloudBgcolor.getAlphaValue())
                            }
                        }
                }
            }
            .zIndex(1)
            .padding(.horizontal, 30)
            .padding(.bottom, isIPhone ? 10 : 20)
            
            // Email Notification setting
            HStack() {
                Text("NOTIFICATION_EMAIL_DELIVERY".localized(userManager.userLanguage))
                    .foregroundColor(userManager.setting.textColor)
                    .font(.system(size: isIPhone ? 15 : 17))
                    .padding(.leading, 10)
                
                Spacer()
                
                Toggle(isOn: $userManager.setting.notifyByEmail) {}
                    .onChange(of: userManager.setting.notifyByEmail){ checked in
                        userManager.setting.notifyByEmail = checked
                    }
                    .frame(width: 30)
                    .padding(.trailing, 30)
            }
            .padding(.bottom, isIPhone ? 10 : 20)
            
            Group{
                HStack {
                    Text("【" + "UPLOAD_SETTING_ITEMS".localized(userManager.userLanguage) + "】")
                        .foregroundColor(userManager.setting.textColor)
                        .font(isIPhone ? .title3.bold() : .title2.bold())
                    Spacer()
                }.padding(.bottom, isIPhone ? 10 : 20)
                
                HStack() {
                    Text("ALIGN_SMART_DASHBOARD".localized(userManager.userLanguage))
                        .foregroundColor(userManager.setting.textColor)
                        .font(.system(size: isIPhone ? 14 : 17))
                        .padding(.leading, 10)
                    
                    Spacer()
                    
                    customPopover(
                        isShown: $linkTipIsShown,
                        content:"DEFAULT_SETTING_EXPLANATION".localized(userManager.userLanguage),
                        frameValue: (width: 400, height: 70),
                        offsetValue: (x: -235, y: -60)
                    )
                    
                    Toggle(isOn: $userManager.setting.coordinateSetting) {}
                        .onChange(of: userManager.setting.coordinateSetting){ checked in
                            // 座標系連携がoffならDashboard連携もoff
                            if !checked {
                                userManager.setting.linkDashboard = false
                            }
                        }
                        .frame(width: 30)
                        .padding(.trailing, 30)
                }
                .padding(.bottom, isIPhone ? 7 : 10)
                .zIndex(3)
                
                HStack() {
                    Text("UPLORD_SYSTEM_SETTING".localized(userManager.userLanguage))
                        .foregroundColor(userManager.setting.textColor)
                        .font(.system(size: isIPhone ? 14 : 17))
                        .padding(.leading, 10)
                    
                    Spacer()
                    
                    customPopover(
                        isShown: $uploadTipIsShown,
                        content:"DEFAULT_SETTING_EXPLANATION".localized(userManager.userLanguage),
                        frameValue: (width: 400, height: 70),
                        offsetValue: (x: -235, y: -60)
                    )
                    
                    Toggle(isOn: $userManager.setting.linkDashboard){}
                        .onChange(of: userManager.setting.linkDashboard){ checked in
                            // Dashboard連携がonなら座標系連携もon
                            if checked {
                                userManager.setting.coordinateSetting = true
                            }
                        }
                        .frame(width: 30)
                        .padding(.trailing, 30)
                }
                .padding(.bottom, isIPhone ? 10 : 20)
                .zIndex(3)
            }
            .onTapGesture {
                if self.anyDetailIsShown{
                    hideDetails();
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, isIPhone ? 15: 30)
        .frame(width: isIPhone ? 680 : 700)
        .background(userManager.setting.themeColor)
        .border(.gray, width: 1)
    }
}
