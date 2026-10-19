//
//  UploadResultView.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 13/05/2022.
//

import SwiftUI

struct UploadingResultView: View {
    @Binding var show: Bool
    @Binding var success: Bool
    @Binding var messsage: String
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
                    Text(messsage)
                        .foregroundColor(.green)
                        .font(.title2)
                        .padding(EdgeInsets(top: 20, leading: 10, bottom: 20, trailing: 10))
                }
                .frame(maxWidth: 500)
                .background(.black.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 15))
            }
        }
    }
}
