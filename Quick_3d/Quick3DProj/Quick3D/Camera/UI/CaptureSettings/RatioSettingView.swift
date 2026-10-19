//
//  RatioSettingView.swift
//  Quick3D
//
//  Created by HungNT on 24/4/26.
//

import Foundation
import SwiftUI
import Combine

struct RatioSettingView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var pendingSettings: CapturePendingSettings

    @State private var sliderValue: CGFloat = 0
    
    private let minValueSlider: CGFloat = 50
    private let maxValueSlider: CGFloat = 90
    private let conversionValue: CGFloat = 100
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Scan Ratio:")
                .font(.system(size: 16))
                .foregroundColor(userManager.setting.textColor)
                .padding(.bottom, 8)
            
            // Slider
            HStack () {
                CameraSlider(
                    value: $sliderValue,
                    range: minValueSlider...maxValueSlider,
                    step: 5
                )
                .onChange(of: sliderValue) { newValue in
                    pendingSettings.ratioValue = (newValue * conversionValue) / 10000
                }
                
                Text("\(Int(sliderValue))%")
                    .frame(maxWidth: 50)
                    .padding(.leading, 8)
            }
        }
        .padding(16)
        .background(userManager.setting.itemBgColor)
        .cornerRadius(8)
        .frame(maxWidth: .infinity)
        .onAppear {
            sliderValue = (pendingSettings.ratioValue * 10000) / conversionValue
        }
    }
}
