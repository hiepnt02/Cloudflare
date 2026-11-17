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
    
    public var isReady: Bool {
        rtkDevice.isReady
    }
    
    public var hasReceivedNmea: Bool {
        rtkDevice.hasReceivedNmea
    }
    
    private var isDisconnecting = false
    
    private var lostSignalTimer: Timer?
    
    /// Kept out of `subscription`: that set is cleared on every stop/start scan.
    private var stateSubscription: AnyCancellable?
    
    /// Also kept out of `subscription`, the other way round: stopping a scan must
    /// not cancel a connect that is already in flight.
    private var scanSubscription: AnyCancellable?

    private var isScanning = false
    private var emittedDeviceIDs = Set<UUID>()
    
    override init(manager: RTKManager? = nil) {
        self.rtkDevice = RTKDevice(manager: manager)
        super.init(manager: manager)
        self.rtkDevice.delegate = self
    }
    
    func setup() {
        self.service = Vigram.bluetoothService()
        observeBluetoothState()
    }
    
    private func observeBluetoothState() {
        stateSubscription = service?.state()
            .receive(on: queue)
            .sink { [weak self] state in
                self?.logger?.logInfo("BLUETOOTH", "Manager state \(state.rawValue)")
                // A scan started before the freshly created manager is powered on can be dropped.
                self?.manager?.isBluetoothReady.send(state == .poweredOn)
            }
    }
    
    public func scanDevices() {
        DispatchQueue.main.async {
            self.stopScanDevices()
            self.startScan()
        }
    }

    private func startScan() {
        DispatchQueue.main.async {
            guard !self.isScanning else { return }

            self.isScanning = true
            self.emittedDeviceIDs.removeAll(keepingCapacity: true)
            self.logger?.logInfo("BLUETOOTH", "Scanning...")
            self.scanSubscription = self.service?.observeAvailableDevices()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] devices in
                    guard let self else { return }
                    guard self.isScanning else { return }
                    let deviceIDs = Set(devices.map(\.identifier))
                    guard deviceIDs != self.emittedDeviceIDs else { return }
                    self.emittedDeviceIDs = deviceIDs
                    self.logger?.logInfo("BLUETOOTH", "Found \(devices.count) device(s): \(devices.map { $0.name ?? $0.identifier.uuidString }.joined(separator: ", "))")
                    self.manager?.devices.send(devices)
                }
            self.service?.startScan()
        }
    }
    
    public func stopScanDevices() {
        DispatchQueue.main.async {
            self.isScanning = false
            self.scanSubscription = nil
            self.emittedDeviceIDs.removeAll(keepingCapacity: true)
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
    
    /// For a peripheral that never connected: the SDK sends no state change for it, so the
    /// disconnected callback that normally resets this service never arrives.
    func abandonConnection() {
        DispatchQueue.main.async {
            self.service?.disconnect()
        }
        reset()
    }
    
    public func disconnect() {
        // Nothing connected or pending: the SDK call could only cancel a reconnect that starts right after.
        guard rtkDevice.device != nil else { return }
        // When the link already dropped (viDoc switched off), no disconnected callback follows to clear
        // the flag, and a stale flag would cut the next connection the moment it comes up.
        if rtkDevice.state != .disconnected {
            isDisconnecting = true
        }
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
        isDisconnecting = false
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
                    _self.manager?.onBluetoothConnectFailed()
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

