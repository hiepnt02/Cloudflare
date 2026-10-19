//
//  RTKManager.swift
//  Quick3D
//
//  Created by HaNST on 21/11/24.
//

import Foundation
import VigramSDK
import Combine
import CoreBluetooth
import SwiftUI
import Keys

enum RTKQuality {
    case fixed
    case float
    case dgnss
    case gnss
    case invalid
    
    static func of(_ quality: GPSQualityIndicator?) -> RTKQuality {
        guard let quality = quality else {
            return .invalid
        }
        switch quality {
        case .rtkFixedAmbiguitySolution:
            return .fixed
        case .singlePoint:
            return .gnss
        case .pseudoRangeDifferential:
            return .dgnss
        case .rtkFloatingAmbiguitySolution:
            return .float
        default:
            return .invalid
        }
    }
}

enum RTKState {
    case connecting
    case disconnecting
    case connected
    case disconnected
}

enum RTKErrorLevel {
    case device
    case bluetooth
    case ntrip
    case gps
    case auth
}

struct RTKError {
    let level: RTKErrorLevel
    let error: Error
}

enum RTKConnectionPhase: Equatable {
    case bluetooth
    case waitingFix
    case ntrip
    case connected
    
    static func current(bluetooth: RTKState, isReady: Bool, ntrip: RTKState) -> RTKConnectionPhase {
        if bluetooth != .connected {
            return .bluetooth
        }
        if !isReady {
            return .waitingFix
        }
        return ntrip == .connected ? .connected : .ntrip
    }
    
    var needsForceReset: Bool {
        return self == .bluetooth
    }
}

enum RTKTimeoutAction: Equatable {
    case ignore
    case abort
    case disconnect
    case extend
    
    /// Only a connect still in progress is timed out; once it has connected or is already
    /// being torn down, a late fire must not cut a link or an NTRIP auto-reconnect.
    /// A viDoc that has sat idle can take far longer than the screen's timeout to report a
    /// position after reconnecting, so a link that is up and streaming gets more time instead.
    static func on(state: RTKState, phase: RTKConnectionPhase, receivingData: Bool, canExtend: Bool) -> RTKTimeoutAction {
        guard state == .connecting else { return .ignore }
        if phase.needsForceReset {
            return .abort
        }
        if canExtend && receivingData && (phase == .waitingFix || phase == .ntrip) {
            return .extend
        }
        return .disconnect
    }
}

enum RTKLostSignal {
    /// A lost-signal timer can outlive the session that started it, and a reset device reports
    /// `.invalid` by default, so only the timer still held by a ready device may disconnect.
    static func shouldDisconnect(isCurrentTimer: Bool, isReady: Bool, quality: RTKQuality) -> Bool {
        return isCurrentTimer && isReady && quality == .invalid
    }
}

enum RTKBluetoothReadiness {
    static func shouldReauthenticate(serviceReady: Bool, authInFlight: Bool) -> Bool {
        return !serviceReady && !authInFlight
    }
}

class RTKDebugLogger: CSVLogger {
    
    let formatter = DateFormatter()
    
    init() {
        super.init(fileUrl: StorageManager.shared.getCameraFileURL("rtk.log"), canAppend: true)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    
    func logInfo(_ step: String, _ message: String) {
        
        print("INFO \(step): \(message)")
        
        let time = formatter.string(from: Date())
        self.log([
            time,
            "RTK",
            "INFO",
            step,
            message
        ], -1)
    }
    
    func logError(_ step: String, _ message: String) {
        
        print("ERROR \(step): \(message)")
        
        let time = formatter.string(from: Date())
        self.log([
            time,
            "RTK",
            "ERROR",
            step,
            message
        ], -1)
    }
    
}

final class RTKManager: NSObject {
    
    public static let shared = RTKManager()
    
    public let queue = DispatchQueue(label: "ltd.landlog.scquick3d.RTKManager", attributes: [])
    
    private var subscription = Set<AnyCancellable>()
    
    public var state = CurrentPublisher<RTKState>(.disconnected)
    
    public let ready = CurrentPublisher<Bool>(false)
    
    public var isReady: Bool { ntripService?.isReady ?? false }
    
    public let location = CurrentPublisher<LocationModel>(.init())
    
