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
    
    private var session: RTKScanSession?
    
    private var scanTimer: Timer?
    
    private var devices: [CBPeripheral] = []
    
    private var isScanning: Bool = true
    
    private var timeout: TimeInterval = 60
    
    private var scanTimeout: TimeInterval = 10
    
    private let ntripMissingWait: TimeInterval = 10
    
    /// How long the viDoc that dropped out may take to come back in range before giving up.
    private let recoveryWait: TimeInterval = 10
    
    /// Once it is back in range, how long getting the link, fix and NTRIP back may take.
    private let recoveryConnectLimit: TimeInterval = 30
    
    private var recovery: RTKRecovery?
    
    private var reconnectSubscription: AnyCancellable?
    
    private init() {
        reconnectSubscription = RTKManager.shared.connectionLost
            .receive(on: RTKManager.shared.queue)
            .sink { [weak self] identifier in
                self?.reconnect(to: identifier)
            }
    }
    
    private func reconnect(to identifier: UUID) {
        recovery = RTKRecovery(device: identifier, deadline: Date().addingTimeInterval(recoveryWait))
        RTKManager.shared.isRecovering.send(true)
        RTKManager.shared.isWaitingForSignal.send(true)
        if state.value != .disconnected {
            unsubscribe()
            setState(.disconnected)
        }
        retryRecovery()
    }
    
    /// Every failed attempt is retried until the deadline, so a link that drops again mid-reconnect is not the end.
    private func retryRecovery() {
        guard let recovery = recovery else { return }
        let remaining = recovery.deadline.timeIntervalSinceNow
        guard remaining >= 1 else {
            endRecovery(restored: false)
            return
        }
        start(scanTimeout: remaining, timeout: recoveryConnectLimit, only: recovery.device)
    }
    
    private func endRecovery(restored: Bool) {
        guard recovery != nil else { return }
        recovery = nil
        RTKManager.shared.isRecovering.send(false)
        RTKManager.shared.isWaitingForSignal.send(false)
        if !restored {
            RTKManager.shared.recoveryFailed.send()
        }
    }
    
    /// Stops waiting for the viDoc without reporting the connection as lost.
    func cancelRecovery() {
        RTKManager.shared.queue.async {
            guard self.recovery != nil else { return }
            self.recovery = nil
            RTKManager.shared.isRecovering.send(false)
            RTKManager.shared.isWaitingForSignal.send(false)
            self.isScanning = false
            self.unsubscribe()
            self.setState(.disconnected)
        }
    }
    
    /// The timer lives on main; its event is applied on the RTK queue, and only to the session that scheduled it.
    private func startTimer(_ timeout: TimeInterval, _ event: @escaping (inout RTKScanSession) -> RTKScanDecision) {
        guard let id = session?.id else { return }
        DispatchQueue.main.async {
            self.scanTimer?.invalidate()
            self.scanTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                RTKManager.shared.queue.async {
                    guard let _self = self, _self.session?.id == id else { return }
                    _self.handle(event(&_self.session!))
                }
            }
        }
    }

    func stopTimer() {
        DispatchQueue.main.async {
            self.scanTimer?.invalidate()
            self.scanTimer = nil
        }
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
                    _self.endRecovery(restored: true)
                case .disconnected:
                    if !_self.isScanning {
                        _self.setState(.disconnected)
                        _self.unsubscribe()
                        _self.retryRecovery()
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
                
                if let decision = _self.session?.update(available: devices.map { $0.identifier }) {
                    _self.handle(decision)
                }
            }.store(in: &self.subscription)
        
        RTKManager.shared.isBluetoothReady
            .receive(on: RTKManager.shared.queue)
            .sink { [weak self] ready in
                guard let _self = self, ready, _self.session?.serviceReady() == true else { return }
                RTKManager.shared.scanDevices()
                _self.startTimer(_self.scanTimeout) { $0.deadline() }
            }.store(in: &self.subscription)
        
    }
    
    private func handle(_ decision: RTKScanDecision) {
        switch decision {
        case .wait:
            break
        case .connect(let identifier):
            isScanning = false
            stopTimer()
            guard let device = devices.first(where: { $0.identifier == identifier }) else {
                fail(.deviceNotFound)
                return
            }
            if recovery != nil {
                recovery?.deviceFound(connectLimit: recoveryConnectLimit)
                RTKManager.shared.isWaitingForSignal.send(false)
            }
            connect(device: device)
        case .fail(let reason):
            fail(reason)
        }
    }
    
    private func fail(_ reason: RTKScanFailure) {
        isScanning = false
        if recovery != nil {
            unsubscribe()
            setState(.disconnected)
            endRecovery(restored: false)
            return
        }
        setError(NSError(domain: "RTKAutoConnectionHepler", code: 0, userInfo: [NSLocalizedDescriptionKey: reason.message]))
        unsubscribe()
    }
    
    func unsubscribe() {
        subscription.forEach { $0.cancel() }
        subscription.removeAll(keepingCapacity: true)
    }
    
    func connect(device: CBPeripheral) {
        do {
            try RTKManager.shared.connectTo(device: device, isAutoConnectToNtrip: true, timeout: timeout)
        } catch where recovery != nil {
            fail(.deviceNotFound)
        } catch {
            setError(error)
        }
    }
    
    /// `optional` only tells the caller whether a failure deserves an alert; device choice is the same on every screen.
    /// With `only`, no other viDoc is taken, even once the scan deadline has passed.
    func start(optional: Bool = true, scanTimeout: TimeInterval = 10, timeout: TimeInterval = 60, only device: UUID? = nil) {
        RTKManager.shared.queue.async {
            if !RTKManager.shared.isConnecting && self.state.value == .disconnected {
                self.setState(.connecting)
                self.isScanning = true
                self.scanTimeout = scanTimeout
                self.timeout = timeout
                self.error.send(nil)
                let ntripConfigured = RTKManager.shared.isNtripConfigured
                self.session = RTKScanSession(saved: device ?? RTKManager.shared.lastVidocConnected,
                                              ntripConfigured: ntripConfigured,
                                              allowOther: device == nil)
                self.setup()
                if ntripConfigured {
                    RTKManager.shared.ensureBluetoothService()
                    self.startTimer(scanTimeout) { $0.serviceTimeout() }
                } else {
                    self.startTimer(self.ntripMissingWait) { $0.ntripWaitElapsed() }
                }
            }
        }
    }
}

