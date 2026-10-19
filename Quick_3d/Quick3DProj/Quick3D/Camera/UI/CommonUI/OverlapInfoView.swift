//
//  OverlapInfoView.swift
//  Quick3D
//
//  Created by HungNT on 25/12/25.
//

import SwiftUI

struct OverlapInfoView: View {
    
    @AppStorage("overlapValue")
    private var overlapValue: Double = 0
    
    var body: some View {
        Text("\(Int(overlapValue * 100))%")
            .font(.system(size: 12))
            .foregroundColor(.white)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(imperialBlue.opacity(0.5))
            )
    }
}
