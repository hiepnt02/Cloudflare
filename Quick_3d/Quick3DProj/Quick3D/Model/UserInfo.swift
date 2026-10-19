//
//  UserInfo.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 21/04/2022.
//

import AVFoundation

struct UserInfo: Codable {
    var email: String
    var name: String
    var language: String?
    var userId: String?
    var corporationId: String?
    var emailWidth: CGFloat {
        return email.width(with: .systemFont(ofSize: 19))
    }
    var picture: String?
}

struct User: Codable, Hashable {
    var userId: String?
    var name: String
}

// Wrapper to handle common API response shapes
struct UserList: Decodable {
    let users: [User]
}

