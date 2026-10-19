//
//  GNSSStatusBar.swift
//  Quick3D
//
//  Created by HungNT on 23/12/25.
//

import SwiftUI

struct GNSSStatusBar: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var cameraObject: CameraObject
    @EnvironmentObject var thermalMonitor: ThermalMonitor

    @ObservedObject var rtk: RTKObject = RTKObject.shared
    @StateObject var gps: GPSObject = .init()

    @Binding var isShowVidocSetting: Bool
    
    @State private var showDisconnectAlert = false
    
    var onClickThermal: (CGRect) -> Void
    var onHideThermal: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // MARK: - Left RTK/GPS Section
            HStack {
                itemSwitchStatus(
                    isRTK: true,
                    onClick: {
                        isShowVidocSetting = true
                    }
                )

                itemSwitchStatus(
                    isRTK: false,
                    onClick: {
                        if RTKManager.shared.isReady {
                            showDisconnectAlert = true
                        }
                    }
                )
                
            }
            .padding(4)
            .background(darkNavy)
            .clipShape(RoundedRectangle(cornerRadius: borderSoft))
            
            // MARK: - Right Status Section
            if isConnectingToVidoc() {
                rightStatusSection()
            }
            
            if cameraObject.isReady {
                if thermalMonitor.state == .nominal {
                    thermometerView("thermometer-normal")
                } else if thermalMonitor.state == .fair {
                    thermometerView("thermometer-fair")
                } else if thermalMonitor.state == .serious {
                    thermometerView("thermometer-serious")
                } else if thermalMonitor.state == .critical {
                    thermometerView("thermometer-critical")
                }
            }
        }
        .padding(8)
        .background(imperialBlue.opacity(0.5))
        .cornerRadius(borderNormal)
        .overlay(
            RoundedRectangle(cornerRadius: borderNormal)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
        .alert("WARNING".localized(userManager.userLanguage), isPresented: $showDisconnectAlert) {
            Button("YES".localized(userManager.userLanguage), role: .destructive) {
                RTKManager.shared.disconnect()
            }
            Button("CANCEL".localized(userManager.userLanguage), role: .cancel) {}
        } message: {
            Text("RTK_DISCONNECT_CONFIRM".localized(userManager.userLanguage))
        }
    }
    
    private func thermometerView(_ icon: String) -> some View {
        GeometryReader { geo in
            Button(action: {
                if thermalMonitor.state == .fair || thermalMonitor.state == .serious {
                    onClickThermal(geo.frame(in: .global))
                    
                    Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { _ in
                        onHideThermal()
                    }
                }
            }) {
                Image(icon)
                    .frame(width: 13, height: 30)
            }
        }
        .frame(width: 13, height: 30)
    }
    
    func itemSwitchStatus(
        isRTK: Bool,
        onClick: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 4) {
            Text(isRTK ? "RTK" : "GPS")
                .font(.system(size: 16, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            
            if isRTK {
                Image("ic_settings_white")
                    .renderingMode(.template)
                    .font(.system(size: 16))
                    .foregroundColor(isConnectingToVidoc() == isRTK ? .white : .gray)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isConnectingToVidoc() == isRTK ? electricBlue : .clear)
        .foregroundColor(isConnectingToVidoc() == isRTK ? .white : .gray)
        .cornerRadius(borderNormal)
        .overlay(
            isConnectingToVidoc() == isRTK ?
                RoundedRectangle(cornerRadius: borderNormal)
                    .stroke(electricViolet, lineWidth: 1)
            : nil
        )
        .onTapGesture {
            onClick()
        }
    }
    
    func rightStatusSection() -> some View {
        HStack(spacing: 12) {
            // Battery
            VStack(alignment: .center, spacing: 2) {
                if rtk.isWaitingForSignal {
                    Image("ic_battery_default")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 16, height: 11)
                    Text(rtkNotAvailableText)
                        .font(.system(size: 15))
                } else if case .battery(let message) = rtk.batteryMessage {
                    BatteryGaugeView(percentage: message.percentage)
                    Text("\(message.percentage)%")
                        .font(.system(size: 15))
                } else {
                    Image("ic_battery_default")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 16, height: 11)
                    HStack(alignment: .center, spacing: 0) {
                        Image("ic_loading")
                            .frame(width: 10, height: 10)
                        Text("%")
                            .font(.system(size: 15))
                    }
                    .padding(.leading, 2)
                }
            }
            .padding(.top, 4)
            
            // Satellites
            VStack(alignment: .center, spacing: 0) {
                Image("ic_satellite_white")
                    .frame(width: 16, height: 16)
                Text(rtk.isWaitingForSignal ? rtkNotAvailableText : "\(rtk.satelliteCountToDisplay)")
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(.white.opacity(0.8))
    }

    private func isConnectingToVidoc() -> Bool {
        return rtk.isReady || rtk.isWaitingForSignal
    }
}

extension RTKObject {
    var satelliteCountToDisplay: Int {
        let pvtCount = satelliteMessagePVT?.satelliteCount ?? 0
        
        if pvtCount > 0 {
            return pvtCount
        } else {
            return GGAMessage?.satelliteCount ?? 0
        }
    }
}
