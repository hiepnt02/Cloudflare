//
//  GNSSQualityBar.swift
//  Quick3D
//
//  Created by HungNT on 19/5/26.
//

import Foundation
import SwiftUI

struct GNSSQualityBar: View {
    @EnvironmentObject var userManager: UserManager
    
    @ObservedObject var rtk: RTKObject = RTKObject.shared
    
    var body: some View {
        let quality = rtk.quality
        Text("\(getQualityStatus(quality))")
            .font(.system(size: 12).bold())
            .foregroundColor(.white)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(imperialBlue.opacity(0.5))
            )
    }
    
    private func getQualityStatus(_ quality: RTKQuality) -> String {
        if rtk.isWaitingForSignal {
            return rtkNotAvailableText
        }
        if rtk.satelliteCountToDisplay == 0 {
            return "RTK_STATUS_UNAVAILABLE".localized(userManager.userLanguage)
        }
        switch quality {
        case .invalid:
            return "RTK_STATUS_NO_FIX".localized(userManager.userLanguage)
        case .gnss:
            return "RTK_STATUS_AUTONOMOUS".localized(userManager.userLanguage)
        case .dgnss:
            return "RTK_STATUS_DGPS".localized(userManager.userLanguage)
        case .fixed:
            return "RTK_STATUS_FIXED".localized(userManager.userLanguage)
        case .float:
            return "RTK_STATUS_FLOAT".localized(userManager.userLanguage)
        }
    }
}
