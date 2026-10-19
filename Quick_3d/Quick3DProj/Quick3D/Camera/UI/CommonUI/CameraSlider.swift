//
//  OverlapSlider.swift
//  Quick3D
//
//  Created by HungNT on 6/1/26.
//

import SwiftUI

struct CameraSlider: View {
    @Binding var value: CGFloat
    var range: ClosedRange<CGFloat> = 0...100
    var step: CGFloat = 1
    
    var trackHeight: CGFloat = 6
    var bgTrackColor: Color = Color.gray.opacity(0.3)
    var activeTrackColor: Color = skyBlue
    var bgDotColor: Color = .white
    var strokeDotColor: Color = skyBlue
    var dotSize: CGFloat = 20

    var body: some View {
        GeometryReader { geometry in
            // Calculate the percentage safely
            let rangeDiff = range.upperBound - range.lowerBound
            let percent = rangeDiff == 0 ? 0 : (value - range.lowerBound) / rangeDiff
            
            // Calculate the raw width and ensure it's not negative
            let trackWidth = max(0, percent * geometry.size.width)

            ZStack(alignment: .leading) {
                // The Background Track
                Capsule()
                    .fill(bgTrackColor)
                    .frame(height: trackHeight)

                // The Active Track (Accent)
                Capsule()
                    .fill(activeTrackColor)
                    .frame(width: trackWidth, height: trackHeight)

                // The Custom "Dot"
                Circle()
                    .stroke(strokeDotColor, lineWidth: 3)
                    .background(Circle().fill(bgDotColor))
                    .frame(width: dotSize, height: dotSize)
                    .offset(x: trackWidth - dotSize/2) // 10 is half of the thumb width (20/2)
                    .gesture(
                        DragGesture().onChanged { gesture in
                            let dragPercent = Double(gesture.location.x / geometry.size.width)
                            let clippedPercent = min(max(0, dragPercent), 1)
                            
                            let rawValue = CGFloat(clippedPercent) * rangeDiff + range.lowerBound
                            
                            // Apply stepping logic
                            let steppedValue = round(rawValue / step) * step
                            self.value = min(max(range.lowerBound, steppedValue), range.upperBound)
                        }
                    )
            }
        }
        .frame(height: dotSize)
    }
}
