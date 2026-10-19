//
//  ConnectivityMonitor.swift
//  Quick3D
//
//  Created by HungNT on 24/2/25.
//
import Network

class ConnectivityMonitor {
    public static let shared = ConnectivityMonitor()
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "ConnectivityMonitorQueue")
    
    // Use an internal property to store it.
    private var _isConnected: Bool = false
    
    // Ensure that reading/writing this variable always occurs on the same queue.
    private var isConnected: Bool {
        get {
            return queue.sync { _isConnected }
        }
        set {
            queue.async { self._isConnected = newValue }
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
