//
//  CaptureExportEvent.swift
//  Quick3D
//
//  Created by HaNST on 10/10/25.
//

import Foundation

class CaptureExportEvent: EventIdentity, CaptureEvent {

    func call(_ context: CaptureContext) {
        if (context.status != .paused) {
            context.handleAsync(error: NSError(domain: "ARCameraContext", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cannot export."]))
            return
        }
        
        Task {
            do {
                print("Exporting...")
                
                await MainActor.run {
                    context.changeStatus(.exporting)
                    context.delegate?.capture(CaptureSession.current, exportProgress: 0)
                }
                
                try await context.combine()
                
                let zipURL = try await CaptureSession.current?.export(onProgress: { progress in
                    Task { @MainActor in
                        context.delegate?.capture(CaptureSession.current, exportProgress: progress)
                    }
                })
                
                if let url = zipURL {
                    await MainActor.run {
                        context.delegate?.capture(CaptureSession.current, didExport: url)
                    }
                }
                
                context.changeStatus(.stopped)
                context.restart()
                
            } catch {
                context.handleAsync(error: error)
            }
        }
        
    }
    
}
