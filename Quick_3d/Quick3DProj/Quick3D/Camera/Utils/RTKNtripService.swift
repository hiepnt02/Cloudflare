//
//  RTKManager.swift
//  Quick3D
//
//  Created by HaNST on 14/02/25.
//

import Foundation
import VigramSDK
import Combine
import CoreBluetooth
import SwiftUI

protocol RTKNtripStateDelegate: AnyObject {
    func onNtripDisconnected()
    func onNtripDisconnecting()
    func onNtripConnecting()
    func onNtripConnected()
    func onNtripStateChanged(previousState: RTKState?, state: RTKState)
}

final class RTKNtripService: RTKTemplate {
    
    public let gpsService: RTKGPSService
    
    public private(set) var service: NtripService?
    
    private var task: NtripTask?
    
    private var subscription = Set<AnyCancellable>()
    
    let rawState = CurrentPublisher<StateNtripConnection>(.notConnected)
    
    public private(set) var state: RTKState = .disconnected
    
    public private(set) var previousState: RTKState?
    
    public private(set) var isReady: Bool = false
    
    private var isDisconnecting = false
    
    private var recoveryWatchdog: DispatchWorkItem?
    
    private let recoveryTimeout: TimeInterval = 20
    
    public weak var delegate: RTKNtripStateDelegate?
    
    override init(manager: RTKManager? = nil) {
        self.gpsService = RTKGPSService(manager: manager)
        super.init(manager: manager)
    }
    
    private func setReady(_ value: Bool) {
        if value != isReady {
            isReady = value
            manager?.ready.send(value)
        }
    }
    
    private func setError(_ value: Error) {
        self.manager?.error.send(RTKError(level: .ntrip, error: value))
    }
    
    private func verifyState(old: RTKState, new: RTKState) -> Bool {
        guard old != new else { return false }
        
        if new == .connected && old != .connecting {
            return false
        }
        
        return true
    }
    
    private func setState(_ value: RTKState) {
        queue.async {
            if self.verifyState(old: self.state, new: value) {
                
                self.previousState = self.state
                
                self.state = value
                
                self.manager?.ntripState.send(value)
                
                self.onNtripStateChanged(previousState: self.previousState, state: value)
                
                switch value {
                case .connected:
                    self.onNtripConnected()
                case .connecting:
                    self.onNtripConnecting()
                case .disconnected:
                    self.onNtripDisconnected()
                case .disconnecting:
                    self.onNtripDisconnecting()
                }
            }
        }
    }
    
    private func startRecoveryWatchdog() {
        guard recoveryWatchdog == nil else { return }
        
        let work = DispatchWorkItem { [weak self] in
            guard let _self = self else { return }
            
            _self.recoveryWatchdog = nil
            
            guard _self.state == .connected || _self.state == .connecting else { return }
            
            _self.setError(NSError(domain: "RTKNtripService",
                                   code: 0,
                                   userInfo: [
                                    NSLocalizedDescriptionKey: "NTRIP did not recover within \(Int(_self.recoveryTimeout))s"
                                   ]))
            _self.disconnect()
        }
        
        recoveryWatchdog = work
        
        queue.asyncAfter(deadline: .now() + recoveryTimeout, execute: work)
    }
    
    private func cancelRecoveryWatchdog() {
        recoveryWatchdog?.cancel()
        recoveryWatchdog = nil
    }
    
