//
//  GPSDebugView.swift
//  Quick3D
//
//  Created by HungNT on 3/6/26.
//

import SwiftUI
import VigramSDK
import Combine

struct GPSDebugView: View {
    @StateObject private var gpsObject = GPSObject()
    
    var body: some View {
        VStack {
            DebugTitleView(label: "GPS")
            DebugItemView(label: "Latitude", value: "\(gpsObject.location?.latitude ?? 0)")
            DebugItemView(label: "Longitude", value: "\(gpsObject.location?.longitude ?? 0)")
            DebugItemView(label: "Altitude", value: "\(gpsObject.location?.altitude ?? 0)")
                .padding(.bottom, 5)
            
            DebugItemView(label: "HAccuracy", value: "\(gpsObject.location?.horizontal ?? 0)")
            DebugItemView(label: "VAccuracy", value: "\(gpsObject.location?.vertical ?? 0)")
        }
        .padding(8)
        .foregroundColor(.white)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(imperialBlue.opacity(0.5))
        )
    }
}
