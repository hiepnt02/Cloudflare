//
//  LocationManager.swift
//  Quick3D
//
//  Created by HaNST on 13/12/24.
//

import Foundation
import CoreLocation
import Combine
import CoreMotion
import SwiftUI

class LocationManager: NSObject, CLLocationManagerDelegate {
    
    static let shared = LocationManager()
    
    public let queue = DispatchQueue(label: "ltd.landlog.scquick3d.LocationManager", attributes: [])
    
    private let gpsManager = GPSManager.shared
    private let rtkManager = RTKManager.shared
    private let motionManager = MotionManager.shared
    
    private var _gpsLocation: ThreadSafeValue<LocationModel> = .init(LocationModel())
    private var _rtkLocation: ThreadSafeValue<LocationModel?> = .init(nil)
    private var _isGPSReady: ThreadSafeValue<Bool> = .init(false)
    private var _isRTKReady: ThreadSafeValue<Bool> = .init(false)
    
//    public var location = CurrentPublisher<LocationModel>(.init())
    private var _location: ThreadSafeValue<LocationModel> = .init(LocationModel())
    
    private var subscription = Set<AnyCancellable>()
    
    public var isRTK: Bool {
        _isRTKReady.value
    }
    
    public var isReady: Bool {
        _isGPSReady.value || _isRTKReady.value
    }
    
    public var gpsLocation: LocationModel {
        _gpsLocation.value
    }
    
    public var rtkLocation: LocationModel? {
        isRTK ? _rtkLocation.value : nil
    }
    
    public var location: LocationModel {
        _location.value
    }
    
    public var rtkId: String? {
        rtkManager.id
    }
    
    public var rtkSerialNumber: String? {
        rtkManager.serialNumber
    }
    
    override init() {
        super.init()
        setup()
    }
    
    func setup() {
        gpsManager.ready
            .receive(on: queue)
            .sink { [weak self] isReady in
                guard let s = self else {
                    return
                }
                s._isGPSReady.value = isReady
            }.store(in: &subscription)
        
        gpsManager.location
            .receive(on: queue)
            .sink { [weak self] location in
                guard let s = self else {
                    return
                }
                if !s.isRTK {
                    s._location.value = location
                }
                s._gpsLocation.value = location
            }.store(in: &subscription)
        
        rtkManager.ready
            .receive(on: queue)
            .sink { [weak self] isReady in
                guard let s = self else {
                    return
                }
                s._isRTKReady.value = isReady
            }.store(in: &subscription)
        
        rtkManager.location
            .receive(on: queue)
            .sink { [weak self] location in
                guard let s = self else {
                    return
                }
                s._location.value = location
                s._rtkLocation.value = location
            }.store(in: &subscription)
    }
    
    func start() {
        gpsManager.start()
        motionManager.start()
    }
    
    func stop() {
        gpsManager.stop()
        motionManager.stop()
    }
    
}
