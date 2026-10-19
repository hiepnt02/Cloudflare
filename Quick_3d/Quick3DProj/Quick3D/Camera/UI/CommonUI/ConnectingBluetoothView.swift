//
//  ConnectingBluetoothView.swift
//  Quick3D
//
//  Created by HungNT on 20/10/25.
//

import SwiftUI
import Combine
import CoreBluetooth

struct ConnectingBluetoothView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var bluetoothState: RTKState?
    @State private var cancellable: AnyCancellable?

    var body: some View {
        HStack {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(0.6)
                .frame(width: 20, height: 20)

            Text(bluetoothState == .connected ? "GETTING_LOCATION_INFO".localized(userManager.userLanguage) : "DETECTING_VIDOC".localized(userManager.userLanguage))
                .font(.system(size: 12))
                .foregroundColor(.white)
            
        }
        .frame(height: UserSession.isIPhone ? 38 : 46)
        .padding(.horizontal, 8)
        .background(imperialBlue.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: borderNormal))
        .onAppear {
            cancellable = RTKManager.shared.bluetoothState.receive(on: DispatchQueue.main).sink { state in
                bluetoothState = state
            }
        }
        .onDisappear {
            cancellable?.cancel()
        }
    }
}
