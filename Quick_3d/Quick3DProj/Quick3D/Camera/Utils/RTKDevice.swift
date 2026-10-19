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

class NMEAData {
    let gga: GGAMessage?
    let gst: GSTMessage?
    let pvt: VigramSDK.SatelliteMessage.Pvt?
    let dop: VigramSDK.SatelliteMessage.Dop?
    
    let quality: RTKQuality
    
    let accuracy: (horizontal: Double, vertical: Double)?
    
    let raw: String?
    
    init() {
        gga = nil
        gst = nil
        pvt = nil
        dop = nil
        raw = nil
        quality = .invalid
        accuracy = nil
    }
    
    init(_ data: NMEAData, message: NMEAMessage) {
        if let ggaMessage = message as? GGAMessage {
            self.gga = ggaMessage
            self.quality = RTKQuality.of(ggaMessage.quality)
        } else {
            self.gga = data.gga
            self.quality = data.quality
        }
        
        if let gstMessage = message as? GSTMessage {
            self.gst = gstMessage
            self.accuracy = gstMessage.accuracy
        } else {
            self.gst = data.gst
            self.accuracy = data.accuracy
        }
        
        self.pvt = data.pvt
        self.dop = data.dop
        
        self.raw = message.raw
    }
    
    init(_ data: NMEAData, message: SatelliteMessage) {
        self.gga = data.gga
        self.gst = data.gst
        self.raw = data.raw
        
        self.quality = data.quality
        
        self.accuracy = nil
        
        switch message {
        case .pvt(let value):
            self.pvt = value
            self.dop = data.dop
        case .dop(let value):
            self.pvt = data.pvt
            self.dop = value
        default:
            self.pvt = data.pvt
            self.dop = data.dop
        }
    }
}

enum RequestDeviceType{
    case changeStatusGNSS(satellite: NavigationSystemType, activate: Bool)
    case setMinimumElevation(ElevationValue)
    case getStatusGNSS(NavigationSystemType)
    case getMinimumElevation
    case requestBattery
}

final class RTKDevice: RTKTemplate {
    public private(set) var name: String?
    
    public private(set) var device: Peripheral?
    
    private var subscription = Set<AnyCancellable>()
    
    public private(set) var nmea = NMEAData()
    
    public private(set) var previousState: RTKState?
    
    public private(set) var state: RTKState = .disconnected
    
    public private(set) var isReady = false
    
    public private(set) var hasReceivedNmea = false
    
    private var lostSignalTimer: Timer?
    
    private var queueRequest: [RequestDeviceType] = []
        
    private var queueRunning: Bool = false
    
    public weak var delegate: RTKBluetoothStateDelegate?
    
    public var serialNumber: String? {
        device?.serialNumber
    }
    
    private func mapState(_ state: CBPeripheralState) -> RTKState {
        switch state {
        case .connected:
            return RTKState.connected
        case .disconnected:
            return RTKState.disconnected
        case .connecting:
            return RTKState.connecting
        case .disconnecting:
            return RTKState.disconnecting
        @unknown default:
            return RTKState.disconnected
        }
    }
    
    private func setState(_ value: RTKState) {
        previousState = state
        state = value
        manager?.bluetoothState.send(value)
    }
    
    func setState(_ value: CBPeripheralState) {
        let bluetoothState = mapState(value)
        if state != bluetoothState {
            
            setState(bluetoothState)
            
            onBluetoothStateChanged(previousState: previousState, state: bluetoothState)
            
            switch bluetoothState {
            case .connected:
                onBluetoothConnected()
            case .connecting:
                onBluetoothConnecting()
            case .disconnected:
                onBluetoothDisconnected()
            case .disconnecting:
                onBluetoothDisconnecting()
            }
        }
    }
    
    public func reset() {
        unsubscribe()
        
        let timer = lostSignalTimer
        lostSignalTimer = nil
        DispatchQueue.main.async {
            timer?.invalidate()
        }
        
        name = nil
        device = nil
        
        setState(RTKState.disconnected)
        
        previousState = nil
        
        isReady = false
        hasReceivedNmea = false
        nmea = .init()
        
        removeQueue()
    }
    
    private func unsubscribe() {
        subscription.forEach { $0.cancel() }
        subscription.removeAll(keepingCapacity: true)
    }
    
    func setDevice(_ device: Peripheral) {
        self.name = device.peripheral.name
        self.device = device
        setup()
    }
    
