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

protocol RTKBluetoothStateDelegate: AnyObject {
    func onBluetoothDisconnected()
    func onBluetoothDisconnecting()
    func onBluetoothConnecting()
    func onBluetoothConnected()
    func onBluetoothReady()
    func onBluetoothStateChanged(previousState: RTKState?, state: RTKState)
}

final class RTKBluetoothService: RTKTemplate {
    
    public private(set) var service: BluetoothService?
    
    private var subscription = Set<AnyCancellable>()
    
    private let rtkDevice: RTKDevice
    
    public var bluetooth: BluetoothService {
        service!
    }

    public weak var delegate: RTKBluetoothStateDelegate?
    
    public var serialNumber: String? {
        rtkDevice.serialNumber
    }
    
    public var name: String? {
        rtkDevice.name
    }
    
    public var identifier: UUID? {
        rtkDevice.device?.peripheral.identifier
    }
    
    public var isConnected: Bool {
        state == .connected
    }
    
    public var nmeaData: NMEAData {
        rtkDevice.nmea
    }
    
    public var connectedDevice: Peripheral? {
        rtkDevice.device
    }
    
    public var previousState: RTKState? {
        rtkDevice.previousState
    }
    
    public var state: RTKState {
        rtkDevice.state
    }
    
    private var isDisconnecting = false
    
    private var lostSignalTimer: Timer?
    
    /// Kept out of `subscription`: that set is cleared on every stop/start scan.
    private var stateSubscription: AnyCancellable?
    
    /// Also kept out of `subscription`, the other way round: stopping a scan must
    /// not cancel a connect that is already in flight.
    private var scanSubscription: AnyCancellable?
    
    override init(manager: RTKManager? = nil) {
        self.rtkDevice = RTKDevice(manager: manager)
        super.init(manager: manager)
        self.rtkDevice.delegate = self
    }
    
    func setup() {
        self.service = Vigram.bluetoothService()
        observeBluetoothState()
        scanDevices()
    }
    
    private func observeBluetoothState() {
        stateSubscription = service?.state()
            .receive(on: queue)
            .sink { [weak self] state in
                self?.logger?.logInfo("BLUETOOTH", "Manager state \(state.rawValue)")
            }
    }
    
    public func scanDevices() {
        logger?.logInfo("BLUETOOTH", "Scanning...")
        DispatchQueue.main.async {
            self.scanSubscription = self.service?.observeAvailableDevices()
                .receive(on: self.queue)
                .sink { [weak self] devices in
                    self?.logger?.logInfo("BLUETOOTH", "Found \(devices.count) device(s): \(devices.map { $0.name ?? $0.identifier.uuidString }.joined(separator: ", "))")
                    self?.manager?.devices.send(devices)
                }
            self.service?.startScan()
        }
    }
    
    public func stopScanDevices() {
        DispatchQueue.main.async {
            self.scanSubscription = nil
            self.service?.stopScan()
            self.manager?.devices.send([])
        }
    }
    
    private func unsubscribe() {
        subscription.forEach { $0.cancel() }
        subscription.removeAll(keepingCapacity: true)
    }
    
    private func reset() {
        unsubscribe()
        isDisconnecting = false
        rtkDevice.reset()
        
        stopScanDevices()
        scanDevices()
    }
    
    public func disconnect() {
        isDisconnecting = true
        if rtkDevice.state == .connected {
            rtkDevice.setState(.disconnecting)
        }
        DispatchQueue.main.async {
            self.service?.disconnect()
        }
    }
    
    func connect(device peripheral: CBPeripheral, config peripheralConfig: PeripheralConfiguration) throws {
        if rtkDevice.state != .disconnected {
            throw NSError(domain: "RTKBluetoothService", code: 0, userInfo: [NSLocalizedDescriptionKey: "The device is unavailable."])
        }
        DispatchQueue.main.async {
            let device = Vigram.peripheral(peripheral, configuration: peripheralConfig)
            self.connect(device)
        }
    }
    
    private func connect(_ device: Peripheral) {
        rtkDevice.setDevice(device)
        logger?.logInfo("BLUETOOTH", "Connecting to \(device.peripheral.name ?? "Unknown") (\(device.peripheral.identifier.uuidString)), state \(device.peripheral.state.rawValue)")
        service?.connect(to: device.peripheral.identifier)
            .receive(on: queue)
            .sink(receiveCompletion: { [weak self] completion in
                guard let _self = self else { return }
                switch completion {
                case .finished:
                    _self.rtkDevice.start()
                case .failure(let error):
                    _self.manager?.logError("BLUETOOTH", "Connect failed: \(error)")
                    _self.manager?.error.send(RTKError(level: .bluetooth, error: error))
                }
            }){ _ in }.store(in: &subscription)
    }
    
    public func gpsService(correctionTask task: (any VigramSDK.NtripTask)?) -> (service: GPSService, device: Peripheral)? {
        if isConnected, let _device = rtkDevice.device {
            let service = Vigram.gpsService(
                peripheral: _device,
                bluetoothService: bluetooth,
                correctionTask: task,
                automaticallyReconnectNtrip: true
            )
            return (service, _device)
        }
        return nil
    }
    
}

extension RTKBluetoothService: RTKBluetoothStateDelegate {
    
    func onBluetoothStateChanged(previousState: RTKState?, state: RTKState) {
        delegate?.onBluetoothStateChanged(previousState: previousState, state: state)
    }
    
    func onBluetoothDisconnected() {
        reset()
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
        if isDisconnecting {
            disconnect()
        }
    }
    
    func onBluetoothReady() {
        delegate?.onBluetoothReady()
    }
}

