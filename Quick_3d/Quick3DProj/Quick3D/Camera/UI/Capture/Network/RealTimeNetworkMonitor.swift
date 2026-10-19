//
//  RealTimeNetworkMonitor.swift
//  Quick3D
//
//  Created by HungNT on 29/1/26.
//

import Foundation

struct NetworkSpeedBytes {
    var bytesIn: UInt64
    var bytesOut: UInt64
}

class RealTimeNetworkMonitor: ObservableObject {
    @Published var downloadSpeed: String = "0 KB/s"
    @Published var uploadSpeed: String = "0 KB/s"
    
    private var timer: Timer?
    private var lastBytes: NetworkSpeedBytes?
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let currentBytes = self.getNetworkBytes()
            
            if let last = self.lastBytes {
                let diffIn = currentBytes.bytesIn > last.bytesIn ? currentBytes.bytesIn - last.bytesIn : 0
                let diffOut = currentBytes.bytesOut > last.bytesOut ? currentBytes.bytesOut - last.bytesOut : 0
                
                DispatchQueue.main.async {
                    self.downloadSpeed = self.formatBytes(diffIn)
                    self.uploadSpeed = self.formatBytes(diffOut)
                }
            }
            self.lastBytes = currentBytes
        }
    }
    
    private func getNetworkBytes() -> NetworkSpeedBytes {
        var bIn: UInt64 = 0
        var bOut: UInt64 = 0
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return NetworkSpeedBytes(bytesIn: 0, bytesOut: 0) }
        
        var ptr = ifaddr
        while ptr != nil {
            let name = String(cString: ptr!.pointee.ifa_name)
            // en0 là WiFi, pdp_ip0 là Cellular
            if ptr!.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                if let data = ptr!.pointee.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self)
                    bIn += UInt64(networkData.pointee.ifi_ibytes)
                    bOut += UInt64(networkData.pointee.ifi_obytes)
                }
            }
            ptr = ptr!.pointee.ifa_next
        }
        freeifaddrs(ifaddr)
        return NetworkSpeedBytes(bytesIn: bIn, bytesOut: bOut)
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 {
            return String(format: "%.1f KB/s", kb)
        } else {
            let mb = kb / 1024
            return String(format: "%.1f MB/s", mb)
        }
    }
}
