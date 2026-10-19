//
//  MetalPointCloud.swift
//  Quick3D
//
//  Created by HaNST on 6/11/25.
//

import Foundation
import Metal
import SceneKit

class MetalCameras {
    
    var data: [MetalCamera] = []
    
    let bufferSize: Int
    
    private var hasConnectedToRTK: Bool = false
    
    weak var session: CaptureSession?
    
    private let lock = NSLock()
    
    init(bufferSize: Int) {
        self.bufferSize = bufferSize
    }
 
    func append(_ frame: FrameMetadata) {
        lock.lock()
        defer {
            lock.unlock()
        }
        
        if frame.isRTK && !hasConnectedToRTK {
            hasConnectedToRTK = true
            data.forEach { $0.showAccuracy = true }
        }

        var item: MetalCamera? = data.last
        if item == nil || !item!.canAppend() {
            item?.showAccuracy = hasConnectedToRTK || frame.isRTK
            
            let ratio = Float(frame.width / frame.height)
            item = MetalManager.shared.makeCamera(size: bufferSize, width: 0.15, height: 0.1, ratio: ratio, showAccuracy: hasConnectedToRTK)
            data.append(item!)
            session?.livePreviewContext?.updateCameras()
        }
        
        item?.append(frame)
    }
    
    func resetHasConnectedRtk() {
        hasConnectedToRTK = false
    }
}

