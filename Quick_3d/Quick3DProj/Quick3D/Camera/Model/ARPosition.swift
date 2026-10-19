import Foundation
import SwiftUI
import simd

class ARPosition: ObservableObject {
    @Published var currentStep: ARPositionStepEnum = .tenMM
    
    @Published var positionX: Float = 0
    @Published var positionY: Float = 0
    @Published var positionZ: Float = 0
    
    @Published var positionXMm: Decimal = 0
    @Published var positionYMm: Decimal = 0
    @Published var positionZMm: Decimal = 0
    
    @Published var eulerAnglesX: Float = 0
    @Published var eulerAnglesY: Float = 0
    @Published var eulerAnglesZ: Float = 0
    
    @Published var eulerAnglesYDecimal: Decimal = 0
    
    @Published var scale: Float = 1.0
    @Published var scaleDecimal: Decimal = 100
    
//    init(
//        position: SIMD3<Float> = UserSession.shared.position,
//        eulerAngles: SIMD3<Float> = UserSession.shared.eulerAngles
//    ) {
//        self.positionX = position.x
//        self.positionY = position.y
//        self.positionZ = position.z
//        self.scale = 1.0
//        self.scaleDecimal = 100
//        
//        self.positionXMm = Decimal(string: "\(position.x * 1000)") ?? 0
//        self.positionYMm = Decimal(string: "\(position.y * 1000)") ?? 0
//        self.positionZMm = Decimal(string: "\(position.z * 1000)") ?? 0
//        
//        self.eulerAnglesX = eulerAngles.x.degrees
//        self.eulerAnglesY = eulerAngles.y.degrees
//        self.eulerAnglesZ = eulerAngles.z.degrees
//        
//        self.eulerAnglesYDecimal = eulerAngles.y.degrees.toDecimal
//    }
    
    func setFrom(position: SIMD3<Float>, eulerAngles: SIMD3<Float>, scale: Float) {
        self.positionX = position.x
        self.positionY = position.y
        self.positionZ = position.z
        self.positionXMm = Decimal(Double(position.x) * 1000)
        self.positionYMm = Decimal(Double(position.y) * 1000)
        self.positionZMm = Decimal(Double(position.z) * 1000)

        self.eulerAnglesX = eulerAngles.x.degrees
        self.eulerAnglesY = eulerAngles.y.degrees
        self.eulerAnglesZ = eulerAngles.z.degrees
        self.eulerAnglesYDecimal = Decimal(Double(eulerAngles.y.degrees))

        self.scale = scale
        self.scaleDecimal = Decimal(Double(scale * 100))
    }

    func updateUserSessionAndEvent(eventSetter: (SIMD3<Float>, SIMD3<Float>, Float) -> Void) {
        self.positionX = (self.positionXMm / 1000).floatValue
        self.positionY = (self.positionYMm / 1000).floatValue
        self.positionZ = (self.positionZMm / 1000).floatValue
        self.eulerAnglesY = self.eulerAnglesYDecimal.floatValue
        
        self.scale = (self.scaleDecimal / 100).floatValue
        
        let pos = SIMD3<Float>(positionX, positionY, positionZ)
        let eulerAngles = SIMD3<Float>(eulerAnglesX.radians, eulerAnglesY.radians, eulerAnglesZ.radians)
//        UserSession.shared.position = pos
//        UserSession.shared.eulerAngles = eulerAngles
        eventSetter(pos, eulerAngles, self.scale)
    }
    
//    func fetch() {
//        let position: SIMD3<Float> = UserSession.shared.position
//        let eulerAngles: SIMD3<Float> = UserSession.shared.eulerAngles
//        self.positionX = position.x
//        self.positionY = position.y
//        self.positionZ = position.z
//        
//        self.positionXMm = Decimal(string: "\(position.x * 1000)") ?? 0
//        self.positionYMm = Decimal(string: "\(position.y * 1000)") ?? 0
//        self.positionZMm = Decimal(string: "\(position.z * 1000)") ?? 0
//        
//        self.eulerAnglesX = eulerAngles.x.degrees
//        self.eulerAnglesY = eulerAngles.y.degrees
//        self.eulerAnglesZ = eulerAngles.z.degrees
//        
//        self.eulerAnglesYDecimal = eulerAngles.y.degrees.toDecimal
//        self.scaleDecimal = Decimal(string: "\(scale * 100)") ?? 100
//    }
}
