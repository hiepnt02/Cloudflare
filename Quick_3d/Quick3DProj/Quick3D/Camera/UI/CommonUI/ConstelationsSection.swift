//
//  GNSSConstelationsSection.swift
//  Quick3D
//
//  Created by HungNT on 19/1/26.
//

import SwiftUI

struct ConstelationsSection: View {
    @EnvironmentObject var userManager: UserManager
    
    @Binding var currentGNSS: Set<GNSSEnum>
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("GNSS_CONSTELLATIONS".localized(userManager.userLanguage))
                .font(.system(size: 16))
                .foregroundColor(userManager.setting.textColor)
            
            ForEach(GNSSEnum.allCases) { item in
                HStack {
                    Text(item.title)
                        .font(.system(size: 16))
                        .foregroundColor(userManager.setting.textColor)
                        .padding(.leading, 16)
                    
                    Spacer()
                    
                    GNSSCheckbox(
                        isChecked: currentGNSS.contains(item),
                        allowHit: item != .GPS
                    ) {
                        toggleSelection(for: item)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(userManager.setting.itemBgColor)
        .cornerRadius(8)
        .frame(maxWidth: .infinity)
    }
    
    private func toggleSelection(for item: GNSSEnum) {
        if currentGNSS.contains(item) {
            currentGNSS.remove(item)
        } else {
            currentGNSS.insert(item)
        }
    }
}
