//
//  CaptureButtonView.swift
//  Quick3D
//
//  Created by HungNT on 24/9/25.
//

import SwiftUI

struct CaptureButton: View {
    
    @EnvironmentObject var arObject: ARObject
    
    @StateObject private var gps = GPSObject()
    
    var size: CGFloat = UIDevice.current.isIphone ? 72 : 82
    
    let action: () -> Void
    
    var body: some View {
        if gps.ready {
            Button(action: action)
            {
                switch arObject.status {
                case .running:
                    Image("ic_pause_circle")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Color.white)
                        .frame(width: 48, height: 48)
                default:
                    Image("ic_shutter")
                        .resizable()
                        .frame(width: size, height: size)
                }
            }
            .frame(width: size + 8, height: size + 8)
            .background(arObject.status != .running && arObject.status != .exported ? Color.gray.opacity(0) : Color(hex: 0x000000, alpha:0.5))
            .clipShape(Circle())
        }
    }
}
