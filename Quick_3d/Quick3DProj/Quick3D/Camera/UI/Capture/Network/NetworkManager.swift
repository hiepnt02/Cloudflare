//
//  NetworkManager.swift
//  Quick3D
//
//  Created by HungNT on 29/1/26.
//

import Network
import Combine

class NetworkManager: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // @Published tự động thông báo cho SwiftUI khi giá trị thay đổi
    @Published var isConnected: Bool = false
    @Published var connectionType: String = "Unknown"

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            // Luôn cập nhật UI trên Main Thread
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.updateConnectionType(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func updateConnectionType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = "WiFi"
        } else if path.usesInterfaceType(.cellular) {
            connectionType = "Cellular"
        } else {
            connectionType = "Other"
        }
    }
}
