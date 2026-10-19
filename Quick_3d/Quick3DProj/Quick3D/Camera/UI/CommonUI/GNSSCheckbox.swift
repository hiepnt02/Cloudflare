//
//  GNSSCheckbox.swift
//  Quick3D
//
//  Created by HungNT on 19/1/26.
//

import SwiftUI

struct GNSSCheckbox: View {
    let isChecked: Bool
    var allowHit: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isChecked ? lavender : Color.white)
                
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isChecked ? electricBlue : Color.gray, lineWidth: 2)
                
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(electricBlue)
                }
            }
            .frame(width: 24, height: 24)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!allowHit)
    }
}
