//
//  ShootWarningPopup.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 23/10/2022.
//

import SwiftUI

struct ShootWarningPopup: View {
    @EnvironmentObject var userManager: UserManager
    @Binding var isShow: Bool
    
    @State private var verificationReportPageIsShown = false;
    
    @State private var shootingNumberofshotsD1IsShown = false;
    
    @State private var shootingTipsD1IsShown = false;
    @State private var shootingTipsD2IsShown = false;
    @State private var shootingTipsD3IsShown = false;
    
    @State private var roverPointsD1IsShown = false;
    @State private var roverPointsD2IsShown = false;
    
    @State private var linkPointsD1IsShown = false;
    
    @State private var anyDetailIsShown = false;
    
    var didTapOKButton: (() -> Void)?
    private var isIPhone: Bool {
        UIDevice.current.isIphone
    }
    
    func hideDetails() {
        self.anyDetailIsShown = false;
        self.shootingNumberofshotsD1IsShown = false;
        self.shootingTipsD1IsShown = false;
        self.shootingTipsD2IsShown = false;
        self.shootingTipsD3IsShown = false;
        self.roverPointsD1IsShown = false;
        self.roverPointsD2IsShown = false;
        self.linkPointsD1IsShown = false;
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
                    .font(.custom(CustomFonts.FAFreeSolid, size: 15))
                    .fixedSize(horizontal: false, vertical: true)
                    .dynamicTypeSize(DynamicTypeSize.medium)
                    .frame(width: 15, height: 15)
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
            
            VStack(alignment: .leading) {
                Text("SHOOTING_POINTS".localized(userManager.userLanguage))
                    .foregroundColor(userManager.setting.textColor)
                    .font(.callout.bold())
                    .underline()
                    .fixedSize(horizontal: false, vertical: true)
                    .dynamicTypeSize(DynamicTypeSize.medium)
                    .padding(.leading, 10)
                    .padding(.bottom, 2)
                
                VStack(alignment: .leading, spacing: 1){
                    Text("1. " + "SHOOTING_POINTS_C1".localized(userManager.userLanguage))
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(userManager.setting.textColor)
                        .dynamicTypeSize(DynamicTypeSize.medium)
                    
                    Text("2. " + "SHOOTING_POINTS_C2".localized(userManager.userLanguage))
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(userManager.setting.textColor)
                        .dynamicTypeSize(DynamicTypeSize.medium)
                    
                    Text("3. " + "SHOOTING_POINTS_C3".localized(userManager.userLanguage))
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(userManager.setting.textColor)
                        .dynamicTypeSize(DynamicTypeSize.medium)
                }
                .padding(.leading, 20)
                
                HStack(alignment: .top, spacing: 1){
                    HStack{
                        Text("【" + "SHOOTING_NUMBEROFSHOTS".localized(userManager.userLanguage) + "】")
                            .font(.caption.bold())
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundColor(userManager.setting.textColor)
                            .dynamicTypeSize(DynamicTypeSize.medium)
                            .padding(.leading, 20)
                        
                        Spacer()
                        
                        customPopover(
                            isShown: $shootingNumberofshotsD1IsShown,
                            content:
                                "SHOOTING_NUMBEROFSHOTS_D1_1".localized(userManager.userLanguage) + "\n"
                            + "SHOOTING_NUMBEROFSHOTS_D1_2".localized(userManager.userLanguage) + "\n"
                            + "* " + "SHOOTING_NUMBEROFSHOTS_D1_3".localized(userManager.userLanguage),
                            frameValue: (width: 400, height: 110),
                            offsetValue: (x: 220, y: -40)
                        )
                    }
                    .frame(width: 160)
                    .zIndex(1.0)
                    
                    VStack(alignment: .leading, spacing: 1){
                        Text("・" + "SHOOTING_NUMBEROFSHOTS_C1".localized(userManager.userLanguage))
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundColor(userManager.setting.textColor)
                            .dynamicTypeSize(DynamicTypeSize.medium)
                        
                        Text("・" + "SHOOTING_NUMBEROFSHOTS_C2".localized(userManager.userLanguage))
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundColor(userManager.setting.textColor)
                            .dynamicTypeSize(DynamicTypeSize.medium)
                    }
                }
                
                HStack(alignment: .top, spacing: 1){
                    VStack(alignment: .leading, spacing: 10){
                        HStack{
                            Text("【" + "SHOOTING_TIPS".localized(userManager.userLanguage) + "】")
                                .font(.caption.bold())
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundColor(userManager.setting.textColor)
                                .dynamicTypeSize(DynamicTypeSize.medium)
                                .padding(.leading, 20)
                        }
                        
                        HStack{
                            Button(action: {
                                self.verificationReportPageIsShown.toggle()
                            }) {
                                Text("VERIFICATION_REPORT_LINK".localized(userManager.userLanguage))
                                    .font(.caption.bold())
                                    .underline()
                                    .fixedSize(horizontal: false, vertical: true)
                                    .foregroundColor(userManager.setting.textColor)
                                    .dynamicTypeSize(DynamicTypeSize.medium)
                                    .padding(.leading, 20)
                            }
                            Spacer()
                            
                            customPopover(
                                isShown: $linkPointsD1IsShown,
                                content:
                                    "ONLY_DISTRIBUTORS".localized(userManager.userLanguage) + "\n"
                                + "LIKE_TO_OBTAIN_REPORT".localized(userManager.userLanguage),
                                frameValue: (width: 400, height: 110),
                                offsetValue: (x: 220, y: -40)
                            )
                        }
                    }
                    .frame(width: 160)
                    .zIndex(linkPointsD1IsShown ? 1.0 : 0.0)
                    
                    VStack(alignment: .leading, spacing: 1){
                        Text("・" + "SHOOTING_TIPS_C1".localized(userManager.userLanguage))
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundColor(userManager.setting.textColor)
                            .dynamicTypeSize(DynamicTypeSize.medium)
                        
                        HStack{
                            Text("・" + "SHOOTING_TIPS_C2".localized(userManager.userLanguage))
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundColor(userManager.setting.textColor)
                                .dynamicTypeSize(DynamicTypeSize.medium)
                            
                            customPopover(
                                isShown: $shootingTipsD1IsShown,
                                content:
                                    "SHOOTING_TIPS_D1_1".localized(userManager.userLanguage) + "\n"
                                + "* " + "SHOOTING_TIPS_D1_2".localized(userManager.userLanguage),
                                frameValue: (width: 400, height: 110),
                                offsetValue: (x: -180, y: -70)
                            )
                        }
                        
                        HStack{
                            Text("・" + "SHOOTING_TIPS_C3".localized(userManager.userLanguage))
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundColor(userManager.setting.textColor)
                                .dynamicTypeSize(DynamicTypeSize.medium)
                            
                            customPopover(
                                isShown: $shootingTipsD2IsShown,
                                content:
                                    "SHOOTING_TIPS_D2".localized(userManager.userLanguage),
                                frameValue: (width: 400, height: 110),
                                offsetValue: (x: -180, y: -70)
                            )
                        }
                        
                        HStack{
                            Text("・" + "SHOOTING_TIPS_C4".localized(userManager.userLanguage))
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundColor(userManager.setting.textColor)
                                .dynamicTypeSize(DynamicTypeSize.medium)
                            
                            customPopover(
                                isShown: $shootingTipsD3IsShown,
                                content:
                                    "SHOOTING_TIPS_D3".localized(userManager.userLanguage),
                                frameValue: (width: 400, height: 70),
                                offsetValue: (x: -180, y: -50)
                            )
                        }
                    }
                }
                
                Text("ROVER_POINTS".localized(userManager.userLanguage))
                    .foregroundColor(userManager.setting.textColor)
                    .font(.callout.bold())
                    .underline()
                    .fixedSize(horizontal: false, vertical: true)
                    .dynamicTypeSize(DynamicTypeSize.medium)
                    .padding(.leading, 10)
                    .padding(.bottom, 2)
                
                VStack(alignment: .leading, spacing: 1){
                    Text("1. " + "ROVER_POINTS_C1".localized(userManager.userLanguage))
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(userManager.setting.textColor)
                        .dynamicTypeSize(DynamicTypeSize.medium)
                    
                    HStack{
                        Text("2. " + "ROVER_POINTS_C2".localized(userManager.userLanguage))
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundColor(userManager.setting.textColor)
                            .dynamicTypeSize(DynamicTypeSize.medium)
                        
                        Button(
                            action: {
                                hideDetails();
                                self.anyDetailIsShown = true;
                                self.roverPointsD1IsShown = true;
                            },
                            label: {
                                let questionIcon = "";
                                Text(questionIcon)
                                    .foregroundColor(userManager.setting.textColor)
                                    .font(.custom(CustomFonts.FAFreeSolid, size: 15))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .dynamicTypeSize(DynamicTypeSize.medium)
                                    .frame(width: 15, height: 15)
                                    .padding(.trailing, 20)
                            }
                        )
                        .overlay(
                            roverPointsD1IsShown ?
                            VStack(alignment: .leading, spacing: 0){
                                Image("RTK")
                                    .resizable()
                                    .scaledToFit()
                                
                                Text("ROVER_POINTS_D1_1".localized(userManager.userLanguage)
                                     + "\n"
                                     + "ROVER_POINTS_D1_2".localized(userManager.userLanguage))
                            }
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(width: 550, height: 180)
                                .padding(.all, 5)
                                .background(userManager.setting.themeColor, in: Rectangle(), fillStyle: FillStyle(eoFill: true))
                                .foregroundColor(userManager.setting.textColor)
                                .border(Color.gray, width: 1)
                                .font(.caption.bold())
                                .fixedSize(horizontal: false, vertical: true)
                                .dynamicTypeSize(DynamicTypeSize.medium)
                                .offset(x: 40, y: -110)
                                .onTapGesture{}
                            :
                                nil
                        )
                    }
                    
                    HStack{
                        Text("3. " + "ROVER_POINTS_C3".localized(userManager.userLanguage))
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundColor(userManager.setting.textColor)
                            .dynamicTypeSize(DynamicTypeSize.medium)
                        
                        customPopover(
                            isShown: $roverPointsD2IsShown,
                            content: "ROVER_POINTS_D2_1".localized(userManager.userLanguage)
                            + "\n"
                            + "ROVER_POINTS_D2_2".localized(userManager.userLanguage),
                            frameValue: (width: 400, height: 110),
                            offsetValue: (x: 0, y: -70)
                        )
                    }
                }
                .padding(.leading, 20)
                
                HStack(spacing: 25) {
                    Button(
                        action: {
                            withAnimation(.linear(duration: 0.3)) {
                                isShow = false
                            }
                        },
                        label: {
                            Text("CANCEL".localized(userManager.userLanguage))
                                .frame(height: 30, alignment: .center)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .foregroundColor(.white)
                                .background(.black.opacity(0.7))
                                .font(.title3.bold())
                                .fixedSize(horizontal: false, vertical: true)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(Color(.white), lineWidth: 1)
                                )
                                .dynamicTypeSize(DynamicTypeSize.medium)
                        }
                    )
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(
                        action: {
                            withAnimation(.linear(duration: 0.3)) {
                                isShow = false
                            }
                            didTapOKButton?()
                        },
                        label: {
                            Text("ShootWarningOK".localized(userManager.userLanguage))
                                .frame(height: 30, alignment: .center)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .font(.title3.bold())
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundColor(.white)
                                .background(userManager.setting.buttonColor)
                                .cornerRadius(2)
                                .dynamicTypeSize(DynamicTypeSize.medium)
                        }
                    )
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 10)
            }
            .sheet(isPresented: $verificationReportPageIsShown) {
                WebView(url: URL(string: "https://support-quick3d.smartconstruction.com/hc/ja/articles/18443673090457--Smart-Construction-Quick3D-%E7%82%B9%E7%BE%A4%E7%B2%BE%E5%BA%A6%E6%A4%9C%E8%A8%BC%E3%83%AC%E3%83%9D%E3%83%BC%E3%83%88")!)
            }
            .frame(width: 680, height: 360)
            .padding(.horizontal, 10)
            .background(userManager.setting.themeColor, in: Rectangle(), fillStyle: FillStyle(eoFill: true))
            .border(.gray, width: 1)
        }.onTapGesture {
            if self.anyDetailIsShown{
                hideDetails();
            }
        }
    }
    
}

