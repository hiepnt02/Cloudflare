//
//  PermissionHelper.swift
//  Quick3D
//
//  Created by HaNST on 13/12/24.
//

import Foundation
import AVFoundation
import UIKit
import CoreLocation
import CoreBluetooth
import Combine
import CoreMotion

class PermissionHelper: NSObject, CBCentralManagerDelegate {
    
    static let shared = PermissionHelper()
    
    fileprivate var bluetoothUnauthorized: (() -> Void)?
    fileprivate var bluetoothPoweredOff: (() -> Void)?
    fileprivate var bluetoothPoweredOn: (() -> Void)?
    
    private var centralManager: CBCentralManager?
    
    private var bluetoothState: CBManagerState?
    
    private var subscription = Set<AnyCancellable>()
    
    override init() {
        super.init()
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        checkBluetooth()
    }
    
    func checkBluetooth() {
        if let state = bluetoothState {
            switch state {
            case .poweredOff:
                bluetoothPoweredOff?()
                break
            case .poweredOn:
                bluetoothPoweredOn?()
                break
            default:
                bluetoothUnauthorized?()
                break
            }
            bluetoothUnauthorized = nil
            bluetoothPoweredOff = nil
            bluetoothPoweredOn = nil
        }
    }
    
    func checkBluetooth(poweredOn: (() -> Void)?, unauthorized: (() -> Void)?, poweredOff: (() -> Void)?) {
        self.bluetoothUnauthorized = unauthorized
        self.bluetoothPoweredOn = poweredOn
        self.bluetoothPoweredOff = poweredOff
        
        if let _ = bluetoothState {
            checkBluetooth()
        }
    }
    
    func checkCamera(authorized: (() -> Void)?, unauthorized: (() -> Void)?) {
        let status =  AVCaptureDevice.authorizationStatus(for: .video)
        switch(status){
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video, completionHandler: {accessGranted in
                    if !accessGranted {
                        unauthorized?()
                    } else {
                        authorized?()
                    }
                })
                break
            case .denied:
                unauthorized?()
                break
            case .restricted, .authorized:
                authorized?()
                break
            @unknown default: break
        }
    }
    
    func checkLocation(authorized: (() -> Void)?, unauthorized: (() -> Void)?) {
        
        GPSManager.shared.authorizationStatus.sink { [weak self] status in
            guard let _self = self else { return }
            
            Task {
                await MainActor.run {
                    switch(status) {
                    case .notDetermined:
                        GPSManager.shared.requestWhenInUseAuthorization()
                        return
                    case .restricted, .authorizedAlways, .authorizedWhenInUse:
                        authorized?()
                    default:
                        unauthorized?()
                    }
                    _self.unsubscribe()
                }
            }
            
        }.store(in: &subscription)
        
    }
    
    func unsubscribe() {
        subscription.forEach { $0.cancel() }
        subscription.removeAll(keepingCapacity: true)
    }
    
    func checkMotion(completion: (()->Void)? = nil) {
        if CMMotionActivityManager.isActivityAvailable() {
            CMMotionActivityManager().queryActivityStarting(from: Date(), to: Date(), to: OperationQueue.main) { _, _ in
                completion?()
            }
        } else {
            completion?()
        }
    }
    
    func check(authorized: (()->Void)?, cameraUnauthorized: (()->Void)?, locationUnauthorized: (()->Void)?, bluetoothUnauthorized: (()->Void)?, bluetoothPoweredOff: (()->Void)?) {
        self.checkCamera(authorized: {
            self.checkLocation(authorized: {
                self.checkBluetooth(poweredOn: {
                    self.checkMotion(completion: authorized)
                }, unauthorized: bluetoothUnauthorized, poweredOff: bluetoothPoweredOff)
                
                if self.centralManager == nil {
                    let options = [CBCentralManagerOptionShowPowerAlertKey: true]
                    self.centralManager = CBCentralManager(delegate: self, queue: nil, options: options)
                }
            }, unauthorized: locationUnauthorized)
        }, unauthorized: cameraUnauthorized)
    }
}
