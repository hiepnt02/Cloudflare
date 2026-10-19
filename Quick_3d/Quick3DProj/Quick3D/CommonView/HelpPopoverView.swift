//
//  HelpPopoverView.swift
//  Quick3D
//
//  Created by HungNT on 18/6/26.
//

import SwiftUI

import SwiftUI

class PopoverManager: ObservableObject {
    @Published var activePopoverID: String? = nil
    @Published var anchorFrame: CGRect = .zero // Save the coordinates of the icon button
    
    func toggle(id: String) {
        if activePopoverID == id {
            activePopoverID = nil
        } else {
            activePopoverID = id
        }
    }
    
    func toggle(id: String, frame: CGRect) {
        if activePopoverID == id {
            activePopoverID = nil
        } else {
            activePopoverID = id
            self.anchorFrame = frame
        }
    }
    
    func hideAll() {
        activePopoverID = nil
    }
}

struct HelpPopoverView: View {
    @EnvironmentObject var userManager: UserManager
    @ObservedObject var manager: PopoverManager
    
    var id: String
    var content: String
    var frameWidth: CGFloat?
    var frameHeight: CGFloat?
    var offsetValue: CGSize
    var icon: String = ""
    
    var onClicked: () -> Void
    
    var body: some View {
        Button(action: {
            manager.toggle(id: id)
            onClicked()
        }) {
            Text(icon)
                .foregroundColor(userManager.userSetting.getTextColor())
                .font(.custom(CustomFonts.FAFreeSolid, size: 20))
                .fixedSize(horizontal: false, vertical: true)
                .dynamicTypeSize(DynamicTypeSize.medium)
                .frame(width: 30, height: 30)
                .padding(.trailing, 20)
        }
        .overlay(
            Group {
                if manager.activePopoverID == id {
                    Text(content)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: frameWidth, height: frameHeight)
                        .padding(.all, 5)
                        .background(userManager.userSetting.getThemeColor(), in: Rectangle())
                        .foregroundColor(userManager.userSetting.getTextColor())
                        .border(Color.gray, width: 1)
                        .font(.caption.bold())
                        .dynamicTypeSize(DynamicTypeSize.medium)
                        .offset(x: offsetValue.width, y: offsetValue.height)
                        .onTapGesture { /* Xử lý nếu cần */ }
                }
            }
        )
    }
}
