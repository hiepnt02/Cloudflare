//
//  VidocInfoSection.swift
//  Quick3D
//
//  Created by HungNT on 19/1/26.
//

import SwiftUI

struct VidocInfoSection: View {
    @EnvironmentObject private var userManager: UserManager
    
    @ObservedObject private var rtkObj: RTKObject = RTKObject.shared

    var body: some View {
        VStack(alignment: .leading) {
            if rtkObj.isReady {
                Group {
                    if UIDevice.current.isIphone {
                        vidocInfoSectionIphone()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        vidocInfoSectionIpad()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
    }
    
    private func vidocInfoSectionIphone() -> some View {
        HStack(alignment: .center) {
            Text(rtkObj.vidocConnected?.peripheral.name ?? "")
                .font(.system(size: 20))
                .foregroundColor(userManager.setting.textColor)
            
            // Battery
            Image("ic_battery_white")
                .renderingMode(.template)
                .resizable()
                .foregroundColor(userManager.setting.textColor)
                .frame(width: 16, height: 16)
            
            if case .battery(let mesage) = rtkObj.batteryMessage {
                Text("\(mesage.percentage)%")
                    .font(.system(size: 12))
                    .foregroundColor(userManager.setting.textColor)
            }
            
            Spacer()
            
            Text("接続済み")
                .font(.system(size: 12))
                .padding(2)
                .foregroundColor(pineGreen)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(pineGreen, lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 2).fill(mintBreeze)
                        )
                )
        }
        .padding(.bottom, 8)
    }
    
    private func vidocInfoSectionIpad() -> some View {
        VStack {
            Image("img_vidoc_case")
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(Circle())
            
            HStack {
                Text(rtkObj.vidocConnected?.peripheral.name ?? "")
                    .font(.system(size: 16))
                    .foregroundColor(userManager.setting.textColor)
                
                Text("接続済み")
                    .font(.system(size: 12))
                    .padding(2)
                    .foregroundColor(pineGreen)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(pineGreen, lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 2).fill(mintBreeze)
                            )
                    )
            }
            
            HStack {
                Image("ic_battery_white")
                    .renderingMode(.template)
                    .resizable()
                    .foregroundColor(userManager.setting.textColor)
                    .frame(width: 16, height: 16)
                
                if case .battery(let mesage) = rtkObj.batteryMessage {
                    Text("\(mesage.percentage)%")
                        .font(.system(size: 16))
                        .foregroundColor(userManager.setting.textColor)
                }
            }
            .padding(.bottom, 8)
        }
    }
}
