//
//  RTKConnectionProfileTests.swift
//  Quick3DTests
//
//  QUICK-971 — model profile kết nối RTK và bảng tra offset ăng-ten.
//

import XCTest
import VigramSDK
@testable import Quick3D

final class RTKConnectionProfileTests: XCTestCase {

    // MARK: - Helper

    private func makeProfile(
        id: String = "p1",
        name: String = "Test",
        rtkDeviceType: RTKRoverEnum = .viDoc,
        cameraOffsetSegment: CameraOffsetEnum = .SPCPlus,
        customOffset: SIMD3<Double> = .zero,
        provider: NtripServiceProviderEnum = .other,
        hostnameOrIp: String = "d-gnss.jp",
        port: Int = 2101,
        username: String = "user",
        password: String = "pass",
        mountPoint: String = "MP1",
        coordinateSystem: CoordinateSystemNtripModel? = CoordinateSystemNtripModel(code: "6668", name: "JGD2011", id: "EPSG:6668"),
        elevation: ElevationValue = .ang15,
        gnss: Set<GNSSEnum> = [.GPS, .GALILEO]
    ) -> RTKConnectionProfile {
        RTKConnectionProfile(
            id: id,
            name: name,
            rtkDeviceType: rtkDeviceType,
            cameraOffsetSegment: cameraOffsetSegment,
            customOffset: customOffset,
            ntripServiceProvider: provider,
            hostnameOrIp: hostnameOrIp,
            port: port,
            username: username,
            password: password,
            mountPoint: mountPoint,
            coordinateSystem: coordinateSystem,
            elevation: elevation,
            gnss: gnss
        )
    }

    func testDraftIgnoresLegacyRoverWithoutMarkingUneditedProfileDirty() {
        for rover in [RTKRoverEnum.viDoc24, .viDocLight] {
            let draft = RTKProfileDraft(editing: makeProfile(rtkDeviceType: rover))
            XCTAssertEqual(draft.rtkDeviceType, .viDoc)
            XCTAssertEqual(draft.snapshot.rtkDeviceType, .viDoc)
            XCTAssertFalse(draft.isDirty)
            draft.name = "Changed"
            XCTAssertTrue(draft.isDirty)
            draft.reset()
            XCTAssertEqual(draft.rtkDeviceType, .viDoc)
            XCTAssertFalse(draft.isDirty)
        }
    }

    // MARK: - Codable

