//
//  RTKDisconnectionObserver.swift
//  Quick3D
//
//  Created by Admin on 10/11/25.
//

import Foundation
import Combine

final class RTKConnectionObserver: ObservableObject {
    
    public static let shared = RTKConnectionObserver()
    
    private var subscription = Set<AnyCancellable>()
    private var lastDeviceReady = false
    private(set) var lastQuality: RTKQuality? = nil

    var showAlert: ((String) -> Void)?

    init() {
        observe()
    }

    private func observe() {
        RTKManager.shared.nmea
            .receive(on: DispatchQueue.main)
            .sink { [weak self] nmea in
                guard let _self = self else { return }
                let quality = nmea.quality
                if _self.lastQuality == .fixed && quality != .fixed {
                    let msg = "RTK_LOST_FIXED_QUALITY"
                    _self.showAlert?(msg)
                }
                _self.lastQuality = quality
            }
            .store(in: &subscription)
        
        RTKManager.shared.ready
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                if state {
                    self?.lastDeviceReady = true
                }
            }
            .store(in: &subscription)

        RTKManager.shared.bluetoothState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let _self = self else { return }

                let nowNotConnected: Bool = {
                    if case .disconnected = state { return true }
                    return false
                }()

                if nowNotConnected {
                    if _self.lastDeviceReady {
                        let msg = "RTK_LOST_CONNECTION"
                        _self.showAlert?(msg)
                        _self.lastDeviceReady = false
                    }
                    _self.lastQuality = nil
                }
            }
            .store(in: &subscription)
    }
    
    func reset() {
        lastQuality = nil
        lastDeviceReady = false
    }
}
