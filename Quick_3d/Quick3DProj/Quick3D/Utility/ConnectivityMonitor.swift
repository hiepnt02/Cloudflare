//
//  ConnectivityMonitor.swift
//  Quick3D
//
//  Created by HungNT on 24/2/25.
//
import Foundation
import Network

class ConnectivityMonitor {
    public static let shared = ConnectivityMonitor()
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "ConnectivityMonitorQueue")

    // Use an internal property to store it.
    private var _isConnected: Bool = false

    // Guarded by a lock instead of `queue.sync`: every project cell reads this value
    // while rendering, and hopping to another queue for each read is expensive
    // (and can block the main thread while the monitor queue is busy).
    private let lock = NSLock()

    private var isConnected: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isConnected
        }
        set {
            lock.lock()
            _isConnected = newValue
            lock.unlock()
        }
    }

    init() {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let status = path.status == .satisfied
            self?.isConnected = status // Written through the queue
            
            // Only dispatch UI-related work to the main thread
            DispatchQueue.main.async {
                if status {
                    print("Internet connection available")
                } else {
                    print("No internet connection")
                }
            }
        }
        monitor.start(queue: queue)
    }

    func isCurrentlyConnected() -> Bool {
        return isConnected // Read through queue.sync
    }
    
    deinit {
        monitor.cancel()
    }
}
