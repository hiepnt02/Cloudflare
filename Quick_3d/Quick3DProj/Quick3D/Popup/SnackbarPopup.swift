//
//  SnackbarPopup.swift
//  Quick3D
//
//  Created by ryoma.terai on 2024/08/16.
//

import SwiftUI

struct SnackbarErrorView: View {
    let message: String
    let onDismiss: () -> Void // ✖︎ボタンが押された時のアクションをクロージャとして渡す
    
    private let isIPhone = UIDevice.current.isIphone
    
    var body: some View {
        HStack {
            Text(message)
                .foregroundColor(.white)
                .padding()

            Spacer()
            
            Button(action: {
                onDismiss() // ボタンが押された時のアクションを実行
            }) {
                Image(systemName: "xmark") // ✖︎アイコン
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .background(Color.red)
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.bottom, isIPhone ? 40 : 100)
        .frame(maxWidth: isIPhone ? 400 : 600)
    }
}
