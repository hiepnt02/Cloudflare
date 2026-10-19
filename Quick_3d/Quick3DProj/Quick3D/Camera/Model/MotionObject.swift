//
//  MotionObject.swift
//  Quick3D
//
//  Created by HungNT on 17/9/25.
//

import Foundation
import Combine
import CoreMotion

struct MotionData {
    var acceleration: CMAcceleration = CMAcceleration(x: 0, y: 0, z: 0)
    var attitude: CMAttitude = CMAttitude()
    var isMoveFast: Bool = false
}

class MotionObject: ObservableObject {
    @Published var data = MotionData()
    
    private var subscription = Set<AnyCancellable>()
    
    // Sử dụng Singleton để dùng chung giữa các View
    static let shared = MotionObject()
    
    init() {
        configure()
    }
    
    func configure() {
        MotionManager.shared.acceleration
            .receive(on: RunLoop.main) // Đảm bảo update trên main thread cho UI
            .sink { [weak self] acceleration in
                guard let self = self, let a = acceleration else { return }
                
                let isFast = abs(a.x) > 0.4 || abs(a.y) > 0.4
                
                // Chỉ cập nhật 1 lần duy nhất cho tất cả thuộc tính
                self.data = MotionData(acceleration: a,
                                       attitude: self.data.attitude,
                                       isMoveFast: isFast)
            }
            .store(in: &subscription)
        MotionManager.shared.attitude
            .receive(on: RunLoop.main) // Đảm bảo update trên main thread cho UI
            .sink { [weak self] attitude in
                guard let self = self, let a = attitude else { return }
                
                self.data = MotionData(acceleration: self.data.acceleration,
                                       attitude: a,
                                       isMoveFast: self.data.isMoveFast)
            }
            .store(in: &subscription)
    }
}
