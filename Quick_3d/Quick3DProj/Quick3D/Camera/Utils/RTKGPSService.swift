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


final class RTKGPSService: RTKTemplate {
    private var service: GPSService?
    private var device: Peripheral?
    private var environmentDataService: EnvironmentDataService?
    
    private var subscription = Set<AnyCancellable>()
    
    let data = CurrentPublisher<EnvironmentData?>(nil)
    
    private func setError(_ value: Error) {
        self.manager?.error.send(RTKError(level: .ntrip, error: value))
    }
    
    func reset() {
        subscription.forEach { $0.cancel() }
        subscription.removeAll(keepingCapacity: true)
        
        service = nil
        device = nil
        environmentDataService = nil
        
//        location.send(.init())
        
        data.send(nil)
    }
    
    func reconect() -> Bool {
        guard let s = service else {
            return false
        }
        s.reconnect()
        return true
    }
    
    func setService(service: GPSService, device: Peripheral) {
        reset()
        self.service = service
        self.device = device
        setup()
    }
    
    func setup() {
        guard let gpsService = service, let peripheral = device else { return }

        environmentDataService = Vigram.environmentDataService (
            gpsService: gpsService,
            peripheral: peripheral,
            dynamicStateType: .pedestrian
        )
        
        if let environmentDataService = self.environmentDataService {
            var offset = mapToAntennaOffset()
            offset.y -= (VigramSDK.Configuration.middleAntenna * 0.01)
            let method = CoordinateCorrection.Method.device(antennaOffset: offset)
            
            environmentDataService.record(updateInterval: 0.1, with: method)
                .receive(on: queue)
                .sink { [weak self] completion in
                    switch completion {
                    case .failure(let error):
                        if Configuration.debug {
                            print("[DATA]: \(error.localizedDescription)")
                            self?.setError(error)
                        }
                    case .finished:
                        break
                    }
                } receiveValue: { [weak self] data in
                    self?.manager?.location.send(
                        LocationModel(
                            data,
                            coordinate: UserSession.shared.coordinateSystemNtrip?.id ?? defaultCoordinate
                        )
                    )
                    self?.data.send(data)
                }
            
            .store(in: &subscription)
        }
        
    }
    
    func mapToAntennaOffset() -> SIMD3<Double> {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        var offset = SIMD3<Double>(0, 0, 0)
        
        let caseType = UserSession.shared.cameraOffsetSegment
        switch caseType {
        case .SPC:
            offset = offsetSPC[identifier] ?? SIMD3<Double>(0.0, 0.0, 0.0)
        case .SPCPlus:
            offset = getOffsetSPCPlus(identifier)
        case .CasetifySPCPlus:
            offset = offsetCasetifySPCPlus[identifier] ?? SIMD3<Double>(0.0, 0.0, 0.0)
        case .Custom:
            offset = UserSession.shared.customOffsetVidoc
        }
        
        return offset
    }
    
    private func getOffsetSPCPlus(_ identifier: String) -> SIMD3<Double> {
        var offset = SIMD3<Double>(0, 0, 0)
        
        let rtkType = UserSession.shared.rtkTypeSelected
        switch rtkType {
        case .viDoc:
            offset = offsetSPCPlus[identifier] ?? SIMD3<Double>(0.0, 0.0, 0.0)
        case .viDoc24:
            offset = offsetVidoc24[identifier] ?? SIMD3<Double>(0.0, 0.0, 0.0)
        case .viDocLight:
            offset = offsetVidocLight[identifier] ?? SIMD3<Double>(0.0, 0.0, 0.0)
        }
        
        return offset
    }
}
