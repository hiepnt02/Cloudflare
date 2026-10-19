//
//  UploadingView.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 13/05/2022.
//

import SwiftUI

struct UploadingView: View{
    @Binding var show: Bool
    @Binding var progress: Double
    @EnvironmentObject var userManager: UserManager
    
    var body: some View {
        ZStack {
            if show {
                // PopUp background color
                Color(userManager.setting.colorTheme == .light ? .black : .white)
                    .colorInvert()
                    .opacity(show ? 0.3 : 0)
                    .edgesIgnoringSafeArea(.all)
                
                // PopUp Window
                VStack(alignment: .center, spacing: 0) {
                    HStack() {
                        Text("UPLOADING".localized(userManager.userLanguage))
                            .foregroundColor(.white)
                            .frame(height: 30, alignment: .leading)
                            .font(.title2)
                        
                        Spacer()
                        
                        Text("\(Int(progress*100))%")
                            .foregroundColor(.white)
                            .frame(height: 30, alignment: .trailing)
                            .font(.title2)
                    }
                    .padding(EdgeInsets(top: 20, leading: 25, bottom: 0, trailing: 25))
                    
                    
                    ProgressView("", value: progress, total: 1)
                        .padding(EdgeInsets(top: 0, leading: 25, bottom: 20, trailing: 25))
                }
                .frame(width: 500)
                .background(.black.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}
