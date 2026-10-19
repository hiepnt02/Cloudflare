//
//  ButtonOpenCamera.swift
//  Quick3D
//
//  Created by HungNT on 12/1/26.
//

import SwiftUI

struct ButtonOpenCamera: View {
    @EnvironmentObject var userManager: UserManager
    
    var onClick: () -> Void
    
    private let isIPhone = UIDevice.current.isIphone
    private let iconSize: CGFloat = UIDevice.current.isIphone ? 30 : 60
    private let hPadding: CGFloat = UIDevice.current.isIphone ? 8 : 16
    private let vPadding: CGFloat = UIDevice.current.isIphone ? 4 : 16
    
    var body: some View {
        Button(action: onClick) {
            HStack {
                Image("cameraButton2")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color.white)
                    .frame(width: iconSize, height: iconSize)
                    .padding(10)
                    .background(userManager.setting.buttonColor)
                    .clipShape(Circle())
            }
        }
        .buttonStyle(SquishButtonStyle())
    }
}
