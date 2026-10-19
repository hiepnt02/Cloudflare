//
//  InsufficientPhotoPopup.swift
//  Quick3D
//
//  Created by ryoma.terai on 2024/10/30.
//

import SwiftUI
import Alamofire

struct InsufficientPhotoPopup: View {
    @ObservedObject var uploadProject: UploadProject
    @EnvironmentObject var userManager: UserManager
    @State private var isIPhone = UIDevice.current.isIphone
    
    var body: some View {
        ZStack {
            if uploadProject.isInsufficientPhoto {
                Color(userManager.setting.colorTheme == .light ? .black : .white)
                    .opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView(showsIndicators: false) {
                    contentView.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) {_ in
                    }.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) {_ in
                    }
                }
                .frame(maxHeight: UIScreen.main.bounds.height)
                .frame(height: isIPhone ? 350 : 350)
            }
        }
    }
    
    private var contentView: some View {
            ZStack() {
                VStack(spacing: 0) {
                    HStack {
                        Text("UPLOAD_ERROR".localized(userManager.userLanguage))
                            .foregroundColor(userManager.setting.textColor)
                            .font(.title2.bold())
                        Spacer()
                        Button(action: {
                            uploadProject.isInsufficientPhoto = false;
                        }, label: {
                            Image(systemName: "xmark")
                                .foregroundColor(userManager.setting.textColor)
                        })
                    }.padding(EdgeInsets(top: 30, leading: 0, bottom: 10, trailing: 0))

                    Divider()
                        .frame(height: 1)
                        .background(userManager.setting.textColor)
                        .padding(.bottom, 20)
                    HStack(spacing: 0) {
                        Image("attention")
                            .renderingMode(.template)
                            .resizable()
                            .foregroundColor(.red)
                            .frame(width: 15, height: 15)
                        Text("INSUFFICIENT_PHOTOS_NUMBER".localized(userManager.userLanguage))
                            .foregroundColor(userManager.setting.textColor)
                    }
                    Text("TAKE_TEN_MORE_PICTURE".localized(userManager.userLanguage))
                        .foregroundColor(userManager.setting.textColor)
                        .padding(.bottom, 30)

                    HStack(spacing: 25) {
                        Button(
                            action: {
                               uploadProject.isInsufficientPhoto = false;
                            },
                            label: {
                                Text("COMFIRM".localized(userManager.userLanguage))
                                    .frame(height: 40, alignment: .center)
                                    .frame(width: 200)
                                    .foregroundColor(.white)
                                    .font(.footnote.bold())
                                    .background(userManager.setting.buttonColor)
                            }
                        )
                        .buttonStyle(PlainButtonStyle())

                    }.padding(.bottom, 30)
                }
            }
            .frame(width: isIPhone ? 500 : 700)
            .padding(.horizontal, isIPhone ? 20 : 30)
            .background(userManager.setting.themeColor)
            .border(.gray, width: 1)
        }
}

extension InsufficientPhotoPopup {

}
