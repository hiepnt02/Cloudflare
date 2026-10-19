//
//  CaptureStartEvent.swift
//  Quick3D
//
//  Created by HaNST on 10/10/25.
//

import Foundation
import SwiftUI

class CaptureStartEvent: EventIdentity, CaptureEvent {
    
    @AppStorage("previewPointSize")
    private var pointSize: String = "4"
    
    @AppStorage("previewSpacing")
    private var spacing: String = "20"
    
    private var isEnableMesh: Bool = UserSession.shared.isEnableMesh
    private var isSaveMesh: Bool = UserSession.shared.isSaveMesh
    private var imgResolution: ImageResolutionEnum = UserSession.shared.imageResolution
    
    func call(_ context: CaptureContext) {
        if context.status == .running {
            return
        }
        do {
            if !LocationManager.shared.isReady {
                throw NSError(domain: "ARCameraContext", code: 0, userInfo: [NSLocalizedDescriptionKey: "Session not ready."])
            }
            
            let spacing: Int
            
            switch imgResolution {
            case .normal:
                spacing = 30
            case .fourK:
                spacing = 60
            case .maximum:
                spacing = 60
            }
            
            context.resetDistances()
            try CaptureSession.start(LocationManager.shared.isRTK, pointCloudsSettings: (
                spacing,
                Int(pointSize) ?? 4
            ), isSaveMesh: isSaveMesh) { error in
                context.handleAsync(error: error)
            }
            context.meshNode.isHidden = !isEnableMesh
            context.changeStatus(.running)
        } catch {
            context.handleAsync(error: error)
        }
    }
    
}
