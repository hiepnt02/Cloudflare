//
//  ThreadSafeValue.swift
//  Quick3D
//
//  Created by HaNST on 13/3/26.
//

import Foundation

class ThreadSafeValue<T> {
    
    private let lock = NSLock()

    private var _value: T
    
    public var value: T {
        set (v) {
            lock.lock()
            defer { lock.unlock() }
            _value = v
        }
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
    }
    
    init(_ value: T) {
        self._value = value
    }
    
}
