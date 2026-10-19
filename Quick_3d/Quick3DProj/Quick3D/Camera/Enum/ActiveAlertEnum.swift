//
//  ActiveAlertEnum.swift
//  Quick3D
//
//  Created by HungNT on 8/6/26.
//

enum ActiveAlertEnum: Identifiable {
    case noNetwork
    case custom(title: String, message: String)
    
    // Bắt buộc có id để SwiftUI nhận diện khi dùng item-base alert
    var id: String {
        switch self {
        case .noNetwork: return "noNetwork"
        case .custom(let title, _): return title
        }
    }
    
    var title: String {
        switch self {
        case .noNetwork:
            return "noNetwork"
        case .custom(let title, _):
            return title
        }
    }
    
    var message: String {
        switch self {
        case .noNetwork:
            return "Please check your internet connection."
        case .custom(_, let message):
            return message
        }
    }
}
