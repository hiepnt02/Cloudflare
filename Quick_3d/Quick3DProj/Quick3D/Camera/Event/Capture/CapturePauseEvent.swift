//
//  CapturePauseEvent.swift
//  Quick3D
//
//  Created by HaNST on 10/10/25.
//

import Foundation

class CapturePauseEvent: EventIdentity, CaptureEvent {

    let waitUntilCompleted: Bool
    
    init(_ waitUntilCompleted: Bool) {
        self.waitUntilCompleted = waitUntilCompleted
    }
    
    func call(_ context: CaptureContext) {
        if (context.status != .running && context.status != .pausing) {
            context.handleAsync(error: NSError(domain: "ARCameraContext", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cannot pause."]))
            return
        }
        
        context.changeStatus(.pausing)
        
        if waitUntilCompleted {
            Task {
                context.waitUntilCompleted()
                context.changeStatus(.paused)
            }
        }
    }
}
