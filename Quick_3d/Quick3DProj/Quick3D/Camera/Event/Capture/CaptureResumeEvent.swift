//
//  CaptureResumeEvent.swift
//  Quick3D
//
//  Created by HaNST on 10/10/25.
//

import Foundation

class CaptureResumeEvent: EventIdentity, CaptureEvent {

    func call(_ context: CaptureContext) {
        if context.status == .paused || context.status == .pausing {
            context.changeStatus(.running)
        } else {
            context.handleAsync(error: NSError(domain: "ARCameraContext", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cannot resume."]))
        }
    }
    
}
