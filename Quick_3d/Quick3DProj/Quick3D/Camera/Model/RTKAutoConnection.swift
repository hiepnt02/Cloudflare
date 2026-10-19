//
//  RTKAutoConnection.swift
//  Quick3D
//
//  Created by HaNST on 27/2/25.
//

import Foundation
import SwiftUI
import Combine
import VigramSDK
import CoreBluetooth

final class RTKAutoConnection: ObservableObject {
    
    @Published var rawState: StateNtripConnection = .notConnected
    
    @Published var state: RTKState = .connecting
    
    @Published var quality: RTKQuality = .invalid
    
    @Published var correctionAge: TimeInterval? = nil
    
    @Published var error: Error?
    
    @Published var isError: Bool = false
    
    private var subscription = Set<AnyCancellable>()
    
    private var isOptional: Bool = true
    
    private var scanTimer: Timer?
    
    private var stateTimer: Timer?
    
    init() {
        setup()
    }
    
    func setup() {
        RTKManager.shared.ntripService?.rawState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let _self = self else { return }
                _self.rawState = state
            }.store(in: &subscription)
        
        RTKAutoConnectionHelper.shared.state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let _self = self else { return }
                _self.state = state
            }.store(in: &subscription)
        
        RTKManager.shared.nmea
            .receive(on: DispatchQueue.main)
            .sink { [weak self] nmea in
                guard let _self = self else { return }
                _self.quality = nmea.quality
                _self.correctionAge = nmea.gga?.correctionAge
            }.store(in: &subscription)
        
        RTKAutoConnectionHelper.shared.error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let _self = self else { return }
                if let e = error {
                    _self.error = e
                    _self.isError = true
                } else {
                    _self.isError = false
                }
            }.store(in: &subscription)
    }
    
    func unsubscribe() {
        subscription.forEach { $0.cancel() }
        subscription.removeAll(keepingCapacity: true)
    }
    
}