struct RTKRecovery {
    let device: UUID
    
    private(set) var deadline: Date
    
    private var isDeviceFound = false
    
    init(device: UUID, deadline: Date) {
        self.device = device
        self.deadline = deadline
    }
    
    /// Only the first sighting extends the deadline; retries after that do not push it further.
    mutating func deviceFound(connectLimit: TimeInterval, at date: Date = Date()) {
        guard !isDeviceFound else { return }
        isDeviceFound = true
        deadline = date.addingTimeInterval(connectLimit)
    }
}

enum RTKScanFailure: Equatable {
    case deviceNotFound
    case serviceUnavailable
    case ntripNotConfigured
    
    var message: String {
        switch self {
        case .deviceNotFound:
            return "Device not found."
        case .serviceUnavailable:
            return "Bluetooth service not ready."
        case .ntripNotConfigured:
            return "NTRIP not configured."
        }
    }
}

enum RTKScanDecision: Equatable {
    case connect(UUID)
    case wait
    case fail(RTKScanFailure)
    
    /// The saved device always wins. Another device is only taken when nothing is saved,
    /// or once the scan deadline has passed without the saved one showing up.
    static func evaluate(available: [UUID], saved: UUID?, deadlineReached: Bool, allowOther: Bool = true) -> RTKScanDecision {
        if let saved = saved, available.contains(saved) {
            return .connect(saved)
        }
        guard let first = available.first, allowOther else {
            return deadlineReached ? .fail(.deviceNotFound) : .wait
        }
        if saved == nil || deadlineReached {
            return .connect(first)
        }
        return .wait
    }
}

struct RTKScanSession {
    enum Phase {
        case ntripMissing
        case waitingService
        case scanning
        case decided
    }
    
    let id = UUID()
    
    let saved: UUID?
    
    private(set) var phase: Phase = .waitingService
    
    let allowOther: Bool
    
    private var available: [UUID] = []
    
    init(saved: UUID?, ntripConfigured: Bool = true, allowOther: Bool = true) {
        self.saved = saved
        self.allowOther = allowOther
        if !ntripConfigured {
            phase = .ntripMissing
        }
    }
    
    /// Without NTRIP settings the connection can never complete, so nothing is scanned or
    /// connected; the attempt only ends once this wait is over.
    mutating func ntripWaitElapsed() -> RTKScanDecision {
        guard phase == .ntripMissing else { return .wait }
        return decide(.fail(.ntripNotConfigured))
    }
    
    /// Returns true only on the transition into scanning, i.e. when the caller should start the scan and its deadline.
    mutating func serviceReady() -> Bool {
        guard phase == .waitingService else { return false }
        phase = .scanning
        return true
    }
    
    mutating func serviceTimeout() -> RTKScanDecision {
        guard phase == .waitingService else { return .wait }
        return decide(.fail(.serviceUnavailable))
    }
    
    /// Lists that arrive before the service is ready can only be leftovers from an earlier scan, so they are ignored.
    mutating func update(available: [UUID]) -> RTKScanDecision {
        guard phase == .scanning else { return .wait }
        self.available = available
        return decide(RTKScanDecision.evaluate(available: available, saved: saved, deadlineReached: false, allowOther: allowOther))
    }
    
    mutating func deadline() -> RTKScanDecision {
        guard phase == .scanning else { return .wait }
        return decide(RTKScanDecision.evaluate(available: available, saved: saved, deadlineReached: true, allowOther: allowOther))
    }
    
    private mutating func decide(_ decision: RTKScanDecision) -> RTKScanDecision {
        if decision != .wait {
            phase = .decided
        }
        return decision
    }
}
