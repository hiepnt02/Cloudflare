//
//  NtripServiceProviderEnum.swift
//  Quick3D
//
//  Created by HaNST on 22/8/26.
//

import Foundation

/// Nhà cung cấp dịch vụ NTRIP (VRS). Mỗi case trừ `.other` gắn cứng một cặp
/// hostname/port; chọn provider sẽ tự điền và khoá hai ô đó ở phần nhập NTRIP.
enum NtripServiceProviderEnum: String, CaseIterable, Identifiable, Codable {
    case docomo = "DOCOMO"
    case softbank = "SOFTBANK"
    case jenoba = "JENOBA"
    case terasat = "TERASAT"
    case scEdge = "SC_EDGE"
    case scRover = "SC_ROVER"
    case other = "OTHER"

    var id: String { self.rawValue }

    /// Khoá dịch cho nhãn hiển thị trong pulldown.
    var localizedKey: String {
        switch self {
        case .docomo:
            return "RTK_NTRIP_PROVIDER_DOCOMO"
        case .softbank:
            return "RTK_NTRIP_PROVIDER_SOFTBANK"
        case .jenoba:
            return "RTK_NTRIP_PROVIDER_JENOBA"
        case .terasat:
            return "RTK_NTRIP_PROVIDER_TERASAT"
        case .scEdge:
            return "RTK_NTRIP_PROVIDER_SC_EDGE"
        case .scRover:
            return "RTK_NTRIP_PROVIDER_SC_ROVER"
        case .other:
            return "OTHER"
        }
    }

    /// `nil` với `.other` — người dùng tự nhập hostname.
    var hostname: String? {
        switch self {
        case .docomo:
            return "d-gnss.jp"
        case .softbank:
            return "ntrip.ales-corp.co.jp"
        case .jenoba:
            return "ntrip.jenoba.jp"
        case .terasat:
            return "ntrip.terasat.co.jp"
        case .scEdge, .scRover:
            return "rtcmsv.smartconstruction.com"
        case .other:
            return nil
        }
    }

    /// `nil` với `.other`. Terasat dùng cổng 5001, các provider còn lại dùng 2101.
    var port: String? {
        switch self {
        case .terasat:
            return "5001"
        case .docomo, .softbank, .jenoba, .scEdge, .scRover:
            return "2101"
        case .other:
            return nil
        }
    }

    /// Chỉ hai provider SmartConstruction cần nút hướng dẫn cạnh nhãn username.
    var showsUsernameHint: Bool {
        switch self {
        case .scEdge, .scRover:
            return true
        case .docomo, .softbank, .jenoba, .terasat, .other:
            return false
        }
    }

    /// Giá trị không nhận diện được (nil, khoá cũ, dữ liệu hỏng) đều về `.other`
    /// để người dùng vẫn nhập tay được thay vì bị khoá vào một provider sai.
    init(string: String?) {
        guard let string = string, let value = NtripServiceProviderEnum(rawValue: string) else {
            self = .other
            return
        }
        self = value
    }
}