    public let nmea = CurrentPublisher<NMEAData>(.init())
    
    public let devices = CurrentPublisher<[CBPeripheral]>([])
    
    public let isBluetoothReady = CurrentPublisher<Bool>(false)
    
    /// Emits the viDoc whose Bluetooth link dropped without the app asking for it.
    public let connectionLost = PassthroughSubject<UUID, Never>()
    
    /// True from an unexpected drop until the viDoc is back or the wait for it is over.
    public let isRecovering = CurrentPublisher<Bool>(false)
    
    /// The part of a recovery before the viDoc shows up again.
    public let isWaitingForSignal = CurrentPublisher<Bool>(false)
    
    public let recoveryFailed = PassthroughSubject<Void, Never>()
    
    public var deviceMessage = CurrentPublisher<DeviceMessage?>(nil)
    
    public let error = CurrentPublisher<RTKError?>(nil)
    
    public var bluetoothState = CurrentPublisher<RTKState>(.disconnected)
    
    public var ntripState = CurrentPublisher<RTKState>(.disconnected)
    
    public var serialNumber: String? {
        bluetoothService?.serialNumber
    }
    
    public var connectedDevice: Peripheral? {
        bluetoothService?.connectedDevice
    }
    
    public var isConnecting: Bool {
        currentState != .disconnected
    }
    
    public var id: String?
    
    public let rtkLogger = RTKDebugLogger()
    
    public private(set) var bluetoothService: RTKBluetoothService?
    
    public private(set) var ntripService: RTKNtripService?
    
    public private(set) var autoDisconnect: Bool = false
    
    private var isAutoConnectToNtrip: Bool = false
    
    private var connectedIdentifier: UUID?
    
    private var timeoutTimer: Timer?

    private var isAuthenticating: Bool = false
    
    private var disconnectWatchdog: DispatchWorkItem?
    
    private let disconnectWatchdogTimeout: TimeInterval = 5
    
    /// Total time, counted from the start of a connect, that a streaming device may take to get a fix and NTRIP.
    private let fixWaitLimit: TimeInterval = 60
    
    private var connectWaitLimit: TimeInterval = 60
    
    private var connectStartedAt: Date?
    
    private var previousState: RTKState?
    
    private let staleCorrectionLimit: TimeInterval = 50
    
    public private(set) var currentState: RTKState = .disconnected
    
    public var lastVidocConnected: UUID? {
        UserSession.shared.lastVidocConnected
    }
    
    public var isNtripConfigured: Bool {
        UserSession.shared.ntripInfo != nil && UserSession.shared.mountPointNtrip?.isEmpty == false
    }

    private var onDisconnected: (() -> Void)? = nil
    
    override init() {
        super.init()
        _ = ConnectivityMonitor.shared
        Configuration.debug = false
        setupNtripReconnect()
        bluetoothService = RTKBluetoothService(manager: self)
        ntripService = RTKNtripService(manager: self)
        authenticationToken()
    }
    
    /// Values carried over from the retry loop the app used to run itself before
    /// VigramSDK 2.0.0; the SDK has no documented defaults, so they are set here.
    private func setupNtripReconnect() {
        Configuration.ntripAutoReconnectMaxAttempts = 3
        Configuration.ntripAutoReconnectDelay = 3
        Configuration.ntripCorrectionAgeReconnectThreshold = 10
        Configuration.ntripMountpointsTimeout = 15
        
        logInfo("NTRIP", "Auto-reconnect: maxAttempts \(Configuration.ntripAutoReconnectMaxAttempts), delay \(Configuration.ntripAutoReconnectDelay)s, age threshold \(Configuration.ntripCorrectionAgeReconnectThreshold)s, mountpoints timeout \(Configuration.ntripMountpointsTimeout)s")
    }
    
