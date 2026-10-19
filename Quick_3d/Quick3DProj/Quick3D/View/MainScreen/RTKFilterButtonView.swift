//
//  RTKFilterButtonView.swift
//  Quick3D
//
//  Created by HungNT on 20/5/26.
//

import SwiftUI

struct RTKFilterButtonView: View {
    @EnvironmentObject var userManager: UserManager
    
    @Binding var rtkFilterMode: Int
    let isIPhone: Bool
    let labelProvider: (Int) -> String
    let onTap: () -> Void
    
    var body: some View {
        Button(
            action: {
                rtkFilterMode = (rtkFilterMode + 1) % 3
                onTap()
            },
            label: {
                Group {
                    if rtkFilterMode == 2 {
                        VStack(spacing: 0) {
                            ZStack {
                                userManager.setting.getGpsRtkButtonColor(0)
                                Text("GPS").foregroundColor(.white)
                            }
                            ZStack {
                                userManager.setting.getGpsRtkButtonColor(1)
                                Text("RTK").foregroundColor(.white)
                            }
                        }
                        .frame(width: isIPhone ? 40 : 50, height: isIPhone ? 32 : 42)
                        .font(isIPhone ? .system(size: 12) : .system(size: 16))
                    } else {
                        Text(labelProvider(rtkFilterMode))
                            .foregroundColor(.white)
                            .frame(width: isIPhone ? 40 : 50, height: isIPhone ? 32 : 42)
                            .font(isIPhone ? .system(size: 12) : .system(size: 16))
                            .background(userManager.setting.getGpsRtkButtonColor(rtkFilterMode))
                    }
                }
            }
        )
        .padding(1)
    }
}
