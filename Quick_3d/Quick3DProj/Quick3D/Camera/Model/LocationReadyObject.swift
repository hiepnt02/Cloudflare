//
//  LocationReadyObject.swift
//  Quick3D
//
//  Created by HaNST on 19/1/26.
//

import Foundation
import Combine

public class LocationReadyObject: ObservableObject {
    
    @Published var gpsReady: Bool = false
    
    @Published var rtkReady: Bool = false
    
    private var subscription = Set<AnyCancellable>()
    
    init() {
        configure()
    }
    
    func configure() {
        GPSManager.shared.ready
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReady in
                self?.gpsReady = isReady
            }.store(in: &subscription)
        
        RTKManager.shared.ready
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReady in
                self?.rtkReady = isReady
            }.store(in: &subscription)
    }
}
