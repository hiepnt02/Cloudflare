//
//  MotionManager.swift
//  Quick3D
//
//  Created by HaNST on 13/10/25.
//
import Foundation
import CoreMotion

class MotionManager {
    static let shared = MotionManager()
    private let manager = CMMotionManager()
    private let queue = OperationQueue() // Queue xử lý riêng
    
    public var acceleration = CurrentPublisher<CMAcceleration?>(nil)
    public var attitude = CurrentPublisher<CMAttitude?>(nil)
    private var isStarted = false

    func start() {
        guard !isStarted, manager.isDeviceMotionAvailable else { return }
        isStarted = true
        
        manager.deviceMotionUpdateInterval = 0.03 // 50Hz
        manager.startDeviceMotionUpdates(using: .xTrueNorthZVertical, to: queue) { [weak self] (data, error) in
            if let userAccel = data?.userAcceleration {
                self?.acceleration.send(userAccel)
            }
            if let attitude = data?.attitude {
                self?.attitude.send(attitude)
            }
        }
    }
    
    func stop() {
        manager.stopDeviceMotionUpdates()
        isStarted = false
    }
}
