//
//  AntennaOffsetResolver.swift
//  Quick3D
//
//  Created by MOR on 4/9/26.
//

import Foundation
import UIKit

/// Tra offset ăng-ten thuần tuý, không đọc `UserSession` và không cần kết nối.
///
/// Đường chạy thật vẫn đi qua `RTKGPSService.mapToAntennaOffset()` (đọc config đang active),
/// còn màn sửa profile gọi thẳng vào đây với giá trị của draft — nếu không tách, màn sửa
/// buộc phải ghi `UserSession` trước rồi đọc ngược lại, tức là sửa config đang chạy.
enum AntennaOffsetResolver {

    /// Mã máy không đổi trong suốt phiên chạy. Cache lại để không chạm `UIDevice.current`
    /// từ luồng nền — `ImageCalculator` và `CatchLog` gọi đường này ngoài main thread, còn
    /// code cũ chỉ gọi `uname()` trần.
    static let currentDeviceIdentifier: String = UIDevice.current.identifierRaw

    static func offset(
        rtkType: RTKRoverEnum,
        offsetSegment: CameraOffsetEnum,
        custom: SIMD3<Double>,
        deviceIdentifier: String = AntennaOffsetResolver.currentDeviceIdentifier
    ) -> SIMD3<Double> {
        switch offsetSegment {
        case .SPC:
            return offsetSPC[deviceIdentifier] ?? .zero
        case .SPCPlus:
            return spcPlus(rtkType: rtkType, deviceIdentifier: deviceIdentifier)
        case .CasetifySPCPlus:
            return offsetCasetifySPCPlus[deviceIdentifier] ?? .zero
        case .Custom:
            return custom
        }
    }

    private static func spcPlus(rtkType: RTKRoverEnum, deviceIdentifier: String) -> SIMD3<Double> {
        switch rtkType {
        case .viDoc:
            return offsetSPCPlus[deviceIdentifier] ?? .zero
        case .viDoc24:
            return offsetVidoc24[deviceIdentifier] ?? .zero
        case .viDocLight:
            return offsetVidocLight[deviceIdentifier] ?? .zero
        }
    }
}
