//
//  ExportSuccessPopup.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 09/11/2022.
//

import SwiftUI

struct ExportSuccessPopup: View {
    @EnvironmentObject var userManager: UserManager
    @Binding var isShow: Bool
    
    private var isIPhone: Bool {
        UIDevice.current.isIphone
    }

    var body: some View {
        ZStack() {
            // PopUp background color
//            Color(.white)
//                .opacity(0.3)
//                .edgesIgnoringSafeArea(.all)
//            
            Color(userManager.setting.colorTheme == .light ? .black : .white)
                .opacity(0.3)
                .edgesIgnoringSafeArea(.all)

            VStack(alignment: .center, spacing: 0) {
                HStack {
                    Text("ExportCompleteTitle".localized(userManager.userLanguage))
                        .foregroundColor(.white)
                        .font(.title2.bold())

                    Spacer()

                    Button(action: {
                        withAnimation(.linear(duration: 0.3)) {
                            isShow = false
                        }
                    }, label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    })
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 10)

                Divider()
                    .frame(height: 1)
                    .background(Color.white)
                    .padding(.bottom, 20)

                Text("ExportCompleteMessage".localized(userManager.userLanguage))
                    .font(.body.bold())
                    .foregroundColor(.white)
                    .padding(.bottom, 30)

                Button(
                    action: {
                        withAnimation(.linear(duration: 0.3)) {
                            isShow = false
                        }
                    },
                    label: {
                        Text("OK")
                            .frame(height: 40, alignment: .center)
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .font(.body.bold())
                            .foregroundColor(.white)
                            .background(.blue)
                            .cornerRadius(2)
                    }
                )
                .buttonStyle(PlainButtonStyle())
                .frame(width: 250)
                .padding(.bottom, 30)
            }
            .padding(.horizontal, isIPhone ? 20 : 30)
            .background(.black)
            .frame(width: 500)
            .border(.gray, width: 1)
        }
    }
}
