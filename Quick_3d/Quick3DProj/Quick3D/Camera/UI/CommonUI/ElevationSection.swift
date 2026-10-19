//
//  ElevationSection.swift
//  Quick3D
//
//  Created by HungNT on 19/1/26.
//

import SwiftUI
import VigramSDK

struct ElevationSection: View {
    @EnvironmentObject var userManager: UserManager
    
    @Binding var currentElev: ElevationValue
    
    private let elevations: [ElevationValue] = [
        .ang0, .ang5, .ang10, .ang15, .ang20, .ang25, .ang30, .ang35, .ang40
    ]
    
    var body: some View {
        HStack {
            Text("MINIMUM_ELEVATION".localized(userManager.userLanguage))
                .font(.system(size: 16))
                .foregroundColor(userManager.setting.textColor)
            
            Spacer()
            
            Menu {
                ForEach(elevations, id: \.self) { item in
                    Button(action: {
                        currentElev = item
                    }) {
                        HStack {
                            if currentElev == item {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12))
                            }
                            
                            Text(item.displayLabel)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(currentElev.displayLabel)
                        .font(.system(size: 16))
                        .foregroundColor(userManager.setting.textColor)
                    
                    Image("ic_arrow_down_white")
                        .renderingMode(.template)
                        .resizable()
                        .foregroundColor(userManager.setting.textColor)
                        .frame(width: 16, height: 16)
                }
            }
        }
        .padding(16)
        .background(userManager.setting.itemBgColor)
        .cornerRadius(8)
        .frame(maxWidth: .infinity)
    }
    
}

extension ElevationValue {
    /// Nhãn góc ngẩng, ví dụ "15\u{00B0}".
    var displayLabel: String {
        switch self {
        case .ang0:  return "0\u{00B0}"
        case .ang5:  return "5\u{00B0}"
        case .ang10: return "10\u{00B0}"
        case .ang15: return "15\u{00B0}"
        case .ang20: return "20\u{00B0}"
        case .ang25: return "25\u{00B0}"
        case .ang30: return "30\u{00B0}"
        case .ang35: return "35\u{00B0}"
        case .ang40: return "40\u{00B0}"
        default:     return ""
        }
    }
}
