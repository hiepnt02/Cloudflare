//
//  RTKDebugView.swift
//  Quick3D
//
//  Created by HungNT on 3/6/26.
//

import SwiftUI

struct RTKDebugView: View {
    
    @ObservedObject private var rtkObject = RTKObject.shared
    @StateObject private var rtkAutoConnection = RTKAutoConnection()
    
    var body: some View {
        VStack {
            DebugTitleView(label: "RTK")
            DebugItemView(label: "Latitude", value: "\(rtkObject.location?.latitude ?? 0)")
            DebugItemView(label: "Longitude", value: "\(rtkObject.location?.longitude ?? 0)")
            DebugItemView(label: "Altitude", value: "\(rtkObject.location?.altitude ?? 0)")
                .padding(.bottom, 5)
            
            DebugItemView(label: "HAccuracy", value: "\(rtkObject.location?.horizontal ?? 0)")
            DebugItemView(label: "VAccuracy", value: "\(rtkObject.location?.vertical ?? 0)")
                .padding(.bottom, 5)
            
            DebugItemView(label: "RawState", value: "\(rtkAutoConnection.rawState, default: "")")
            DebugItemView(
                label: "CorrectionAge",
                value: rtkAutoConnection.correctionAge?.formatAsTime ?? "0"
            )
        }
        .padding(8)
        .foregroundColor(.white)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(imperialBlue.opacity(0.5))
        )
    }
}

extension TimeInterval {
    var formatAsTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: self) ?? "00:00"
    }
}