    /// Đây là hợp đồng lưu trữ: profile đi qua JSON vào Keychain rồi quay lại phải y nguyên.
    func testCodableRoundTripPreservesEveryField() throws {
        let original = makeProfile(
            rtkDeviceType: .viDoc24,
            cameraOffsetSegment: .Custom,
            customOffset: SIMD3(0.041, -0.037, 0.02),
            provider: .terasat,
            elevation: .ang30,
            gnss: [.GPS, .QZSS, .GLONASS, .BEIDOU]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RTKConnectionProfile.self, from: data)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.rtkDeviceType, .viDoc24)
        XCTAssertEqual(decoded.cameraOffsetSegment, .Custom)
        XCTAssertEqual(decoded.customOffset, SIMD3(0.041, -0.037, 0.02))
        XCTAssertEqual(decoded.ntripServiceProvider, .terasat)
        XCTAssertEqual(decoded.coordinateSystem?.id, "EPSG:6668")
    }

    /// `ElevationValue` là enum Int của VigramSDK, khác module nên không synthesize được
    /// Codable — profile lưu raw Int. Kiểm tra chuyển đổi hai chiều không lệch.
    func testElevationSurvivesRawIntRoundTrip() throws {
        for value in [ElevationValue.ang0, .ang5, .ang15, .ang40] {
            let profile = makeProfile(elevation: value)
            let decoded = try JSONDecoder().decode(
                RTKConnectionProfile.self,
                from: try JSONEncoder().encode(profile)
            )
            XCTAssertEqual(decoded.elevationValue, value, "elevation \(value) bị lệch")
        }
    }

    /// Raw value lạ (dữ liệu hỏng, hoặc SDK đổi enum) không được làm crash — rơi về mặc định.
    func testUnknownElevationRawFallsBackToDefault() {
        var profile = makeProfile()
        profile.elevation = 9999
        XCTAssertEqual(profile.elevationValue, .ang15)
    }

    func testGnssSetRoundTripsAndIgnoresUnknownValues() throws {
        var profile = makeProfile(gnss: [.GPS, .BEIDOU])
        XCTAssertEqual(profile.gnssSet, [.GPS, .BEIDOU])

        profile.gnss = ["GPS", "SBAS", "GALILEO"]
        // SBAS không có trong GNSSEnum (app hardcode sbassActivate: false), phải bị bỏ qua
        // chứ không được làm hỏng cả tập.
        XCTAssertEqual(profile.gnssSet, [.GPS, .GALILEO])
    }

    // MARK: - isConnectable

    func testFullyFilledProfileIsConnectable() {
        XCTAssertTrue(makeProfile().isConnectable)
    }

    /// Profile migrate từ bản cũ có thể thiếu hệ toạ độ. Nút kết nối phải chặn.
    func testProfileWithoutCoordinateSystemIsNotConnectable() {
        XCTAssertFalse(makeProfile(coordinateSystem: nil).isConnectable)
    }

    /// Trường hợp nguy hiểm nhất: .Custom với offset 0 sẽ nối mà không hiệu chỉnh lever-arm.
    func testCustomOffsetOfZeroIsNotConnectable() {
        XCTAssertFalse(makeProfile(cameraOffsetSegment: .Custom, customOffset: .zero).isConnectable)
        XCTAssertTrue(makeProfile(cameraOffsetSegment: .Custom, customOffset: SIMD3(0, 0, 0.02)).isConnectable)
    }

    /// Offset 0 chỉ là vấn đề với .Custom — các segment khác tra bảng theo máy.
    func testZeroOffsetIsFineForNonCustomSegments() {
        XCTAssertTrue(makeProfile(cameraOffsetSegment: .SPCPlus, customOffset: .zero).isConnectable)
    }

    func testMissingCredentialFieldsBlockConnect() {
        XCTAssertFalse(makeProfile(hostnameOrIp: "").isConnectable)
        XCTAssertFalse(makeProfile(port: 0).isConnectable)
        XCTAssertFalse(makeProfile(username: "").isConnectable)
        XCTAssertFalse(makeProfile(password: "").isConnectable)
        XCTAssertFalse(makeProfile(mountPoint: "").isConnectable)
    }

    // MARK: - Equatable

    /// `lastConnectedAt` đổi vì kết nối, không phải vì người dùng sửa — nếu tính vào so sánh
    /// thì mở một profile đã từng kết nối rồi thoát sẽ bị hỏi "chưa lưu thay đổi".
    func testEqualityIgnoresLastConnectedAt() {
        var a = makeProfile()
        var b = makeProfile()
        a.lastConnectedAt = Date(timeIntervalSince1970: 0)
        b.lastConnectedAt = Date(timeIntervalSince1970: 99999)
        XCTAssertEqual(a, b)
    }

    func testEqualityDetectsEveryUserEditableField() {
        let base = makeProfile()
        XCTAssertNotEqual(base, makeProfile(name: "Khác"))
        XCTAssertNotEqual(base, makeProfile(rtkDeviceType: .viDocLight))
        XCTAssertNotEqual(base, makeProfile(cameraOffsetSegment: .SPC))
        XCTAssertNotEqual(base, makeProfile(provider: .docomo))
        XCTAssertNotEqual(base, makeProfile(hostnameOrIp: "other.jp"))
        XCTAssertNotEqual(base, makeProfile(port: 5001))
        XCTAssertNotEqual(base, makeProfile(username: "u2"))
        XCTAssertNotEqual(base, makeProfile(password: "p2"))
        XCTAssertNotEqual(base, makeProfile(mountPoint: "MP2"))
        XCTAssertNotEqual(base, makeProfile(elevation: .ang40))
        XCTAssertNotEqual(base, makeProfile(gnss: [.GPS]))
        XCTAssertNotEqual(
            base,
            makeProfile(coordinateSystem: CoordinateSystemNtripModel(code: "4326", name: "WGS84", id: "EPSG:4326"))
        )
    }

    func testNtripInfoMirrorsCredentials() {
        let info = makeProfile(hostnameOrIp: "h", port: 1, username: "u", password: "p").ntripInfo
        XCTAssertEqual(info.hostnameOrIp, "h")
        XCTAssertEqual(info.port, 1)
        XCTAssertEqual(info.username, "u")
        XCTAssertEqual(info.password, "p")
    }
}

