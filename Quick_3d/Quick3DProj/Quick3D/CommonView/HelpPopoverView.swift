//
//  HelpPopoverView.swift
//  Quick3D
//
//  Created by HungNT on 18/6/26.
//

import SwiftUI

class PopoverManager: ObservableObject {
    @Published var activePopoverID: String? = nil
    @Published var anchorFrame: CGRect = .zero // Store the icon button's frame
    
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
    var icon: String = "questionmark.circle.fill"
    var iconColor: Color? = nil
    var trailingPadding: CGFloat = 20
    var autoHideAfter: TimeInterval? = nil
    
    var onClicked: () -> Void
    
    @State private var autoHideWorkItem: DispatchWorkItem?
    
    var body: some View {
        Button(action: {
            manager.toggle(id: id)
            onClicked()
        }) {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(iconColor ?? userManager.setting.textColor)
                .frame(width: 20, height: 20)
                .padding(5)
                .frame(width: 30, height: 30)
                .padding(.trailing, trailingPadding)
        }
        .overlay(
            Group {
                if manager.activePopoverID == id {
                    Text(content)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: frameWidth, height: frameHeight)
                        .padding(.all, 5)
                        .foregroundColor(userManager.setting.textColor)
                        .background {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(userManager.setting.themeColor)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.gray, lineWidth: 1)
                        }
                        .font(.caption.bold())
                        .dynamicTypeSize(DynamicTypeSize.medium)
                        .offset(x: offsetValue.width, y: offsetValue.height)
                        .onTapGesture { /* Handle tap if needed */ }
                }
            }
        )
        .onChange(of: manager.activePopoverID) { activeID in
            scheduleAutoHide(activeID: activeID)
        }
        .onDisappear {
            autoHideWorkItem?.cancel()
            autoHideWorkItem = nil
        }
    }
    
    private func scheduleAutoHide(activeID: String?) {
        autoHideWorkItem?.cancel()
        autoHideWorkItem = nil
        
        guard let autoHideAfter = autoHideAfter, activeID == id else { return }
        
        let workItem = DispatchWorkItem {
            if manager.activePopoverID == id {
                manager.activePopoverID = nil
            }
        }
        autoHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + autoHideAfter, execute: workItem)
    }
}
