//
//  SortOption.swift
//  Quick3D
//

import Foundation

enum SortOption: String, Codable, CaseIterable, Hashable {
    case capturedDate = "create"
    case uploadDate = "upload"

    // An unknown raw value from the server must not fail the whole UserSetting payload.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SortOption(rawValue: raw) ?? .capturedDate
    }

    var localizationKey: String {
        switch self {
        case .capturedDate: return "SORT_CAPTURED_DATE"
        case .uploadDate: return "SORT_UPLOAD_DATE"
        }
    }

    // Also used as the date column title in ProjectColumnHeader
    func title(_ lang: String) -> String {
        localizationKey.localized(lang)
    }
}
