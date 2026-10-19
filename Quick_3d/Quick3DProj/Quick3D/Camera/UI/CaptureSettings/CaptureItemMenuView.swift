//
//  CaptureItemMenuView.swift
//  Quick3D
//
//  Created by HungNT on 5/1/26.
//

import SwiftUI

struct CaptureItemMenuView: View {
    @EnvironmentObject var userManager: UserManager
    @Binding var selection: CaptureMenuTypeEnum?
    
    var onSelect: (() -> Void)? = nil
    
    private var language: String {
        userManager.userLanguage
    }
    
    private let corners: UIRectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(CaptureMenuTypeEnum.allCases.enumerated()), id: \.element) { index, item in
                let isSelected = UIDevice.current.userInterfaceIdiom == .phone ? false : selection == item
                
                Button {
                    selection = item
                    onSelect?()
                } label: {
                    buttonLabel(item, isSelected: isSelected)
                        .background(isSelected ? Color.blue : userManager.setting.itemBgColor)
                        .overlay(RoundedCorner(radius: 8, corners: corners).stroke(lightGray, lineWidth: 1))
                        .clipShape(RoundedCorner(radius: 8, corners: corners))
                        //.modifier(CornerModifier(isFirst: isFirst, isLast: isLast))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, contentPadding)
    }

    private func buttonLabel(_ item: CaptureMenuTypeEnum, isSelected: Bool) -> some View {
        HStack {
            Text(item.title.localized(language))
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .white : userManager.setting.textColor)
            
            Spacer()
            
            Image("ic_arrow_down_white")
                .renderingMode(.template)
                .resizable()
                .foregroundColor(isSelected ? .white : userManager.setting.iconColor)
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(-90))
        }
        .padding(16)
    }
}

// Helper để xử lý bo góc gọn hơn
private struct CornerModifier: ViewModifier {
    let isFirst: Bool
    let isLast: Bool
    let radius: CGFloat = 8

    func body(content: Content) -> some View {
        let corners: UIRectCorner = isFirst ? [.topLeft, .topRight] : (isLast ? [.bottomLeft, .bottomRight] : [])
        
        if isFirst || isLast {
            content
                .overlay(RoundedCorner(radius: radius, corners: corners).stroke(lightGray, lineWidth: 1))
                .clipShape(RoundedCorner(radius: radius, corners: corners))
        } else {
            content
        }
    }
}
