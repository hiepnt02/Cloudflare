//
//  StatusView.swift
//  Quick3D
//
//  Created by HungNT on 13/5/26.
//

import SwiftUI

struct StatusView: View {
    enum Status {
        case normal, processing, completed, error, dashboard_upload
    }
    let index: Int
    let status: Status
    
    private var size: CGFloat { UIDevice.current.isIphone ? 18 : 25 }
    
    var body: some View {
        switch status {
        case .normal, .error:
            ZStack {
                Circle()
                    .fill(status == .normal ? Color.gray : Color.red)
                    .frame(width: size, height: size)
                Text("\(index)")
                    .font(.system(size: UIDevice.current.isIphone ? 10 : 13))
                    .foregroundColor(.white)
            }
        case .processing:
            ZStack {
                Circle()
                    .fill(Color(hex: 0xD9D029))
                    .frame(width: size, height: size)
                Image("editing")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(180))
                    .frame(width: size, height: size)
            }
        case .completed:
            Image("check")
                .resizable()
                .frame(width: size, height: size)
        case .dashboard_upload:
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: size, height: size)
                Image("check_white")
                    .resizable()
                    .frame(width: size, height: size)
            }
        }
    }
}
