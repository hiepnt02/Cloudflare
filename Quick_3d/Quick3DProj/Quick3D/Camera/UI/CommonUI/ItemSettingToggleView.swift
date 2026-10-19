//
//  ItemSettingToggleView.swift
//  Quick3D
//
//  Created by Admin on 6/1/26.
//

import SwiftUI

struct ItemSettingToggleView: View {
    @EnvironmentObject var userManager: UserManager
    
    var title: String
    var isOn: Binding<Bool>
    
    private let isIphone = UIDevice.current.isIphone
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(userManager.setting.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            CustomToggle(isOn: isOn)
        }
        .padding(isIphone ? 0 : 12)
        .frame(height: isIphone ? 35 : 70)
        .background(isIphone ? Color.clear : userManager.setting.itemBgColor)
        .cornerRadius(isIphone ? 0 : 8)
    }
}

struct CustomToggle: View {
    @EnvironmentObject var userManager: UserManager
    @Binding var isOn: Bool

    private let trackSize = CGSize(width: 34, height: 14)
    private let cornerRadius: CGFloat = 10
    private let thumbDiameter: CGFloat = 20 // radius 10

    var body: some View {
        let isDark = userManager.setting.colorTheme == .dark
        let trackColor: Color = {
            if isOn {
                return isDark ? skyBlue : sapphireBlue
            } else {
                return isDark ? grey : bombayGray
            }
        }()

        let containerHeight = max(trackSize.height, thumbDiameter)
        let horizontalInset: CGFloat = 0
        let travel = trackSize.width - thumbDiameter - 2 * horizontalInset

        ZStack(alignment: .leading) {
            // Track centered vertically
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(trackColor)
                .frame(width: trackSize.width, height: trackSize.height)

            // Thumb centered vertically, only horizontal movement
            Circle()
                .fill(Color.white)
                .frame(width: thumbDiameter, height: thumbDiameter)
                .shadow(color: Color.black.opacity(0.15), radius: 1.5, x: 0, y: 1)
                .offset(x: (isOn ? travel : 0) + horizontalInset)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                isOn.toggle()
            }
        }
        .frame(width: trackSize.width, height: containerHeight, alignment: .center)
    }
}
