//
//  RTKSearchingView.swift
//  Quick3D
//
//  Created by HaNST on 29/12/25.
//

import SwiftUI

fileprivate let defaultDeviceName = "Unknown Device"

struct RTKSettingsPopup: View {

    @EnvironmentObject private var userManager: UserManager

    @ObservedObject private var rtk: RTKObject = .shared

    @Binding var isShow: Bool

    @State private var isScanning = false
    @State private var timer: Timer?

    @State private var deviceName: String = defaultDeviceName
    @State private var identifier: UUID?

    private let scanTimeout: TimeInterval = 60

    var body: some View {
        VStack(spacing: 0) {
            PopupTitle(
                title: "RTK_DEVICE_CONNECTION".localized(userManager.userLanguage),
                isShow: $isShow,
                bottomPadding: 8,
                onClose: {
                    onClose()
                }
            )

            Divider().background(lightGray).padding(.bottom, 10)

            contentView
        }
        .onLoad {
            if RTKManager.shared.isReady {
                deviceName = RTKManager.shared.connectedDevice?.peripheral.name ?? defaultDeviceName
                identifier = RTKManager.shared.connectedDevice?.peripheral.identifier ?? UUID()
            } else {
                // Reset identifier and device name when RTK is disconnected
                identifier = nil
                deviceName = defaultDeviceName
                performScan()
            }
        }
        .background(userManager.setting.themeColor)
    }

    @ViewBuilder
    private var contentView: some View {
        if let identifier = self.identifier {
            RTKDeviceSelectedView(
                deviceName: self.deviceName,
                identifier: identifier,
                back: {
                    self.deviceName = defaultDeviceName
                    self.identifier = nil
                    performScan(isRescan: true)
                },
                onClose: {
                    onClose()
                    withAnimation {
                        self.isShow = false
                    }

                }
            )
        } else {
            if !rtk.devices.isEmpty {
                RTKDeviceListView(devices: rtk.devices) { name, identifier in
                    self.deviceName = name
                    self.identifier = identifier
                }
                .onDisappear {
                    if !RTKManager.shared.isReady && identifier == nil {
                        performScan(isRescan: true)
                    }
                }
            } else if isScanning || rtk.state != .disconnected {
                RTKScanningView()
            } else {
                RTKRetryView { performScan(isRescan: true) }
            }
        }
    }

    private func performScan(isRescan: Bool = false) {
        stopTimer()
        isScanning = true
        isRescan ? RTKManager.shared.rescanDevices() : RTKManager.shared.scanDevices()

        timer = Timer.scheduledTimer(withTimeInterval: scanTimeout, repeats: false) { _ in
            isScanning = false
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func onClose() {
        stopTimer()
        if !rtk.isReady {
            RTKManager.shared.stopBluetooth()
            RTKManager.shared.disconnect()
        }
    }
}
