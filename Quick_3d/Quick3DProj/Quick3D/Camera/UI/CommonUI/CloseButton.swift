//
//  ButtonClose.swift
//  Quick3D
//
//  Created by HungNT on 30/9/25.
//

import SwiftUI

struct CloseButton: View {

    let action: () -> Void

    var body: some View {
        CircleButton(
            icon: Image(systemName: "xmark"),
            backgroundColor: Color(hex: 0x000000, alpha: 0.7),
            foregroundColor: .white,
            action: action
        )
    }
}
