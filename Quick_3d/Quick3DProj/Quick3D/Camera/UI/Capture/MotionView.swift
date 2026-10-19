//
//  MotionView.swift
//  Quick3D
//
//  Created by HungNT on 17/9/25.
//

import SwiftUI

struct MotionView: View {
    @AppStorage("isShowMovement")
    private var isShowMovement: Bool = UserSession.shared.isShowMovement
    @ObservedObject private var motionObject = MotionObject.shared
    
    private let sensitiveValue = 150.0
    private let ratioCircleLarge: Double = UserSession.isIPhone ? 0.3 : 0.2

    var body: some View {
        Group {
            if isShowMovement {
                GeometryReader { geometry in
                    let size = geometry.size
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let circleSize = min(size.width, size.height) * ratioCircleLarge
                    
                    Canvas { context, size in
                        // Vẽ vòng tròn lớn (tĩnh)
                        let rect = CGRect(origin: CGPoint(x: center.x - circleSize/2, y: center.y - circleSize/2),
                                         size: CGSize(width: circleSize, height: circleSize))
                        
                        var path = Path()
                        path.addEllipse(in: rect)
                        
                        context.stroke(path, with: .color(motionObject.data.isMoveFast ? .red : .gray), lineWidth: 3)
                        
                        // Tính toán offset
                        let accelX = UserSession.isIPhone ? motionObject.data.acceleration.x : -motionObject.data.acceleration.y
                        let accelY = UserSession.isIPhone ? -motionObject.data.acceleration.y : motionObject.data.acceleration.x
                        
                        let offsetX = calculateOffset(width: circleSize, acceleration: accelX)
                        let offsetY = calculateOffset(width: circleSize, acceleration: accelY)
                        
                        // Vẽ Dot nhỏ (động)
                        let dotRect = CGRect(x: center.x + offsetX - 5, y: center.y + offsetY - 5, width: 10, height: 10)
                        context.fill(Path(ellipseIn: dotRect), with: .color(.blue))
                    }
                    .animation(.interactiveSpring(), value: motionObject.data.acceleration.x)
                    .animation(.interactiveSpring(), value: motionObject.data.acceleration.y)
                }
            }
        }
        // Cho phép click xuyên qua toàn bộ view này
        .allowsHitTesting(false)
    }

    func calculateOffset(width: CGFloat, acceleration: Double) -> CGFloat {
        let maxOffset = width / 2.0
        let offset = acceleration * sensitiveValue
        return min(max(offset, -maxOffset), maxOffset)
    }
}
