//
//  ButtonOpenCamera.swift
//  Quick3D
//
//  Created by HungNT on 12/1/26.
//

import SwiftUI

struct ButtonOpenCamera: View {
    @EnvironmentObject var userManager: UserManager
    
    @StateObject var rtkAutoConnection: RTKAutoConnection = .init()
    
    var onClick: () -> Void
    
    private let isIPhone = UIDevice.current.isIphone
    private let iconSize: CGFloat = UIDevice.current.isIphone ? 30 : 60
    private let hPadding: CGFloat = UIDevice.current.isIphone ? 8 : 16
    private let vPadding: CGFloat = UIDevice.current.isIphone ? 4 : 16
    
    private var isRTKStatus: Bool {
        rtkAutoConnection.state == .connected
    }
    
    private var rtkStatusText: String {
        if isRTKStatus {
            return "RTK"
        } else {
            return "GPS"
        }
    }
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
            //.cornerRadius(32)
        }
//        .overlay(alignment: .topTrailing) {
//            Group {
//                if rtkAutoConnection.state == .connecting {
//                    ProgressView()
//                        .progressViewStyle(.circular)
//                        .tint(.white)
//                        .scaleEffect(isIPhone ? 0.6 : 1.0)
//                        .frame(width: isIPhone ? 24 : 36, height: isIPhone ? 24 : 36)
//                        .background(Circle().fill(Color.colorJobsiteDark.opacity(0.8)))
//                        .offset(x: 12, y: isIPhone ? -8 : -14)
//                } else if !rtkStatusText.isEmpty {
//                    Text(rtkStatusText)
//                        .font(.system(size: isIPhone ? 14 : 18, weight: .bold))
//                        .foregroundColor(.white)
//                        .padding(.horizontal, isIPhone ? 4 : 8)
//                        .padding(.vertical, isIPhone ? 4 : 8)
//                        .fixedSize()
//                        .background(userManager.setting.getGpsRtkButtonColor(isRTKStatus ? 1 : 0))
//                        .cornerRadius(6)
//                        .offset(x: 18, y: isIPhone ? -8 : -14)
//                } else {
//                    EmptyView()
//                }
//            }
        }
        .buttonStyle(SquishButtonStyle())
    }
}
