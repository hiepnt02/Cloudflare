//
//  CameraAlertView.swift
//  Quick3D
//
//  Created by HungNT on 24/9/25.
//

import SwiftUI

struct CameraAlertView: View {
    
    var systemImageName: String = "exclamationmark.triangle"
    var isShowIcon: Bool = false
    
    var interval: UInt64 = 2
    var color: Color = rubyRed
    
    @Binding var message: String
    @Binding var isShow: Bool
    
    private let iconSize: CGFloat = UserSession.isIPhone ? 14 : 18
    
    var body: some View {
        if isShow {
            HStack {
                if isShowIcon {
                    Image(systemName: systemImageName)
                        .resizable()
                        .frame(width: iconSize, height: iconSize)
                        .foregroundColor(.white)
                }
                
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
            )
            .alertSound(trigger: message)
            .task {
                do {
                    try await Task.sleep(nanoseconds: interval * 1_000_000_000)
                    isShow = false
                } catch {}
            }
        } else {
            EmptyView()
        }
    }
}
