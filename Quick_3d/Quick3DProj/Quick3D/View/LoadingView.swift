//
//  LoadingView.swift
//  Quick3D
//
//  Created by 横内浩志 on 2023/01/21.
//

import SwiftUI

struct LoadingView: View {
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(.black)
                .opacity(0.5)
            ProgressView("")
        }
    }
}