    func authenticationToken() {
        let token = Quick3DKeys().vidocKey
        if token.isEmpty {
            logError("AUTH", "Vidoc key is empty, RTK is disabled")
        } else {
            isAuthenticating = true
            Vigram.initial(token: token.replacingOccurrences(of: "/\\/" , with: "//"))
                .check()
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        self?.isAuthenticating = false
                        self?.logError("AUTH", "Authentication failed: \(error.localizedDescription)")
                        self?.error.send(RTKError(level: .auth, error: error))
                    }
                }) { [weak self] resultAuthentication in
                    self?.isAuthenticating = false
                    switch resultAuthentication {
                    case .success:
                        self?.logInfo("AUTH", "Authentication succeeded")
                        self?.setup()
                    case .failure(let error):
                        self?.logError("AUTH", "Authentication failed: \(error.localizedDescription)")
                        self?.error.send(RTKError(level: .auth, error: error))
                    }
                }.store(in: &subscription)
        }
        
    }
    
    /// Authentication runs once at init and is never retried by itself, so a launch without
    /// network would otherwise leave RTK without a Bluetooth service until the app restarts.
    func ensureBluetoothService() {
        DispatchQueue.main.async {
            guard RTKBluetoothReadiness.shouldReauthenticate(serviceReady: self.bluetoothService?.service != nil,
                                                             authInFlight: self.isAuthenticating) else { return }
            self.authenticationToken()
        }
    }
    
    private func setState(_ value: RTKState) {
        queue.async {
            if value != self.currentState {
                self.previousState = self.currentState
                self.currentState = value
                self.state.send(value)
            }
        }
    }
    
    private func setup() {
        subscription.removeAll()
        
        bluetoothService?.delegate = self
        
        bluetoothService?.setup()
        
        nmea
            .receive(on: queue)
            .sink { [weak self] data in
                if let gga = data.gga, let _ = data.dop {
                    CaptureSession.current?.rtkLogger?.logNMEA(message: data)
                    self?.disconnectIfCorrectionIsStale(gga)
                }
            }.store(in: &subscription)
        
        ntripService?.delegate = self
        
        ntripService?.setup()
        
        ntripService?.gpsService.data
            .receive(on: queue)
            .sink { [weak self] data in
                if let d = data {
                    CaptureSession.current?.rtkLogger?.logGPS(data: d,
                                                              quality: self?.bluetoothService?.nmeaData.quality,
                                                              pvt: self?.bluetoothService?.nmeaData.pvt,
                                                              dop: self?.bluetoothService?.nmeaData.dop)
                }
            }.store(in: &subscription)
        
        error
            .receive(on: queue)
            .sink { [weak self] error in
                guard let _self = self else { return }
                if let e = error {
                    _self.logError("\(e.level)", e.error.localizedDescription)
                }
            }.store(in: &subscription)
        
        state
            .receive(on: queue)
            .sink { [weak self] state in
            guard let _self = self else { return }
            _self.logInfo("MANAGER", "State \(state)")
            if state == .disconnected {
                _self.rtkLogger.write()
            }
        }.store(in: &subscription)
    }
    
    /// Cleared synchronously so a fresh subscriber is not handed the previous scan's list.
    func scanDevices() {
        bluetoothService?.scanDevices()
    }
    
    func rescanDevices() {
        bluetoothService?.stopScanDevices()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [weak self] _ in
            self?.bluetoothService?.scanDevices()
        }
    }
    
    func stopBluetooth() {
        bluetoothService?.stopScanDevices()
    }
    
    func connectTo(
        device peripheral: CBPeripheral,
        isAutoConnectToNtrip: Bool = false,
        timeout: TimeInterval = 300
    ) throws {
        
        if !ConnectivityMonitor.shared.isCurrentlyConnected() {
            throw URLError(.notConnectedToInternet)
        }
        
        if isConnecting {
            throw NSError(domain: "RTKManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "The device is unavailable."])
        }
        
        self.isAutoConnectToNtrip = isAutoConnectToNtrip
        
        connectedIdentifier = nil
        
        autoDisconnect = false
        
        // Create Configuration
        let gnss = UserSession.shared.gnsss
        let isGalileoActivate = gnss.contains(.GALILEO)
        let isQzssActivate = gnss.contains(.QZSS)
        let isGlonassActivate = gnss.contains(.GLONASS)
        let isBeidouActivate = gnss.contains(.BEIDOU)
        
        let peripheralConfiguration = PeripheralConfiguration(
            elevationValue: UserSession.shared.elevation,
            glonassActivate: isGlonassActivate,
            beidouActivate: isBeidouActivate,
            galileoActivate: isGalileoActivate,
            qzssActivate: isQzssActivate,
            sbassActivate: false
        )
        
        setState(.connecting)
        
        if isAutoConnectToNtrip {
            connectStartedAt = Date()
            connectWaitLimit = isRecovering.value ? timeout : fixWaitLimit
            startTimeoutTimer(timeout)
        }
        
        do {
            try bluetoothService?.connect(device: peripheral, config: peripheralConfiguration)
        } catch {
            setState(.disconnected)
            stopTimeoutTimer()
            throw error
        }
        
    }
    
    func disconnect(_ auto: Bool = false, completion: (() -> Void)? = nil) {
        if currentState == .disconnected {
            completion?()
            return
        }
        onDisconnected = completion
        autoDisconnect = auto
        setState(RTKState.disconnecting)
        ready.send(false)
        stopTimeoutTimer()
        startDisconnectWatchdog()
        ntripService?.disconnect()
    }
    
    /// Ends an attempt whose peripheral never connected; see `RTKBluetoothService.abandonConnection()`.
    private func abortConnection() {
        stopTimeoutTimer()
        cancelDisconnectWatchdog()
        ready.send(false)
        bluetoothService?.abandonConnection()
        setState(.disconnected)
        onDisconnected?()
        onDisconnected = nil
    }
    
    private func startDisconnectWatchdog() {
        cancelDisconnectWatchdog()
        let work = DispatchWorkItem { [weak self] in
            guard let _self = self, _self.currentState == .disconnecting else { return }
            _self.abortConnection()
        }
        disconnectWatchdog = work
        queue.asyncAfter(deadline: .now() + disconnectWatchdogTimeout, execute: work)
    }
    
    private func cancelDisconnectWatchdog() {
        disconnectWatchdog?.cancel()
        disconnectWatchdog = nil
    }
    
    private var connectionPhase: RTKConnectionPhase {
        RTKConnectionPhase.current(bluetooth: bluetoothService?.state ?? .disconnected,
                                   isReady: bluetoothService?.isReady ?? false,
                                   ntrip: ntripState.value)
    }
    
    func onBluetoothConnectFailed() {
        queue.async {
            guard self.currentState == .connecting, self.connectionPhase.needsForceReset else { return }
            self.abortConnection()
        }
    }
    
    func disconnectNTRIP() {
        stopTimeoutTimer()
        ntripService?.disconnect()
    }
    
    func connectToNTRIP(hostname: String, port: String, username: String, password: String, mountPoint: String) throws {
        
        guard let portNum = Int(port) else {
            throw NSError(domain: "RTKManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "The port must be an integer."])
        }
        
        try connectToNTRIP(hostname: hostname, port: portNum, username: username, password: password, mountPoint: mountPoint)
    }
    
    func connectToNTRIP(hostname: String, port: Int, username: String, password: String, mountPoint: String) throws {
        UserSession.shared.ntripInfo = NtripInfoModel(username: username, password: password, port: port, hostnameOrIp: hostname)
        UserSession.shared.mountPointNtrip = mountPoint
        try connectToNTRIP()
    }
    
    func connectToNTRIP() throws {
        if let info = UserSession.shared.ntripInfo, let mountPoint = UserSession.shared.mountPointNtrip {
            logInfo("Connect NTRIP", "Connect to Ntrip")
            ntripService?.connect(hostname: info.hostnameOrIp, port: info.port, username: info.username, password: info.password, mountPoint: mountPoint)
        } else {
            throw NSError(domain: "RTKManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cannot connect RTK device."])
        }
    }
    
    /// The SDK owns NTRIP reconnect since 2.0.0, but it never gives up on a stream
    /// that keeps flowing with corrections this stale, so the app still cuts it.
    private func disconnectIfCorrectionIsStale(_ gga: GGAMessage) {
        guard ntripState.value == .connected,
              gga.correctionAge ?? 0 > staleCorrectionLimit else { return }
        
        logError("NTRIP", "Correction age above \(Int(staleCorrectionLimit))s, dropping NTRIP")
        
        disconnectNTRIP()
    }
    
    func getMountpoints(hostname: String, port: Int, username: String, password: String) -> SingleEventPublisher<[NtripMountPoint]>? {
        return ntripService?.getMountpoints(hostname: hostname, port: port, username: username, password: password)
    }
    
    func mapToAntennaOffset() -> SIMD3<Double> {
        ntripService?.gpsService.mapToAntennaOffset() ?? .zero
    }
    
    func startTimeoutTimer(_ timeout: TimeInterval = 60) {
        DispatchQueue.main.async {
            self.timeoutTimer?.invalidate()
            self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                guard let _self = self else { return }
                _self.queue.async {
                    let phase = _self.connectionPhase
                    let remaining = _self.connectWaitLimit - Date().timeIntervalSince(_self.connectStartedAt ?? Date())
                    let action = RTKTimeoutAction.on(state: _self.currentState,
                                                     phase: phase,
                                                     receivingData: _self.bluetoothService?.hasReceivedNmea ?? false,
                                                     canExtend: remaining >= 1)
                    switch action {
                    case .ignore:
                        return
                    case .extend:
                        _self.startTimeoutTimer(remaining)
                    case .abort, .disconnect:
                        _self.logError("MANAGER", "Connection timeout.")
                        if action == .abort {
                            _self.abortConnection()
                        } else {
                            _self.disconnect()
                        }
                    }
                }
            }
        }
    }
    
    func stopTimeoutTimer() {
        DispatchQueue.main.async {
            self.timeoutTimer?.invalidate()
            self.timeoutTimer = nil
        }
    }
    
}

