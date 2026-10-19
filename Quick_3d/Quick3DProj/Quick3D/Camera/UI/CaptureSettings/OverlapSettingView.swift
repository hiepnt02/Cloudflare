//
//  ImageOverlapSettingPopup.swift
//  Quick3D
//
//  Created by HungNT on 30/3/25.
//

import Foundation
import SwiftUI
import Combine

struct OverlapSettingView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var pendingSettings: CapturePendingSettings

    @State private var sliderValue: CGFloat = 0
    
    private let minValueSlider: CGFloat = 70
    private let maxValueSlider: CGFloat = 95
    private let conversionValue: CGFloat = 100
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Overlap".localized(userManager.userLanguage))
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
                    pendingSettings.overlapValue = (newValue * conversionValue) / 10000
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
            sliderValue = (pendingSettings.overlapValue * 10000) / conversionValue
        }
    }
}
