//
//  BatteryGaugeView.swift
//  Quick3D
//
//  Created by Admin on 12/6/26.
//

import SwiftUI

struct BatteryGaugeView: View {
    let percentage: Int

    private var fillRatio: CGFloat {
        CGFloat(max(0, min(percentage, 100))) / 100.0
    }
    
    private let frameWidth:  CGFloat = 22
    private let frameHeight: CGFloat = 14

    var body: some View {
        ZStack (alignment: .trailing) {
            
            let currentWidth = fillRatio * 13

            RoundedRectangle(cornerRadius: 0)
                .fill(.white)
                .frame(width: currentWidth, height: 10)
                .offset(x: -3, y: 0)

            Image("battery_black")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.black)
                .frame(width: frameWidth, height: frameHeight)
        }
        .frame(width: frameWidth, height: frameHeight)
    }
}
