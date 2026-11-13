//
//  PopoverManager.swift
//  Quick3D
//
//  Created by HungNT on 30/6/26.
//

import SwiftUI

class PopoverManager: ObservableObject {
    @Published var activePopoverID: String? = nil
    @Published var anchorFrame: CGRect = .zero // Lưu tọa độ nút icon
    
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
