//
//  RTKObject.swift
//  Quick3D
//
//  Created by HaNST on 20/11/24.
//

import Foundation
import Combine
import VigramSDK
import CoreBluetooth
import CoreLocation

final class RTKObject: ObservableObject {
    
    static let shared = RTKObject()
    
    @Published var isReady: Bool = false

    @Published var isRecovering: Bool = false
    
    @Published var isWaitingForSignal: Bool = false
    
    @Published var state: RTKState = .disconnected

    /// Thiết bị đang kết nối và danh sách thiết bị quét được. Ở đây thay vì trên
    /// `RTKProfileDraft` vì vòng đời của chúng là cả phiên chạy app, còn draft chỉ sống
    /// trong một lần mở màn sửa profile.
    @Published var vidocConnected: Peripheral?
    @Published var devices: [CBPeripheral] = []

    @Published var location: LocationModel?
    @Published var accuracy: (horizontal: Double, vertical: Double) = (-1.0, -1.0)
    
    @Published var batteryMessage: DeviceMessage?
    @Published var satelliteMessageDOP: VigramSDK.SatelliteMessage.Dop?
    @Published var satelliteMessagePVT: VigramSDK.SatelliteMessage.Pvt?
    @Published var GGAMessage: GGAMessage?
    
    @Published var quality: RTKQuality = .invalid
    
    private var subscription = Set<AnyCancellable>()
    
    public var isConnecting: Bool {
        state == .connected
    }
    
    private init() {
        configure()
    }
    
    func configure() {
        
        RTKManager.shared.ready
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReady in
                self?.isReady = isReady
            }.store(in: &subscription)
        
        RTKManager.shared.isRecovering
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecovering in
                self?.isRecovering = isRecovering
            }.store(in: &subscription)
        
        RTKManager.shared.isWaitingForSignal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isWaitingForSignal in
                self?.isWaitingForSignal = isWaitingForSignal
            }.store(in: &subscription)
        
        RTKManager.shared.state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.state = state
                self?.vidocConnected = state == .connected ? RTKManager.shared.connectedDevice : nil
            }.store(in: &subscription)

        RTKManager.shared.devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.devices = devices
            }.store(in: &subscription)

        RTKManager.shared.location
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.location = location
            }.store(in: &subscription)
        
        RTKManager.shared.nmea
            .receive(on: DispatchQueue.main)
            .sink { [weak self] nmea in
                self?.quality = nmea.quality
                if let acc = nmea.accuracy {
                    self?.accuracy = acc
                }
                self?.satelliteMessageDOP = nmea.dop
                self?.satelliteMessagePVT = nmea.pvt
                self?.GGAMessage = nmea.gga
        }.store(in: &subscription)
        
        RTKManager.shared.deviceMessage
            .receive(on: DispatchQueue.main)
            .filter({ deviceMessage in
                if case .battery(_) = deviceMessage {
                    return true
                } else {
                    return false
                }
            }).sink { [weak self] deviceMessage in
                self?.batteryMessage = deviceMessage
            }.store(in: &subscription)
        
    }
    
}
