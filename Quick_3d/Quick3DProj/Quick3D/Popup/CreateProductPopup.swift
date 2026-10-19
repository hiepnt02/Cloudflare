//
//  CreateProductPopup.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 16/04/2022.
//

import SwiftUI

struct CreateProductPopup: View {
    var handler: (String) -> Void
    @Binding var show: Bool
    @State private var projectName: String = ""
    @EnvironmentObject var userManager: UserManager
    @FocusState private var focusState: Bool
    @State private var isIPhone: Bool = (UIDevice.current.userInterfaceIdiom == .phone) ? true : false
    
    var body: some View {
        ZStack {
            if show {
                // PopUp background color
                Color(userManager.setting.colorTheme == .light ? .black : .white)
                    .colorInvert()
                    .opacity(show ? 0.3 : 0)
                    .edgesIgnoringSafeArea(.all)
                    
                
                // PopUp Window
                VStack(spacing: 0) {
                    HStack {
                        Text("SAVE_PROJECT_NAME".localized(userManager.userLanguage))
                            .foregroundColor(userManager.setting.textColor)
                            .font(.title2.bold())

                        Spacer()

                        Button(action: {
                            show = false
                        }, label: {
                            Image(systemName: "xmark")
                                .foregroundColor(userManager.setting.textColor)
                        })
                    }
                    .padding(EdgeInsets(top: 30, leading: 0, bottom: 10, trailing: 0))

                    Divider()
                        .frame(height: 1)
//                        .background(Color.white)
                        .background(userManager.setting.textColor)
                        .padding(.bottom, 20)
                    
                    TextField("PROJECT_NAME".localized(userManager.userLanguage), text: $projectName)
//                        .foregroundColor(.white)
                        .foregroundColor(userManager.setting.textColor)
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
                    
                    HStack(spacing: 25) {
                        Button(action: {
                            show = false
                        }
                               , label: {
                            Text("CANCEL".localized(userManager.userLanguage))
                                .frame(height: 40, alignment: .center)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .foregroundColor(.white)
//                                .foregroundColor(userManager.userSetting.getTextColor())
                                .background(.black.opacity(0.7))
                                .font(.footnote.bold())
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(Color(.white), lineWidth: 1)
                                )
                        })
                        .buttonStyle(PlainButtonStyle())

                        Button(action: addAction
                               , label: {
                            Text("SAVE".localized(userManager.userLanguage))
                                .frame(height: 40, alignment: .center)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .font(.footnote.bold())
                                .foregroundColor(.white)
//                                .background(.blue)
                                .background(userManager.setting.buttonColor)
                                .cornerRadius(2)
                        })
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 30)
                .frame(width: isIPhone ? 500:700)
//                .background(.black)
                .background(userManager.setting.themeColor)
                .border(.gray, width: 1)
                .onAppear {
                    projectName = ""
                }
            }
        }
    }
}

private extension CreateProductPopup {
    func addAction() {
        guard !projectName.isEmpty else {
            return
        }
        focusState = false
        guard ProductUtil.validationCheck(projectName) else {
            APAlert.shared.showAlert(title: "", message: "PROHIBITED_CHARACTER_MESSAGE".localized(userManager.userLanguage), buttonTitle: "CLOSE".localized(userManager.userLanguage))
            return
        }

        handler(projectName)
        projectName = ""

        // Dismiss the PopUp
        withAnimation(.linear(duration: 0.3)) {
            show = false
        }
    }
}
