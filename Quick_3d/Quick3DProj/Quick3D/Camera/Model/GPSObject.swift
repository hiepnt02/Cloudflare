//
//  LocationManager.swift
//  Quick3D
//
//  Created by HaNST on 13/12/24.
//

import Foundation
import CoreLocation
import Combine

class GPSObject: ObservableObject {
    
    @Published var location: LocationModel?
    
    @Published var ready = false
    
    private var subscription = Set<AnyCancellable>()
    
    init() {
        configure()
    }
    
    func configure() {
        GPSManager.shared.location
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.location = location
            }.store(in: &subscription)
        
        GPSManager.shared.ready
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ready in
                self?.ready = ready
            }.store(in: &subscription)
    }
}
