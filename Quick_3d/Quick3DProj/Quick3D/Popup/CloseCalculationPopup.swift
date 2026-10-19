//
//  CloseCalculationPopup.swift
//  Quick3D
//
//  Created by 横内浩志 on 2022/12/17.
//

import SwiftUI

struct CloseCalculationPopup: View{
    @Binding var show: Bool
    @Binding var toggleCalculation: Bool
//    @Binding var viewerAction: ViewerAction
    
    @EnvironmentObject var userManager: UserManager
    @State private var isIPhone = UIDevice.current.isIphone

    var body: some View {
        ZStack {
            if show {
                Color(userManager.setting.colorTheme == .light ? .black : .white)
                    .opacity(show ? 0.3 : 0)
                    .edgesIgnoringSafeArea(.all)
                
                // PopUp background color
                Button(action: {}, label: {
                    Color(userManager.setting.colorTheme == .light ? .black : .white)
                        .colorInvert()
                        .opacity(0)
                        .edgesIgnoringSafeArea(.all)
                })

                // PopUp Window
                VStack(alignment: .center, spacing: 40) {
                    Text("CONFIRM_CLOSE_CALC".localized(userManager.userLanguage))
                        .foregroundColor(.white)
                        .font(.title2.bold())
                        .padding(.top, 40)

                    HStack(spacing: 20) {
                        Button(action: {
                            withAnimation(.linear(duration: 0.3)) {
                                show = false
                            }
                        }, label: {
                            Text("CANCEL".localized(userManager.userLanguage))
                                .font(isIPhone ? .headline.bold() : .title3.bold())
                                .foregroundColor(.white)
                                .frame(height: isIPhone ? 40 : 55, alignment: .center)
                                .frame(minWidth: 0, maxWidth: .infinity)
                        })
                        .background(.black.opacity(0.7))
                        .buttonStyle(PlainButtonStyle())
                        .border(.gray, width: 1)

                        Button(action: finishCalculation
                               , label: {
                            Text("END".localized(userManager.userLanguage))
                                .font(isIPhone ? .headline.bold() : .title3.bold())
                                .foregroundColor(.white)
                                .frame(height: isIPhone ? 40 : 55, alignment: .center)
                                .frame(minWidth: 0, maxWidth: .infinity)
                        })
                        .background(.blue)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, isIPhone ? 20 : 30)
                .padding(.bottom,  isIPhone ? 20 : 30)
                .background(.black)
                .frame(width: isIPhone ? 500 : 700)
                .border(.gray, width: 1)
                .ignoresSafeArea()
            }
        }
    }
}

extension CloseCalculationPopup {
    private func finishCalculation() {
        self.toggleCalculation = false
//        self.viewerAction = .endCalc
        withAnimation(.linear(duration: 0.3)) {
            show = false
        }
    }
}

