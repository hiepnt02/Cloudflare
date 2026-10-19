//
//  ProjectDetailTransitionPopup.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 31/08/2022.
//

import SwiftUI

struct ProjectDetailTransitionPopup: View {
    var handler: () -> Void
    @Binding var show: Bool
    @Binding var projectName: String
    @EnvironmentObject var userManager: UserManager
    @State private var isIPhone: Bool = (UIDevice.current.userInterfaceIdiom == .phone) ? true : false

    var body: some View {
        ZStack {
            if show {
                // PopUp background color
                if (userManager.setting.colorTheme == .light){
                    Color.black
                        .opacity(show ? 0.3 : 0)
                    
                }else{
                    Color.white
                        .opacity(show ? 0.3 : 0)
                    
                }
                
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
                        .frame(height: 2)
                        .background(Color.white)
                        .padding(.bottom, 20)

                    Text(String(format: "SAVE_COMPLETED".localized(userManager.userLanguage), projectName))
                        .foregroundColor(userManager.setting.textColor)
                        .font(.body)
                        .padding(.bottom, 30)

                    HStack(spacing: 25) {
                        Button(action: {
                            show = false
                        }
                               , label: {
                            Text("CLOSE".localized(userManager.userLanguage))
                                .frame(height: 40, alignment: .center)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .foregroundColor(.white)
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
                            Text("CONTINUE_SFM".localized(userManager.userLanguage))
                                .frame(height: 40, alignment: .center)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .font(.footnote.bold())
                                .foregroundColor(.white)
                                .background(.blue)
                                .cornerRadius(2)
                        })
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 30)
                .frame(width: isIPhone ? 500:700)
                .background(userManager.setting.themeColor)
                .border(.gray, width: 1)
            }
        }
    }
}

private extension ProjectDetailTransitionPopup {
    func addAction() {

        handler()
        // Dismiss the PopUp
        withAnimation(.linear(duration: 0.3)) {
            show = false
        }
    }
}
