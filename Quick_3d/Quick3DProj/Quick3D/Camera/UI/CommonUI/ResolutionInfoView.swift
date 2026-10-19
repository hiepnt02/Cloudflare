//
//  ResolutionInfoView.swift
//  Quick3D
//
//  Created by HungNT on 25/12/25.
//

import SwiftUI

struct ResolutionInfoView: View {
    @EnvironmentObject var userManager: UserManager
    
    @AppStorage("imageResolution")
    private var imageResolution: ImageResolutionEnum = .normal
    
    var body: some View {
        Text(imageResolution.getLabel(userManager))
            .font(.system(size: 12))
            .foregroundColor(.white)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(imperialBlue.opacity(0.5))
            )
    }
}
