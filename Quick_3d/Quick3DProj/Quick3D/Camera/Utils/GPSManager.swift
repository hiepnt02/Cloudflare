//
//  LocationManager.swift
//  Quick3D
//
//  Created by HaNST on 13/12/24.
//

import Foundation
import CoreLocation
import Combine
import SwiftUI

class GPSManager: NSObject, CLLocationManagerDelegate {
    
    static let shared = GPSManager()
    
    public let queue = DispatchQueue(label: "ltd.landlog.scquick3d.GPSManager", attributes: [])
    
    public let authorizationStatus = CurrentPublisher<CLAuthorizationStatus>(.notDetermined)
    
    public let location = CurrentPublisher<LocationModel>(.init())
    
    public let ready = CurrentPublisher<Bool>(false)
    
    public var isReady: Bool = false
    
    private var isStarted: Bool = false
    
    private var manager = CLLocationManager()
    
    private var timer: Timer?
    
    override init () {
        super.init()
        manager.delegate = self
        handleAuthorization(manager.authorizationStatus)
    }
    
    func start() {
        
        if isStarted {
            return
        }
        
        isStarted = true
        
        manager = .init()
        manager.delegate = self
        
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.startUpdatingLocation()
        //manager.startUpdatingHeading()
    }
    
    func stop() {
        manager.stopUpdatingLocation()
        //manager.stopUpdatingHeading()
        ready.send(false)
        isStarted = false
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let gps = locations.last {
            queue.async {
                let location = LocationModel(gps)
                
                self.ready.send(true)
                self.isReady = true
                self.location.send(location)

                let currentTime = Double(location.timestamp.timeIntervalSince1970)
                CaptureSession.current?.gpsLogger.log([String(format: "%.6f", currentTime),
                                                       "\(location.latitude)",
                                                       "\(location.longitude)",
                                                       "\(location.altitude)",
                                                       "\(location.horizontal)",
                                                       "\(location.vertical)",
                                                       "\(location.course)",
                                                       "\(location.courseAccuracy)"])
            }
        }
    }
    
//    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
//    }
    
    // Support check auth for iOS version < 14
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handleAuthorization(status)
    }

    // Support check auth for iOS version >= 14
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        handleAuthorization(status)
    }
    
    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        
        if self.authorizationStatus.value == status {
            return
        }
        
        if status != .notDetermined {
            timer?.invalidate()
            timer = nil
        }
        
        self.authorizationStatus.send(status)
    }
    
    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.handleAuthorization(self.manager.authorizationStatus)
        }
    }
}
