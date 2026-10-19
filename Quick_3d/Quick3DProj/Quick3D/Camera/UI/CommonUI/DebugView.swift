//
//  DebugView.swift
//  Quick3D
//
//  Created by HungNT on 3/6/26.
//

import SwiftUI
import VigramSDK
import Combine

struct DebugView: View {
    
    var isViewARScreen: Bool = false
    
    var body: some View {
        VStack {
            if !isViewARScreen {
                CaptureDebugView()
            }
            
            GPSDebugView()
            
            RTKDebugView()
            
            OthersDebugView()
        }
        .frame(maxWidth: 300)
    }
}
