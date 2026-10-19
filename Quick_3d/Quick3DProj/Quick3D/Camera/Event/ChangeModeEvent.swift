//
//  ResetCameraEvent.swift
//  Quick3D
//
//  Created by HaNST on 10/10/25.
//

import Foundation
import SceneKit

class ChangeModeEvent: EventIdentity, CapturePreviewEvent {
    
    let isWorld: Bool
    
    init(_ isWorld: Bool) {
        self.isWorld = isWorld
    }
    
    func call(_ context: CapturePreviewContext) {
        context.isWorld = isWorld
        context.resetCamera()
    }
}
