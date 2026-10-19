//
//  NtripInfoModel.swift
//  Quick3D
//
//  Created by MOR on 21/1/25.
//

import Foundation

struct NtripInfoModel: Codable {
    var username: String
    var password: String
    var port: Int
    var hostnameOrIp: String
    
    init(username: String, password: String, port: Int, hostnameOrIp: String) {
        self.username = username
        self.password = password
        self.port = port
        self.hostnameOrIp = hostnameOrIp
    }
    
    init(username: String, password: String, port: String, hostnameOrIp: String) throws {
        
        guard let portNum = Int(port) else {
            throw NSError(domain: "NtripInfoModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "The port must be an integer."])
        }
        
        self.username = username
        self.password = password
        self.port = portNum
        self.hostnameOrIp = hostnameOrIp
    }
    
}

struct MountPointModel: Identifiable {
    var name: String
    var distance: String
    /// A caster can list the same mountpoint name more than once, and a recent
    /// entry is shown again in the full list, so identity cannot be the name.
    let id = UUID()
}

struct CoordinateSystemNtripModel: Identifiable, Codable {
    var code: String
    var name: String
    var id: String
}
