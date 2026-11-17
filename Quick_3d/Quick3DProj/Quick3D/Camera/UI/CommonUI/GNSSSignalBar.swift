//
//  GNSSSignalBar.swift
//  Quick3D
//
//  Created by HungNT on 24/12/25.
//

import SwiftUI

struct GNSSSignalBar: View {
    @ObservedObject var rtk: RTKObject = RTKObject.shared
    @StateObject var gps: GPSObject = .init()
    
    private let weakSignalThreshold: Double = 0.02
    private let strongSignalThreshold: Double = 0.015
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Quality Row (RTK only; with GPS the icon is always red and misleading)
            if isConnectingToVidoc() {
                qualityRow()
                    .padding(.bottom, 8)
            }
            
            // Data Rows
            let hRTK = rtk.accuracy.horizontal
            let hGPS = gps.location?.horizontal ?? 0.0
            measureRow(
                label: "H",
                value: String(format: "%.3fm", isConnectingToVidoc() ? hRTK : hGPS),
                labelColor: isConnectingToVidoc() ? getColorVHRTK(hRTK) : getColorVHGPS(hGPS)
            )
            
            let vRTK = rtk.accuracy.vertical
            let vGPS = gps.location?.vertical ?? 0.0
            measureRow(
                label: "V",
                value: String(format: "%.3fm", isConnectingToVidoc() ? vRTK : vGPS),
                labelColor: isConnectingToVidoc() ? getColorVHRTK(vRTK) : getColorVHGPS(vGPS)
            )
            
            if isConnectingToVidoc() {
                let hDop = rtk.GGAMessage?.hdop ?? 0.0
                let rawAge = rtk.GGAMessage?.correctionAge ?? 0.0
                
                measureRow(
                    label: "HDOP",
                    value: String(format: "%.3f", hDop),
                    labelColor: getColorHDOP(hDop)
                )
                
                measureRow(
                    label: "AGE",
                    value: ageDisplayValue(rawAge: rawAge),
                    labelColor: getColorAGE(rawAge)
                )
            }
        }
        .padding(4)
        .background(imperialBlue.opacity(0.5))
        .cornerRadius(borderNormal)
    }
    
    private func ageDisplayValue(rawAge: Double) -> String {
        if rawAge < 0 {
            return "-"
        } else {
            let roundedAge = (rawAge * 2).rounded() / 2.0
            return String(format: "%.1fs", roundedAge)
        }
    }
    
    private func qualityRow() -> some View {
        let h: Double
        let v: Double
        var numIconBright: Int = 0

        if isConnectingToVidoc() {
            h = rtk.accuracy.horizontal
            v = rtk.accuracy.vertical
        } else if !isConnectingToVidoc() {
            h = gps.location?.horizontal ?? 0
            v = gps.location?.vertical ?? 0
        } else {
            // Default case is low accuracy
            h = 0.03
            v = 0.03
        }
        
        if (h >= weakSignalThreshold || v >= weakSignalThreshold) {
            numIconBright = 3
        } else if (h < strongSignalThreshold && v < strongSignalThreshold) {
            numIconBright = 1
        } else {
            numIconBright = 2
        }
        
        return HStack {
            createIcon(image: Image(systemName: "checkmark.circle.fill"), color: mintBreeze)
                .opacity(numIconBright == 1 ? 1.0 : 0.3)
            
            createIcon(image: Image("attention"), color: sunburst)
                .opacity(numIconBright == 2 ? 1.0 : 0.3)
            
            createIcon(image: Image("ic_exclamation"), color: vibrantPeach)
                .opacity(numIconBright == 3 ? 1.0 : 0.3)
        }
    }
    
    private func createIcon(image: Image, color: Color) -> some View {
        image
            .resizable()
            .renderingMode(.template)
            .foregroundColor(color)
            .frame(width: 20, height: 20)
    }
    
    private func measureRow(
        label: String,
        value: String,
        labelColor: Color
    ) -> some View {
        HStack(spacing: 8) {
            // Label Box
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(labelColor)
                .frame(width: 49, height: 18)
                .background(Color(white: 0.15))
                .overlay(
                    Rectangle()
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
            
            // Value
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(labelColor)
                .lineLimit(1)
            
            Spacer()
        }
        .frame(width: 140)
    }
    
    private func isConnectingToVidoc() -> Bool {
        return rtk.isReady
    }
    
    private func getColorVDOP(_ value: Double) -> Color {
        if value > 1.5 || value <= 0 {
            return vibrantPeach
        } else if value > 1 {
            return sunburst
        } else {
            return mintBreeze
        }
    }
    
    private func getColorHDOP(_ value: Double) -> Color {
        if value > 1 || value <= 0 {
            return vibrantPeach
        } else if value > 0.65 {
            return sunburst
        } else {
            return mintBreeze
        }
    }
    
    private func getColorAGE(_ value: Double) -> Color {
        if value <= 3 {
            return mintBreeze
        } else if value <= 10 { 
            return sunburst
        } else {
            return vibrantPeach
        }
    }
    
    private func getColorVHRTK(_ value: Double) -> Color {
        switch value {
        case ...0.0: // value <= 0.0
            return vibrantPeach
        case 0.0..<strongSignalThreshold: // 0.0 <= value < 0.015 (Strong)
            return mintBreeze
        case strongSignalThreshold..<weakSignalThreshold: // 0.015 <= value < 0.02 (Normal)
            return sunburst
        default: // value >= 0.02 (Weak)
            return vibrantPeach
        }
    }
    
    private func getColorVHGPS(_ value: Double) -> Color {
        switch value {
        case ...0.0: // value <= 0.0 (Weak)
            return vibrantPeach
        case 0.0...5.0: // 0.0 < value <= 5.0 (Strong)
            return mintBreeze
        case 5.0...10.0: // 5.0 < value <= 10.0 (Normal)
            return sunburst
        default: // value > 10.0 (Weak)
            return vibrantPeach
        }
    }
}
