//
//  FrameOperation.swift
//  Quick3D
//
//  Created by HaNST on 5/3/26.
//

import Foundation

class FrameOperation: Job {

    public private(set) weak var session: CaptureSession?
    public private(set) var frame: FrameData?

    init(_ session: CaptureSession ,frame: FrameData) {
        self.session = session
        self.frame = frame
    }
    
    override func clear() {
        session = nil
        frame = nil
        super.clear()
    }
    
}