extension RTKManager {
    func logInfo(_ step: String, _ message: String) {
        rtkLogger.logInfo(step, message)
        CaptureSession.current?.sessionLogger.logProcessing("rtk", step, ["message": message])
    }

    func logError(_ step: String, _ message: String) {
        rtkLogger.logError(step, message)
        rtkLogger.write()
        CaptureSession.current?.sessionLogger.logProcessing("rtk", step, level: .error, ["message": message])
    }
}

extension RTKManager: RTKBluetoothStateDelegate {
    func onBluetoothDisconnected() {
        let lostIdentifier = currentState == .disconnecting ? nil : connectedIdentifier
        connectedIdentifier = nil
        cancelDisconnectWatchdog()
        setState(.disconnected)
        onDisconnected?()
        onDisconnected = nil
        if ntripState.value != .disconnected {
            ready.send(false)
            ntripService?.disconnect()
        }
        if let identifier = lostIdentifier {
            isRecovering.send(true)
            isWaitingForSignal.send(true)
            // Queued behind the state change above so listeners already see `.disconnected`.
            queue.async {
                self.connectionLost.send(identifier)
            }
        }
    }
    
    func onBluetoothDisconnecting() {
    }
    
    func onBluetoothConnecting() {
    }
    
    func onBluetoothConnected() {
    }
    
