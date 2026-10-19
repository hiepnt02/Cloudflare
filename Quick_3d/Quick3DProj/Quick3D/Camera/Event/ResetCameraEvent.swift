//
//  ResetCameraEvent.swift
//  Quick3D
//
//  Created by HaNST on 10/10/25.
//

import Foundation
import simd
import SceneKit

class ResetCameraEvent: EventIdentity, CapturePreviewEvent {
    func call(_ context: CapturePreviewContext) {
        context.resetCamera()
    }
}
