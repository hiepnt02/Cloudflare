//
//  GroupMode.swift
//  Quick3D
//
//  Created by HungNT on 24/6/26.
//

enum GroupMode: Int, CaseIterable {
    case year, month, day
    var title: String {
        switch self {
        case .year:
            return "YEAR"
        case .month:
            return "MONTH"
        case .day:
            return "DAY"
        }
    }
    var displayFormat: String {
        switch self {
        case .year:
            return "yyyy"
        case .month:
            return "yyyy/MM"
        case .day:
            return "yyyy/MM/dd"
        }
    }
    
    var enDisplayFormat: String {
        switch self {
        case .year:
            return "yyyy"
        case .month:
            return "MM/yyyy"
        case .day:
            return "dd/MM/yyyy"
        }
    }
}
