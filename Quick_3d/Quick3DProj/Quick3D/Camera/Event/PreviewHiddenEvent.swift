//
//  PreviewHiddenEvent.swift
//  Quick3D
//
//  Created by HaNST on 10/10/25.
//

import Foundation
import SceneKit

class PreviewHiddenEvent: EventIdentity, CapturePreviewEvent {
    
    let isCameraHidden: Bool

    let isPointCloudHidden: Bool
    
    init(isCameraHidden: Bool, isPointCloudHidden: Bool) {
        self.isCameraHidden = isCameraHidden
        self.isPointCloudHidden = isPointCloudHidden
    }
    
    func call(_ context: CapturePreviewContext) {
        context.frames?.isHidden = self.isCameraHidden
        context.points?.isHidden = self.isPointCloudHidden
    }
}