    private func setState(_ value: StateNtripConnection) {
        
        rawState.send(value)
        
        manager?.logInfo("NTRIP", "Raw State: \(value)")
        
        switch value {
        case .ready:
            cancelRecoveryWatchdog()
            setState(RTKState.connected)
        case .reconnectScheduled, .reconnecting:
            startRecoveryWatchdog()
            setState(RTKState.connecting)
        case .reconnectRestored:
            cancelRecoveryWatchdog()
            setState(RTKState.connected)
        case .reconnectFailed(_, let error):
            cancelRecoveryWatchdog()
            setError(error ?? NSError(domain: "RTKNtripService",
                                      code: 0,
                                      userInfo: [
                                        NSLocalizedDescriptionKey: "NTRIP reconnect failed"
                                      ]))
            disconnect()
        case .cancelled:
            if state == .disconnecting || state == .disconnected {
                setState(RTKState.disconnected)
            } else {
                startRecoveryWatchdog()
            }
        case .waiting(let error):
            setError(error)
            startRecoveryWatchdog()
        case .failed(let error):
            setError(error)
            startRecoveryWatchdog()
        case .socketError(let error):
            setError(NSError(domain: "RTKNtripService",
                             code: 0,
                             userInfo: [
                                NSLocalizedDescriptionKey: "socketError: \(error)"
                             ]))
            startRecoveryWatchdog()
        case .unknownError(let error):
            setError(NSError(domain: "RTKNtripService",
                             code: 0,
                             userInfo: [
                                NSLocalizedDescriptionKey: "unknownError: \(error)"
                             ]))
            startRecoveryWatchdog()
        default:
            break
        }
        
    }
    
    
    func setup() {
        service = Vigram.ntripService()
    }
    
    func disconnect() {
        setState(RTKState.disconnecting)
    }
    
    private func unsubscribe() {
        subscription.forEach { $0.cancel() }
        subscription.removeAll(keepingCapacity: true)
    }

    public func reset() {
        unsubscribe()
        
        task?.disconnect()
        task = nil
        previousState = nil
        state = .disconnected
        rawState.send(.notConnected)

        setReady(false)
        
        isDisconnecting = false
        cancelRecoveryWatchdog()
    }
    
    private func connect(information: NtripConnectionInformation, mountPoint: String) {
        
        guard state == .disconnected, let ggaMessage = manager?.bluetoothService?.nmeaData.gga, !isDisconnecting else {
            setError(NSError(domain: "RTKNtripService", code: 0, userInfo: [NSLocalizedDescriptionKey: "The device is unavailable."]))
            return
        }
        
        setState(.connecting)
        
        do {
            try task = service?.task(
                for: information,
                atMountPoint: mountPoint,
                message: ggaMessage
            )
            
            guard let (service, device) = manager?.bluetoothService?.gpsService(correctionTask: task) else {
                task = nil
                setError(NSError(domain: "RTKNtripService", code: 0, userInfo: [NSLocalizedDescriptionKey: "The device is unavailable."]))
                return
            }
            
            gpsService.setService(service: service, device: device)
            
            task?.ntripState
                .receive(on: queue)
                .sink { [weak self] state in
                    guard let _self = self else { return }
                    _self.setState(state)
                }.store(in: &self.subscription)
            
            task?.resume()
                .receive(on: queue)
                .sink(receiveCompletion: { _ in }){ _ in }
                .store(in: &subscription)
            
        } catch {
            setError(error)
        }
        
    }
    
    func connect(hostname: String, port: Int, username: String, password: String, mountPoint: String) {
        
        let nci = NtripConnectionInformation.init(
            hostname: hostname,
            port: port,
            username: username,
            password: password
        )
        
        queue.async {
            self.connect(information: nci, mountPoint: mountPoint)
        }
    }
    
    func getMountpoints(hostname: String, port: Int, username: String, password: String) -> SingleEventPublisher<[NtripMountPoint]>? {
        let nci = NtripConnectionInformation.init(
            hostname: hostname,
            port: port,
            username: username,
            password: password
        )
        return service?.mountpoints(for: nci)
    }
    
}

extension RTKNtripService: RTKNtripStateDelegate {
    
    func onNtripDisconnected() {
        setReady(false)
        reset()
        delegate?.onNtripDisconnected()
    }
    
    func onNtripDisconnecting() {
        delegate?.onNtripDisconnecting()
        isDisconnecting = true
        if let task = self.task {
            task.disconnect()
            setState(.disconnected)
        } else {
            setState(.disconnected)
        }
    }
    
    func onNtripConnecting() {
        delegate?.onNtripConnecting()
    }
    
    func onNtripConnected() {
        cancelRecoveryWatchdog()
        setReady(true)
        delegate?.onNtripConnected()
    }
    
    func onNtripStateChanged(previousState: RTKState?, state: RTKState) {
        delegate?.onNtripStateChanged(previousState: previousState, state: state)
    }
    
}
