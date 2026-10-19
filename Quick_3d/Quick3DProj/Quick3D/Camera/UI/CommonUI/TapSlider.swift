//
//  TapSlider.swift
//  Quick3D
//
//  Created by Admin on 24/10/25.
//

import SwiftUI

struct TapSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var onCommit: (() -> Void)? = nil
    
    @GestureState private var isDragging = false
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
                Capsule()
                    .fill(Color.blue)
                    .frame(width: width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)), height: 4)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .offset(x: width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) - 10)
                    .shadow(radius: 1)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { gesture in
                        let percent = min(max(gesture.location.x / width, 0), 1)
                        value = range.lowerBound + percent * (range.upperBound - range.lowerBound)
                        onCommit?()
                    }
                    .onEnded { drag in
//                        let percent = min(max(drag.location.x / width, 0), 1)
//                        let newVal = range.lowerBound + Float(percent) * (range.upperBound - range.lowerBound)
//                        value = newVal
//                        onCommit?()
                    }
            )
        }
        .frame(height: 20)
    }
}

struct TapSliderWithToolTip: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var onCommit: (() -> Void)? = nil
    
    private let steps: [Double] = [0, 0.25, 0.5, 0.75, 1.0]
    
    @GestureState private var isDragging = false
    
    @State private var showTooltip = false
    @State private var hideTooltipWorkItem: DispatchWorkItem?
    
    let thumbSize: CGFloat = 20
    let trackHeight: CGFloat = 4
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            
            ZStack(alignment: .leading) {
                // Track Background
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
                
                // Active Track
                Capsule()
                    .fill(Color.blue)
                    .frame(width: width * progress, height: 4)
                
                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    // Center the circle on the point
                    .offset(x: (width * progress) - 10)
                    .shadow(radius: 1)
                
                // 2. Value Tooltip
                if showTooltip {
                    Text(String(format: "%.2f", value))
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .offset(x: (width * progress) - 12, y: -22)
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                }
            }
            .contentShape(Rectangle()) // Makes the whole area tappable
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { gesture in
                        handleDrag(location: gesture.location, width: width)
                    }
            )
        }
        .frame(height: 10)
    }
    
    private func handleDrag(location: CGPoint, width: CGFloat) {
        let rawPercent = min(max(Double(location.x / width), 0), 1)
        
        if let nearestStep = steps.min(by: { abs($0 - rawPercent) < abs($1 - rawPercent) }) {
            if value != nearestStep {
                value = nearestStep
                onCommit?()
                showValueForOneSecond()
            }
        }
    }
    
    private func showValueForOneSecond() {
        withAnimation {
            showTooltip = true
        }
        
        hideTooltipWorkItem?.cancel()
        
        let workItem = DispatchWorkItem {
            withAnimation {
                showTooltip = false
            }
        }
        
        hideTooltipWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
}
