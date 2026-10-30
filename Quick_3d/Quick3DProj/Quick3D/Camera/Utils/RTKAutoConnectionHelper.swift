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

final class RTKAutoConnectionHelper {
    
    public static let shared = RTKAutoConnectionHelper()
    
    let state = CurrentPublisher<RTKState>(.disconnected)
    
    let error = CurrentPublisher<Error?>(nil)
    
    private var subscription = Set<AnyCancellable>()
    
    private var isOptional: Bool = true
    
    private var scanTimer: Timer?
    
    private var devices: [CBPeripheral] = []
    
    private var isScanning: Bool = true
    
    private var timeout: TimeInterval = 60
    
    private var scanTimeout: TimeInterval = 10
    
    private init() {
    }
    
    func startScanTimer(_ timeout: TimeInterval = 10) {
        if scanTimer == nil {
            RTKManager.shared.scanDevices()
            DispatchQueue.main.async {
                self.scanTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                    guard let _self = self else { return }
                    if _self.devices.isEmpty {
                        _self.setError(NSError(domain: "RTKAutoConnectionHepler", code: 0, userInfo: [NSLocalizedDescriptionKey: "Scan devices timeout."]))
                        _self.unsubscribe()
                    }
                    _self.scanTimer = nil
                }
            }
        }
    }

    func stopTimer() {
        scanTimer?.invalidate()
        scanTimer = nil
    }
    
    func setState(_ state: RTKState) {
        self.state.send(state)
        stopTimer()
        RTKManager.shared.logInfo("AUTOCONNECT", "State \(state)")
    }
    
    func setError(_ error: Error?) {
        RTKManager.shared.queue.async { [weak self] in
            if error != nil {
                self?.setState(.disconnected)
                RTKManager.shared.logError("AUTOCONNECT", error!.localizedDescription)
            }
            self?.error.send(error)
        }
    }
    
    func setup() {
        
        unsubscribe()
        
        RTKManager.shared.state
            .receive(on: RTKManager.shared.queue)
            .sink { [weak self] state in
                guard let _self = self else { return }
                switch state {
                case .connected:
                    _self.setState(.connected)
                case .disconnected:
                    if !_self.isScanning {
                        _self.setState(.disconnected)
                        _self.unsubscribe()
                    }
                default:
                    break
                }
            }.store(in: &subscription)
        
        RTKManager.shared.devices
            .receive(on: RTKManager.shared.queue)
            .sink { [weak self] devices in
                
                guard let _self = self else { return }
                
                _self.devices = devices
                
                if !devices.isEmpty && _self.isScanning {
                    _self.isScanning = false
                    _self.stopTimer()
                    if let last = RTKManager.shared.lastVidocConnected, let device = devices.filter({ $0.identifier == last }).first {
                        _self.connect(device: device)
                    } else if !_self.isOptional {
                        _self.connect(device: devices[0])
                    } else {
                        _self.setError(NSError(domain: "RTKAutoConnectionHepler", code: 0, userInfo: [NSLocalizedDescriptionKey: "Can't connect to device."]))
                    }
                }
            }.store(in: &self.subscription)
        
    }
    
    func unsubscribe() {
        subscription.forEach { $0.cancel() }
        subscription.removeAll(keepingCapacity: true)
    }
    
    func connect(device: CBPeripheral) {
        do {
            try RTKManager.shared.connectTo(device: device, isAutoConnectToNtrip: true, timeout: timeout)
        } catch {
            setError(error)
        }
    }
    
    func start(optional: Bool = true, scanTimeout: TimeInterval = 10, timeout: TimeInterval = 60) {
        RTKManager.shared.queue.async {
            if !RTKManager.shared.isConnecting && self.state.value == .disconnected {
                self.setState(.connecting)
                self.isScanning = true
                self.scanTimeout = scanTimeout
                self.timeout = timeout
                self.isOptional = optional
                self.error.send(nil)
                self.startScanTimer(scanTimeout)
                self.setup()
            }
        }
    }
}