    func onBluetoothReady() {
        logInfo("BLUETOOTH", "Ready")
        if currentState == .connecting && isAutoConnectToNtrip {
            queue.async {
                do {
                    try self.connectToNTRIP()
                } catch {
                    self.error.send(RTKError(level: .ntrip, error: error))
                }
            }
        }
    }
    
    func onBluetoothStateChanged(previousState: RTKState?, state: RTKState) {
        logInfo("BLUETOOTH", "PreviousState \(previousState, default: "None") -> State \(state)")
    }
    
}

extension RTKManager: RTKNtripStateDelegate {
    func onNtripDisconnected() {
        if isAutoConnectToNtrip {
            bluetoothService?.disconnect()
        }
    }
    
    func onNtripDisconnecting() {
        
    }
    
    func onNtripConnecting() {
        if currentState == .connected {
            setState(.connecting)
        }
    }
    
    func onNtripConnected() {
        
        setState(.connected)
        
        stopTimeoutTimer()
        
        if let identifier = bluetoothService?.identifier {
            UserSession.shared.lastVidocConnected = identifier
            connectedIdentifier = identifier
        }
    }
    
    func onNtripStateChanged(previousState: RTKState?, state: RTKState) {
        logInfo("NTRIP", "PreviousState \(previousState, default: "None") -> State \(state)")
    }
    
}

class RTKTemplate: NSObject {
    
    public private(set) weak var manager: RTKManager?
    
    public var queue: DispatchQueue {
        manager?.queue ?? DispatchQueue.main
    }
    
    public var logger: RTKDebugLogger? {
        manager?.rtkLogger
    }
    
    init(manager: RTKManager? = nil) {
        self.manager = manager
    }
    
}
