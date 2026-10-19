//
//  CaptureCancelEvent.swift
//  Quick3D
//
//  Created by HaNST on 10/10/25.
//

import Foundation

class CaptureCancelEvent: EventIdentity, CaptureEvent {

    func call(_ context: CaptureContext) {
        Task {
            context.discard()
            await MainActor.run {
                context.start()
                context.changeStatus(.stopped)
            }
        }
    }
}
