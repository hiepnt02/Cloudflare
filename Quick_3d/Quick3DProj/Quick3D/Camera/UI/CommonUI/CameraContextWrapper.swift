//
//  CameraContextWrapper.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import Foundation
import ARKit

class CameraContextWrapper<C: CameraContext>: CameraContext {
    typealias Delegate = C.Delegate

    var delegate: Delegate? {
        get { context?.delegate }
        set { context?.delegate = newValue }
    }
    
    var view: ARSCNView? {
        context?.view
    }
    
    private var context: C? = nil
    
    private var isStarted = false
    
    init(context: C?) {
        self.context = context
    }
    
    public func clear() {
        self.context?.clear()
        self.context = nil
    }
    
    public func setup(_ view: ARSCNView) {
        context?.setup(view)
    }
    
    func perform(_ event: any Event) {
        context?.perform(event)
    }
    
    func error(_ error: any Error) {
        context?.error(error)
    }
    
    func restart() {
        context?.restart()
    }
    
    func start() {
        context?.start()
    }
    
    func pause() {
        context?.pause()
    }
    
    func resume() {
        context?.resume()
    }
}
