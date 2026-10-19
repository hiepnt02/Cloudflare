//
//  ARAccuracyTipsView.swift
//  Quick3D
//
//  Created by Admin on 18/11/25.
//

import SwiftUI

struct ARAccuracyTipsView: View {
    @EnvironmentObject var userManager: UserManager

    @Binding var isPresented: Bool
    
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 0) {

            Text("AR_ACCURACY_HEADER".localized(userManager.userLanguage))
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.top, 16)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("AR_ACCURACY_1".localized(userManager.userLanguage))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(userManager.setting.textColor)
                    .dynamicTypeSize(DynamicTypeSize.medium)
                    .padding(.top, 8)
                
                Text("AR_ACCURACY_2".localized(userManager.userLanguage))
                    .font(.body)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(userManager.setting.textColor)
                    .dynamicTypeSize(DynamicTypeSize.medium)
                
                Text("AR_ACCURACY_3".localized(userManager.userLanguage))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(userManager.setting.textColor)
                    .dynamicTypeSize(DynamicTypeSize.medium)
            }
            .padding([.horizontal, .bottom], 20)
            
            Divider()

            Text("OK")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(isPressed ? Color.gray.opacity(0.2) : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    isPresented = false
                }
                .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = pressing
                    }
                }, perform: {})
        }
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
                .shadow(radius: 10)
        )
        .padding(32)
    }
}
