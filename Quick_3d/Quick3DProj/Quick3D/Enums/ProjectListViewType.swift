//
//  ProjectListViewType.swift
//  Quick3D
//

import Foundation

enum ProjectListViewType: String, Codable {
    case grid
    case list

    // An unknown raw value from the server must not fail the whole UserSetting payload.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ProjectListViewType(rawValue: raw) ?? .grid
    }

    var isListView: Bool {
        self == .list
    }
}
