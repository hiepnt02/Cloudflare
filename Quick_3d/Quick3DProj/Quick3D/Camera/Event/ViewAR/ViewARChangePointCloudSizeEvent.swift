//
//  ViewARChangePointCloudSizeEvent.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import Foundation

class ViewARChangePointCloudSizeEvent: EventIdentity, ViewAREvent {
    let scale: Double
    
    init(_ scale: Double) {
        self.scale = scale
    }
    
    func call(_ context: ViewARContext) {
        context.updatePointCloudSize(to: ARProjectHelper.pointCloudSize * scale)
    }
}