// MARK: - AntennaOffsetResolver

final class AntennaOffsetResolverTests: XCTestCase {

    /// Máy có mặt trong cả ba bảng SPC / SPC+ / viDoc24 nên so sánh được các nhánh.
    private let iPhone14Pro = "iPhone15,2"

    func testCustomSegmentReturnsSuppliedOffsetAndIgnoresTables() {
        let custom = SIMD3<Double>(1, 2, 3)
        XCTAssertEqual(
            AntennaOffsetResolver.offset(
                rtkType: .viDoc, offsetSegment: .Custom, custom: custom, deviceIdentifier: iPhone14Pro
            ),
            custom
        )
        // Kể cả máy không có trong bảng nào.
        XCTAssertEqual(
            AntennaOffsetResolver.offset(
                rtkType: .viDoc, offsetSegment: .Custom, custom: custom, deviceIdentifier: "khong-ton-tai"
            ),
            custom
        )
    }

    func testSpcSegmentReadsSpcTable() {
        XCTAssertEqual(
            AntennaOffsetResolver.offset(
                rtkType: .viDoc, offsetSegment: .SPC, custom: .zero, deviceIdentifier: iPhone14Pro
            ),
            offsetSPC[iPhone14Pro]
        )
    }

    /// Chỉ `.SPCPlus` mới tra theo loại rover — đây là nhánh dễ hỏng nhất khi tách hàm.
    func testSpcPlusPicksTablePerRoverType() {
        XCTAssertEqual(
            AntennaOffsetResolver.offset(rtkType: .viDoc, offsetSegment: .SPCPlus, custom: .zero, deviceIdentifier: iPhone14Pro),
            offsetSPCPlus[iPhone14Pro]
        )
        XCTAssertEqual(
            AntennaOffsetResolver.offset(rtkType: .viDoc24, offsetSegment: .SPCPlus, custom: .zero, deviceIdentifier: iPhone14Pro),
            offsetVidoc24[iPhone14Pro]
        )
        XCTAssertEqual(
            AntennaOffsetResolver.offset(rtkType: .viDocLight, offsetSegment: .SPCPlus, custom: .zero, deviceIdentifier: iPhone14Pro),
            offsetVidocLight[iPhone14Pro]
        )
    }

    /// Loại rover không được ảnh hưởng tới các segment khác `.SPCPlus`.
    func testRoverTypeIsIgnoredOutsideSpcPlus() {
        let a = AntennaOffsetResolver.offset(rtkType: .viDoc, offsetSegment: .SPC, custom: .zero, deviceIdentifier: iPhone14Pro)
        let b = AntennaOffsetResolver.offset(rtkType: .viDoc24, offsetSegment: .SPC, custom: .zero, deviceIdentifier: iPhone14Pro)
        XCTAssertEqual(a, b)
    }

    /// Máy không có trong bảng phải ra 0 chứ không crash — code cũ dùng `?? SIMD3(0,0,0)`.
    func testUnknownDeviceFallsBackToZero() {
        for segment in [CameraOffsetEnum.SPC, .SPCPlus, .CasetifySPCPlus] {
            XCTAssertEqual(
                AntennaOffsetResolver.offset(
                    rtkType: .viDoc, offsetSegment: segment, custom: SIMD3(9, 9, 9), deviceIdentifier: "iPhone0,0"
                ),
                .zero,
                "segment \(segment) phải trả 0 cho máy lạ"
            )
        }
    }

    /// Mã máy được cache lúc khởi tạo để không chạm `UIDevice.current` từ luồng nền.
    func testCachedDeviceIdentifierIsNotEmpty() {
        XCTAssertFalse(AntennaOffsetResolver.currentDeviceIdentifier.isEmpty)
    }
}
