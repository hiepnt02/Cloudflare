//
//  RTKConnectionProfile.swift
//  Quick3D
//
//  Created by MOR on 4/9/26.
//

import Foundation
import VigramSDK

/// Một bộ thông tin kết nối RTK đã lưu trên máy.
///
/// Lưu ở Keychain (xem `UserSession.rtkConnectionProfiles`) vì có chứa password NTRIP.
///
/// `elevation` và `gnss` giữ dạng raw: `ElevationValue` là enum `Int` của VigramSDK, khác
/// module nên `extension ElevationValue: Codable {}` không được synthesize; còn `gnss` đi
/// theo đúng cách `UserSession.gnsss` đang round-trip qua `[String]`.
struct RTKConnectionProfile: Codable, Identifiable, Equatable {
    var id: String
    var name: String

    var rtkDeviceType: RTKRoverEnum
    var cameraOffsetSegment: CameraOffsetEnum
    var offsetX: Double
    var offsetY: Double
    var offsetZ: Double

    var ntripServiceProvider: NtripServiceProviderEnum
    var hostnameOrIp: String
    var port: Int
    var username: String
    var password: String
    var mountPoint: String
    var coordinateSystem: CoordinateSystemNtripModel?

    var elevation: Int
    var gnss: [String]

    var createdAt: Date
    var lastConnectedAt: Date?

    init(
        id: String = UUID().uuidString,
        name: String,
        rtkDeviceType: RTKRoverEnum,
        cameraOffsetSegment: CameraOffsetEnum,
        customOffset: SIMD3<Double>,
        ntripServiceProvider: NtripServiceProviderEnum,
        hostnameOrIp: String,
        port: Int,
        username: String,
        password: String,
        mountPoint: String,
        coordinateSystem: CoordinateSystemNtripModel?,
        elevation: ElevationValue,
        gnss: Set<GNSSEnum>,
        createdAt: Date = Date(),
        lastConnectedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.rtkDeviceType = rtkDeviceType
        self.cameraOffsetSegment = cameraOffsetSegment
        self.offsetX = customOffset.x
        self.offsetY = customOffset.y
        self.offsetZ = customOffset.z
        self.ntripServiceProvider = ntripServiceProvider
        self.hostnameOrIp = hostnameOrIp
        self.port = port
        self.username = username
        self.password = password
        self.mountPoint = mountPoint
        self.coordinateSystem = coordinateSystem
        self.elevation = elevation.rawValue
        self.gnss = gnss.map(\.rawValue).sorted()
        self.createdAt = createdAt
        self.lastConnectedAt = lastConnectedAt
    }

    var customOffset: SIMD3<Double> {
        SIMD3(offsetX, offsetY, offsetZ)
    }

    var elevationValue: ElevationValue {
        ElevationValue(rawValue: elevation) ?? .ang15
    }

    var gnssSet: Set<GNSSEnum> {
        Set(gnss.compactMap(GNSSEnum.init))
    }

    /// Đủ thông tin để kết nối. Giữ đúng điều kiện mà nút kết nối dùng trước đây — một
    /// profile migrate từ bản cũ có thể thiếu hệ toạ độ hoặc là `.Custom` với offset 0.
    var isConnectable: Bool {
        !hostnameOrIp.isEmpty
            && port > 0
            && !username.isEmpty
            && !password.isEmpty
            && !mountPoint.isEmpty
            && coordinateSystem != nil
            && (cameraOffsetSegment != .Custom || customOffset != .zero)
    }

    var ntripInfo: NtripInfoModel {
        NtripInfoModel(username: username, password: password, port: port, hostnameOrIp: hostnameOrIp)
    }

    /// Bỏ qua `lastConnectedAt` khi so sánh dirty — nó đổi vì kết nối, không phải vì user sửa.
    static func == (lhs: RTKConnectionProfile, rhs: RTKConnectionProfile) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.rtkDeviceType == rhs.rtkDeviceType
            && lhs.cameraOffsetSegment == rhs.cameraOffsetSegment
            && lhs.offsetX == rhs.offsetX
            && lhs.offsetY == rhs.offsetY
            && lhs.offsetZ == rhs.offsetZ
            && lhs.ntripServiceProvider == rhs.ntripServiceProvider
            && lhs.hostnameOrIp == rhs.hostnameOrIp
            && lhs.port == rhs.port
            && lhs.username == rhs.username
            && lhs.password == rhs.password
            && lhs.mountPoint == rhs.mountPoint
            && lhs.coordinateSystem?.id == rhs.coordinateSystem?.id
            && lhs.elevation == rhs.elevation
            && lhs.gnss == rhs.gnss
    }
}