    func start() {
        device?.start()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard case .failure(let error) = completion else { return }
                self?.manager?.logError("DEVICE", "Start failed: \(error.localizedDescription)")
                self?.setError(error)
            }){ [weak self] _ in
                guard let _self = self else { return }
                // SC_QUICK-2085
                // This function is called to speed up GNSS system setup in vidoc before configuration is completed in SDK
                _self.setupGNSSSettings()
            }
            .store(in: &subscription)
    }
    
    func setError(_ error: Error) {
        manager?.error.send(RTKError(level: .device, error: error))
    }
    
    func setup() {
//        device?.activateAllConstellationGNSS().sink(receiveCompletion: { _ in }) { _ in }.store(in: &subscription)
     
        device?.nmea
            .receive(on: queue)
            .sink { [weak self] message in
                guard let _self = self else { return }
                
                let nmea = NMEAData(_self.nmea, message: message)
                
                _self.nmea = nmea
                
                _self.manager?.nmea.send(nmea)
                
                _self.hasReceivedNmea = true
                
                if let ggaMessage = message as? GGAMessage {
                    if ggaMessage.coordinate != nil {
                        if !_self.isReady && _self.state == .connected {
                            _self.onBluetoothReady()
                        }
                    }
                }
                
                let quality = nmea.quality
                
                if quality == .invalid && _self.isReady {
                    _self.startLostSignalTimer(10)
                }
                
            }.store(in: &self.subscription)
        
        device?.satelliteMessages
            .receive(on: queue)
            .sink{ [weak self] message in
                guard let _self = self else { return }
                
                let nmea = NMEAData(_self.nmea, message: message)
                
                _self.nmea = nmea
                
                _self.manager?.nmea.send(nmea)
                
            }.store(in: &subscription)
        
        device?.state
            .receive(on: queue)
            .sink { [weak self] state in
                guard let _self = self else { return }
                _self.setState(state)
            }.store(in: &self.subscription)
        
        device?.deviceMessages
            .receive(on: queue)
            .sink { [weak self] message in
                guard let _self = self else { return }
                _self.manager?.deviceMessage.send(message)
            }.store(in: &self.subscription)
        
    }
    
    private func startLostSignalTimer(_ interval: TimeInterval = 2) {
        if self.lostSignalTimer == nil {
            DispatchQueue.main.async {
                guard self.lostSignalTimer == nil else { return }
                self.lostSignalTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] timer in
                    guard let _self = self else { return }
                    _self.queue.async {
                        let isCurrentTimer = _self.lostSignalTimer === timer
                        if RTKLostSignal.shouldDisconnect(isCurrentTimer: isCurrentTimer, isReady: _self.isReady, quality: _self.nmea.quality) {
                            _self.setError(NSError(domain: "RTKBluetoothService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Satellite signal lost."]))
                            _self.manager?.disconnect()
                        }
                        if isCurrentTimer {
                            _self.lostSignalTimer = nil
                        }
                    }
                    
                }
            }
        }
    }
    
    private func startQueue(){
        if(queueRunning) { return }
        queueRunning = true
        runQueue()
    }
    
    private func endQueue(){
        queueRunning = false
    }
    
    private func removeQueue(){
        self.queueRequest.removeAll()
        queueRunning = false
    }
    
    private func runQueue(){
        
        guard let first = queueRequest.first else {
            endQueue()
            return
        }
        queueRequest.removeFirst()
        
        switch first {
        case .changeStatusGNSS(let satellite, let activate):
            self.changeStatusGNSS(satellite, activate, { [weak self] res in self?.runNextQueue(first, res)})
        case .setMinimumElevation(let value):
            self.setMinimumElevation(value, { [weak self] res in self?.runNextQueue(first, res)})
        case .getStatusGNSS(let value):
            self.getCurrentStatusGNSS(value, { [weak self] res in self?.runNextQueue(first, res)})
        case .getMinimumElevation:
            self.getCurrentMinimumElevation({ [weak self] res in self?.runNextQueue(first, res)})
        case .requestBattery:
            self.requestBattery()
        }
    }
    
    func runNextQueue<T>(_ request:RequestDeviceType, _ result: Result<T, Error>,){
        switch result {
        case .success:
            break
        case .failure:
            break
        }
        self.runQueue()
    }
    
    func setupGNSSSettings(){
        /// VigramSDK peripheral functions need to run one by one
    
        let gnss = UserSession.shared.gnsss
        
        let elevation = UserSession.shared.elevation
        
        let isGalileoActivate = gnss.contains(.GALILEO)
        let isQzssActivate = gnss.contains(.QZSS)
        let isGlonassActivate = gnss.contains(.GLONASS)
        let isBeidouActivate = gnss.contains(.BEIDOU)
        
        self.queueRequest.append(.changeStatusGNSS(satellite: .sbas, activate: false))
        self.queueRequest.append(.changeStatusGNSS(satellite: .galileo, activate: isGalileoActivate))
        self.queueRequest.append(.changeStatusGNSS(satellite: .qzss, activate: isQzssActivate))
        self.queueRequest.append(.changeStatusGNSS(satellite: .glonass, activate: isGlonassActivate))
        self.queueRequest.append(.changeStatusGNSS(satellite: .beidou, activate: isBeidouActivate))
        
        self.queueRequest.append(.setMinimumElevation(elevation))
        
        self.queueRequest.append(.requestBattery)
        
        self.startQueue()
    }
    
    private func checkStatusGNSS() {
        self.queueRequest.append(.getStatusGNSS(.gps))
        self.queueRequest.append(.getStatusGNSS(.galileo))
        self.queueRequest.append(.getStatusGNSS(.qzss))
        self.queueRequest.append(.getStatusGNSS(.glonass))
        self.queueRequest.append(.getStatusGNSS(.beidou))
        self.queueRequest.append(.getStatusGNSS(.sbas))
        self.queueRequest.append(.getMinimumElevation)
        self.startQueue()
    }
    
    func setMinimumElevation(_ elevation: ElevationValue,
                             _ callback:(((Result<VigramSDK.SatelliteMessage.Acknowledge, Error>)) -> Void)? = nil){
        
        self.device?.setMinimumElevation(angle: elevation)
            .receive(on: queue)
            .sink(receiveCompletion: {[weak self] completion in
            switch completion {
            case .finished:
                break
            case .failure(let error):
                self?.setError(error)
                callback?(.failure(error))
                break
            }
        })
        {acknowledge in
            callback?(.success(acknowledge))
        }.store(in: &self.subscription)
    }
    
    
    private func changeStatusGNSS(_ satellite: NavigationSystemType,
                                  _ activate: Bool,
                                  _ callback:((Result<VigramSDK.SatelliteMessage.Acknowledge,Error>) -> Void)? = nil){
        
        self.device?.changeStatusGNSS(satellite: satellite, activate: activate)
            .receive(on: queue)
            .sink(receiveCompletion: {[weak self] completion in
            switch completion {
            case .finished:
                break
            case .failure(let error):
                self?.setError(error)
                callback?(.failure(error))
                break
            }
        })
        {acknowledge in
            callback?(.success(acknowledge))
        }.store(in: &self.subscription)
    }
    
    private func getCurrentStatusGNSS(_ satellite: NavigationSystemType,
                                      _ callback:((Result<VigramSDK.SatelliteMessage.StatusSattelite, Error>) -> Void)? = nil) {
        self.device?.getCurrentStatusGNSS(satellite: satellite)
            .receive(on: queue)
            .sink(receiveCompletion: {[weak self] completion in
            switch completion {
            case .finished:
                break
            case .failure(let error):
                self?.setError(error)
                callback?(.failure(error))
                break
            }
        })
        {StatusSattelite in
            callback?(.success(StatusSattelite))
        }.store(in: &self.subscription)
    }
    
    private func getCurrentMinimumElevation(_ callback:((Result<SatelliteMessage.Elevation, Error>) -> Void)? = nil) {
        self.device?.getCurrentMinimumElevation()
            .receive(on: queue)
            .sink(receiveCompletion: {[weak self] completion in
            switch completion {
            case .finished:
                break
            case .failure(let error):
                self?.setError(error)
                callback?(.failure(error))
                break
            }
        })
        {elevation in
            callback?(.success(elevation))
        }.store(in: &self.subscription)
    }
    
    
    
    private func requestBattery(
        delay: TimeInterval = 5,
        maxAttempt: Int = 6,
        attempt: Int = 1) {
        device?.requestBattery()
           .receive(on: queue)
           .sink(receiveCompletion: {[weak self] completion in
               switch completion {
               case .finished:
                   break
               case .failure(let error):
                   if attempt < maxAttempt {
                       DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                           self?.requestBattery(
                               delay: delay,
                               maxAttempt: maxAttempt,
                               attempt: attempt + 1
                           )
                       }
                   } else {
                       self?.setError(error)
                   }
                   break
               }
           }) {[weak self] state in
               let wrappedMessage = DeviceMessage.battery(state)
               self?.manager?.deviceMessage.send(wrappedMessage)
           }.store(in: &subscription)
       
    }
    
}

extension RTKDevice: RTKBluetoothStateDelegate {
    
    func onBluetoothStateChanged(previousState: RTKState?, state: RTKState) {
        delegate?.onBluetoothStateChanged(previousState: previousState, state: state)
        if state != .connected {
            isReady = false
        }
    }
    
    func onBluetoothDisconnected() {
        delegate?.onBluetoothDisconnected()
    }
    
    func onBluetoothDisconnecting() {
        delegate?.onBluetoothDisconnecting()
    }
    
    func onBluetoothConnecting() {
        delegate?.onBluetoothConnecting()
    }
    
    func onBluetoothConnected() {
        delegate?.onBluetoothConnected()
    }
    
    func onBluetoothReady() {
        isReady = true
        delegate?.onBluetoothReady()
    }
}
