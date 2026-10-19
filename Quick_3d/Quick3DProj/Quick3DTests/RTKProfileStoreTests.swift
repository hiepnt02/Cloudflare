//
//  RTKProfileStoreTests.swift
//  Quick3DTests
//
//  QUICK-971 — áp profile xuống bộ cấu hình đang active.
//
//  GIỚI HẠN MÔI TRƯỜNG: bundle test chạy không ký nên Keychain không ghi được, mà
//  `UserSession.rtkConnectionProfiles` và `.ntripInfo` đều nằm ở Keychain. Vì vậy mọi thứ
//  cần round-trip Keychain (upsert → load, delete → chọn lại, migration) không tự động hoá
//  được ở đây và phải kiểm tra tay trên máy thật — xem ma trận test trong mô tả PR.
//  Phần dưới đây chỉ phủ nhánh ghi xuống UserDefaults, và đó đúng là nhánh đã từng sót key.
//

import XCTest
import VigramSDK
@testable import Quick3D

final class RTKProfileStoreTests: XCTestCase {

    private var savedMountPoint: String?
    private var savedCoordinate: CoordinateSystemNtripModel?
    private var savedProvider: NtripServiceProviderEnum = .other
    private var savedSegment: CameraOffsetEnum = .SPCPlus
    private var savedElevation: ElevationValue = .ang15
    private var savedGnss: Set<GNSSEnum> = []
    private var savedCustomOffset: SIMD3<Double> = .zero

    override func setUp() {
        super.setUp()
        let session = UserSession.shared
        savedMountPoint = session.mountPointNtrip
        savedCoordinate = session.coordinateSystemNtrip
        savedProvider = session.ntripServiceProvider
        savedSegment = session.cameraOffsetSegment
        savedElevation = session.elevation
        savedGnss = session.gnsss
        savedCustomOffset = session.customOffsetVidoc
    }

    override func tearDown() {
        let session = UserSession.shared
        session.mountPointNtrip = savedMountPoint
        session.coordinateSystemNtrip = savedCoordinate
        session.ntripServiceProvider = savedProvider
        session.cameraOffsetSegment = savedSegment
        session.elevation = savedElevation
        session.gnsss = savedGnss
        session.customOffsetVidoc = savedCustomOffset
        super.tearDown()
    }

    /// Áp đủ cấu hình và custom offset, nhưng bỏ qua loại rover cũ vì chỉ hỗ trợ viDoc.
    func testApplyToActiveConfigWritesEverySettingTheConnectPathReads() {
        let profile = RTKConnectionProfile(
            id: "x",
            name: "x",
            rtkDeviceType: .viDoc24,
            cameraOffsetSegment: .Custom,
            customOffset: SIMD3(0.011, -0.022, 0.033),
            ntripServiceProvider: .terasat,
            hostnameOrIp: "ntrip.terasat.co.jp",
            port: 5001,
            username: "user-x",
            password: "pass-x",
            mountPoint: "MP-X",
            coordinateSystem: CoordinateSystemNtripModel(code: "4326", name: "WGS84", id: "EPSG:4326"),
            elevation: .ang25,
            gnss: [.GPS, .QZSS]
        )

        RTKProfileStore.shared.applyToActiveConfig(profile)

        let session = UserSession.shared
        XCTAssertEqual(session.mountPointNtrip, "MP-X")
        XCTAssertEqual(session.coordinateSystemNtrip?.id, "EPSG:4326")
        XCTAssertEqual(session.ntripServiceProvider, .terasat)
        XCTAssertEqual(session.elevation, .ang25)
        XCTAssertEqual(session.gnsss, [.GPS, .QZSS])
        XCTAssertEqual(session.cameraOffsetSegment, .Custom)
        XCTAssertEqual(session.rtkTypeSelected, .viDoc, "profile cũ không được đổi bảng offset sang rover khác")
        XCTAssertEqual(session.customOffsetVidoc, SIMD3(0.011, -0.022, 0.033), "thiếu key này thì custom offset không bao giờ được lưu")
        // `ntripInfo` nằm ở Keychain nên không kiểm được ở đây — xem ghi chú đầu file.
    }

    /// Offset mà đường định vị thật sẽ dùng phải khớp với offset của profile vừa áp.
    func testActiveConfigFeedsTheSameOffsetTheProfileDeclares() {
        let custom = SIMD3<Double>(0.5, -0.25, 0.125)
        let profile = RTKConnectionProfile(
            id: "y",
            name: "y",
            rtkDeviceType: .viDoc,
            cameraOffsetSegment: .Custom,
            customOffset: custom,
            ntripServiceProvider: .other,
            hostnameOrIp: "h",
            port: 1,
            username: "u",
            password: "p",
            mountPoint: "MP",
            coordinateSystem: nil,
            elevation: .ang15,
            gnss: [.GPS]
        )

        RTKProfileStore.shared.applyToActiveConfig(profile)

        let resolved = AntennaOffsetResolver.offset(
            rtkType: UserSession.shared.rtkTypeSelected,
            offsetSegment: UserSession.shared.cameraOffsetSegment,
            custom: UserSession.shared.customOffsetVidoc
        )
        XCTAssertEqual(resolved, custom)
    }
}
