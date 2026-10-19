//
//  CenterAlertView.swift
//  Quick3D
//
//  Created by Admin on 2/6/26.
//

import SwiftUI

struct CenterAlertView: View {
    
    @Binding var message: String
    @Binding var isShow: Bool
    
    var body: some View {
        if isShow {
            HStack {
                Text(message)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(rubyRed)
            )
            .frame(maxHeight: .infinity, alignment: .center)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    isShow = false
                }
            }
        } else {
            EmptyView()
        }
    }
}

