//
//  Event.swift
//  Quick3D
//
//  Created by HaNST on 10/10/25.
//

import Foundation
import SceneKit

protocol Event {
    var id: Int { get }
}

protocol CapturePreviewEvent: Event {
    func call(_ context: CapturePreviewContext)
}

protocol ViewARPreviewEvent: Event {
    func call(_ context: ViewARPreviewContext)
}

protocol ViewAREvent: Event {
    func call(_ context: ViewARContext)
}

protocol ManualCalibrationEvent: Event {
    func call(_ context: ManualCalibrationContext)
}

protocol CaptureEvent: Event {
    func call(_ context: CaptureContext)
}

class EventIdentity: Event {
    
    private static var idCounter: Int = 0
    
    private static func nextId() -> Int {
        Self.idCounter += 1
        return Self.idCounter
    }
    
    private var _id: Int = -1
    
    var id: Int {
        _id
    }
    
    init() {
        self._id = Self.nextId()
    }
}
