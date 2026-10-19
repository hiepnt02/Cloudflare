//
//  ConfirmDeletePopup.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 02/06/2022.
//

import SwiftUI

struct ConfirmDeletePopup: View{
    @Binding var show: Bool
    let alertMessage: String
    var handler: () -> Void
    @EnvironmentObject var userManager: UserManager
    @State private var isIPhone = UIDevice.current.isIphone
    
    var body: some View {
        ZStack {
            if show {
                // PopUp background color
                Button(action: {}, label: {
                    Color(userManager.setting.colorTheme == .light ? .black : .white)
                        .colorInvert()
                        .opacity(0)
                        .edgesIgnoringSafeArea(.all)
                })
                
                Color(userManager.setting.colorTheme == .light ? .black : .white)
                    .colorInvert()
                    .opacity(show ? 0.3 : 0)
                    .edgesIgnoringSafeArea(.all)
                
                // PopUp Window
                VStack(alignment: .center, spacing: 0) {
                    HStack() {
                        Text("REMOVE".localized(userManager.userLanguage))
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
                    .padding(.top, isIPhone ? 20: 30)
                    .padding(.bottom, 10)
                    
                    Divider()
                        .frame(height: 2)
                        .background(.white)
                        .padding(.bottom, isIPhone ? 10 : 20)
                    
                    Text(alertMessage)
                        .foregroundColor(userManager.setting.textColor)
                        .frame(height: 30)
                        .font(.title2)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 0))
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            withAnimation(.linear(duration: 0.3)) {
                                show = false
                            }
                        }, label: {
                            Text("CANCEL".localized(userManager.userLanguage))
                                .font(isIPhone ? .headline.bold() : .title3.bold())
                                .frame(height: isIPhone ? 40 : 55, alignment: .center)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .contentShape(Rectangle())
                        })
                        .buttonStyle(PlainButtonStyle())
                        .border(.gray, width: 1)
                        
                        Button(action: confirmAction
                               , label: {
                            Text("REMOVE".localized(userManager.userLanguage))
                                .font(isIPhone ? .headline.bold() : .title3.bold())
                                .foregroundColor(.white)
                                .frame(height: isIPhone ? 40 : 55, alignment: .center)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .contentShape(Rectangle())
                        })
                        .background(userManager.setting.deleteButtonColor)
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.bottom, isIPhone ? 20 : 30)
                }
                .padding(.horizontal, isIPhone ? 20 : 30)
                .padding(.bottom,  isIPhone ? 20 : 30)
                .background(userManager.setting.themeColor)
                .frame(width: isIPhone ? 500 : 700)
                .border(.gray, width: 1)
                .ignoresSafeArea()
            }
        }
    }
}

extension ConfirmDeletePopup {
    private func confirmAction() {
        withAnimation(.linear(duration: 0.3)) {
            show = false
        }
        handler()
    }
}
