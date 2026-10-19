//
//  RTKProfileDraft.swift
//  Quick3D
//
//  Created by HaNST on 20/11/24.
//  Tách khỏi RTKStateObject cho QUICK-971.
//

import Foundation
import Combine
import VigramSDK
import CoreLocation

/// Bộ đệm sửa cho MỘT profile kết nối RTK.
///
/// Cố ý không giữ state kết nối live và không subscribe gì từ `RTKManager` — cái đó nằm ở
/// `RTKObject.shared`. Nếu trộn chung, rover rớt Bluetooth giữa lúc người dùng đang gõ sẽ
/// republish cả object, làm form vẽ lại, `TextField` mất first-responder, kéo theo handler
/// mất-focus chạy `validateOffset()` và đánh dấu draft là dirty dù người dùng không sửa gì.
///
/// Chỉ `apply()` ở màn nhập mới ghi xuống `RTKProfileStore`; chỉ nút kết nối mới ghi xuống
/// các key config đang active của `UserSession`.
final class RTKProfileDraft: ObservableObject {

    static let maxRecentMountpointsCount = 5

    let id: String

    @Published var name: String = ""

    @Published var cameraOffsetSegment: CameraOffsetEnum = .SPCPlus
    // Chỉ hỗ trợ viDoc, bỏ qua loại rover lưu từ phiên bản cũ.
    let rtkDeviceType: RTKRoverEnum = .viDoc
    @Published var customOffsetVidoc: SIMD3<Double> = .zero

    @Published var ntripServiceProvider: NtripServiceProviderEnum = .other
    @Published var hostnameNtrip: String = ""
    @Published var portNtrip: String = ""
    @Published var usernameNtrip: String = ""
    @Published var passwordNtrip: String = ""
    @Published var isNtripProviderStatus = false

    @Published var currentNtripCoordinateSystem: CoordinateSystemNtripModel?
    @Published var isNtripCoordinateSystemStatus = false

    @Published var currentMountpoint: String = ""
    @Published var isNtripMountpointStatus = false

    @Published var elevation: ElevationValue = .ang15
    @Published var gnss: Set<GNSSEnum> = [.GPS]

    @Published var mountpoints: [MountPointModel] = []

    /// Mountpoint đã chọn gần đây, mới nhất trước.
    @Published var recentMountpoints: [MountPointModel] = []

    @Published var isMountpointsFetched = false
    @Published var isMountpointsFetching = false

    @Published var ntripError: String? = nil

    private var fetchTask: Task<Void, Never>?

    private let createdAt: Date
    private let lastConnectedAt: Date?
    private var original: RTKConnectionProfile

    // MARK: - Khởi tạo

    /// Sửa một profile đã lưu.
    init(editing profile: RTKConnectionProfile) {
        self.id = profile.id
        self.createdAt = profile.createdAt
        self.lastConnectedAt = profile.lastConnectedAt
        self.original = profile
        hydrate(from: profile)
    }

    /// Tạo profile mới. Draft trắng phần NTRIP, nhưng mang sẵn ốp lưng và rover đang dùng —
    /// hai thứ đó mô tả phần cứng vật lý, không đổi theo caster.
    init(new: Void = ()) {
        self.id = UUID().uuidString
        self.createdAt = Date()
        self.lastConnectedAt = nil

        let seeded = RTKConnectionProfile(
            id: self.id,
            name: "",
            rtkDeviceType: UserSession.shared.rtkTypeSelected,
            cameraOffsetSegment: UserSession.shared.cameraOffsetSegment,
            customOffset: UserSession.shared.customOffsetVidoc,
            ntripServiceProvider: .other,
            hostnameOrIp: "",
            port: 0,
            username: "",
            password: "",
            mountPoint: "",
            coordinateSystem: nil,
            elevation: UserSession.shared.elevation,
            gnss: UserSession.shared.gnsss,
            createdAt: self.createdAt
        )

        self.original = seeded
        hydrate(from: seeded)
    }

    // MARK: - Snapshot / dirty / reset

    var snapshot: RTKConnectionProfile {
        RTKConnectionProfile(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            rtkDeviceType: rtkDeviceType,
            cameraOffsetSegment: cameraOffsetSegment,
            customOffset: customOffsetVidoc,
            ntripServiceProvider: ntripServiceProvider,
            hostnameOrIp: hostnameNtrip,
            port: Int(portNtrip) ?? 0,
            username: usernameNtrip,
            password: passwordNtrip,
            mountPoint: currentMountpoint,
            coordinateSystem: currentNtripCoordinateSystem,
            elevation: elevation,
            gnss: gnss,
            createdAt: createdAt,
            lastConnectedAt: lastConnectedAt
        )
    }

    /// Ô nhập offset chỉ giữ 3 chữ số thập phân, nên mở một profile Custom rồi thoát ngay
    /// sẽ lệch ở chữ số thứ tư và bị coi nhầm là đã sửa. So sánh offset có dung sai.
    var isDirty: Bool {
        let current = snapshot
        var baseline = original
        baseline.rtkDeviceType = rtkDeviceType

        if abs(current.offsetX - baseline.offsetX) < offsetEpsilon { baseline.offsetX = current.offsetX }
        if abs(current.offsetY - baseline.offsetY) < offsetEpsilon { baseline.offsetY = current.offsetY }
        if abs(current.offsetZ - baseline.offsetZ) < offsetEpsilon { baseline.offsetZ = current.offsetZ }

        return current != baseline
    }

    private let offsetEpsilon = 0.0005

    func reset() {
        hydrate(from: original)
    }

    /// Lưu vào kho và đặt làm profile đang chọn.
    func apply() {
        let profile = snapshot
        RTKProfileStore.shared.upsert(profile)
        original = profile
    }

    /// Đủ điều kiện lưu: đúng các điều kiện mà nút kết nối đang dùng, cộng thêm tên.
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !name.containsInvalidNtripCharacter
            && isNtripProviderStatus
            && isNtripCoordinateSystemStatus
            && isNtripMountpointStatus
            && !currentMountpoint.isEmpty
            && currentNtripCoordinateSystem != nil
            && (cameraOffsetSegment != .Custom || customOffsetVidoc != .zero)
    }

    private func hydrate(from profile: RTKConnectionProfile) {
        name = profile.name
        cameraOffsetSegment = profile.cameraOffsetSegment
        customOffsetVidoc = profile.customOffset
        ntripServiceProvider = profile.ntripServiceProvider
        hostnameNtrip = profile.hostnameOrIp
        portNtrip = profile.port == 0 ? "" : "\(profile.port)"
        usernameNtrip = profile.username
        passwordNtrip = profile.password
        currentMountpoint = profile.mountPoint
        currentNtripCoordinateSystem = profile.coordinateSystem
        elevation = profile.elevationValue
        gnss = profile.gnssSet

        // Một profile đã lưu là một profile đã validate — điều kiện lưu bắt buộc như vậy.
        let hasCredentials = !profile.hostnameOrIp.isEmpty && !profile.username.isEmpty
        isNtripProviderStatus = hasCredentials
        isNtripMountpointStatus = !profile.mountPoint.isEmpty
        isNtripCoordinateSystemStatus = profile.coordinateSystem != nil
        ntripError = nil

        applyProviderEndpointOverride()
    }

    /// Với provider khác `.other`, hostname/port là hằng số và hai ô đó bị khoá không cho
    /// sửa. Giữ override để profile đã lưu tự cập nhật nếu nhà cung cấp đổi endpoint — bỏ đi
    /// thì người dùng bị ghim vĩnh viễn vào một endpoint chết mà không sửa được.
    private func applyProviderEndpointOverride() {
        guard let hostname = ntripServiceProvider.hostname,
              let port = ntripServiceProvider.port else { return }

        guard hostname != hostnameNtrip || port != portNtrip else { return }

        hostnameNtrip = hostname
        portNtrip = port

        // Endpoint đã khác thì lần validate trước không còn giá trị, và mountpoint đã lưu
        // chưa chắc tồn tại trên caster mới.
        isNtripProviderStatus = false
        isNtripMountpointStatus = false
    }

    // MARK: - Mountpoint

    var allowNtripValid: Bool {
        !hostnameNtrip.isEmpty && !portNtrip.isEmpty && !usernameNtrip.isEmpty && !passwordNtrip.isEmpty
    }

    func applyNtripServiceProvider(_ provider: NtripServiceProviderEnum) {
        let isProviderChanged = provider != ntripServiceProvider

        ntripServiceProvider = provider

        if let hostname = provider.hostname, let port = provider.port {
            hostnameNtrip = hostname
            portNtrip = port
        } else if isProviderChanged {
            hostnameNtrip = ""
            portNtrip = ""
        }

        guard isProviderChanged else { return }

        cancelFetchingMountpoints()

        usernameNtrip = ""
        passwordNtrip = ""
        currentMountpoint = ""
        mountpoints = []
        recentMountpoints = []
        isMountpointsFetched = false
        isNtripProviderStatus = false
        isNtripMountpointStatus = false
        ntripError = nil
    }

    func cancelFetchingMountpoints() {
        fetchTask?.cancel()
        fetchTask = nil
        isMountpointsFetching = false
    }

    func fetchMountpoints(onCompletion: (([MountPointModel]) -> Void)? = nil, onError: ((Error) -> Void)? = nil) {

        cancelFetchingMountpoints()

        fetchTask = Task { @MainActor in
            if self.allowNtripValid && !self.isMountpointsFetching {
                self.isMountpointsFetching = true
                self.isMountpointsFetched = false
                self.ntripError = nil
                var result: [MountPointModel] = []

                do {
                    result = try await self.fetchMountpoints(hostname: hostnameNtrip, port: portNtrip, username: usernameNtrip, password: passwordNtrip)
                } catch {
                    self.ntripError = error.localizedDescription
                    onError?(error)
                }

                self.isMountpointsFetched = true
                self.isMountpointsFetching = false

                self.mountpoints = result

                if self.ntripError == nil {
                    self.syncRecentMountpoints(with: result)
                    onCompletion?(result)
                }
            }
        }
    }

    /// Drops history entries that are missing from the list returned by the last
    /// mountpoint verification, then rebuilds `recentMountpoints`.
    func syncRecentMountpoints(with fetched: [MountPointModel]) {
        let available = Set(fetched.map { $0.name })
        applyRecentMountpoints(
            UserSession.shared.recentMountPointNtrips.filter { available.contains($0) },
            from: fetched
        )
    }

    /// Moves the picked mountpoint to the top of the history, keeping at most
    /// `maxRecentMountpointsCount` entries.
    func saveRecentMountpoint(_ name: String) {
        var names = UserSession.shared.recentMountPointNtrips.filter { $0 != name }
        names.insert(name, at: 0)
        applyRecentMountpoints(Array(names.prefix(Self.maxRecentMountpointsCount)), from: mountpoints)
    }

    private func applyRecentMountpoints(_ names: [String], from source: [MountPointModel]) {
        UserSession.shared.recentMountPointNtrips = names
        recentMountpoints = names.compactMap { name in
            source.first { $0.name == name }
                .map { MountPointModel(name: $0.name, distance: $0.distance) }
        }
    }

    func fetchMountpoints(hostname: String, port: String, username: String, password: String) async throws -> [MountPointModel] {
        guard let publisher = RTKManager.shared.getMountpoints(hostname: hostname, port: Int(port) ?? 0, username: username, password: password) else {
            return []
        }

        var cancellable: AnyCancellable?

        defer {
            cancellable?.cancel()
        }

        let result: [MountPointModel] = try await withCheckedThrowingContinuation { continuation in
            cancellable = publisher
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { complition in
                    switch complition {
                    case .finished:
                        break
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }, receiveValue: { mountpoints in
                    let list = mountpoints.map {
                        let coord0 = CLLocation(latitude: $0.latitude ?? 0, longitude: $0.longitude ?? 0)
                        let coord1 = CLLocation(latitude: GPSManager.shared.location.value.latitude, longitude: GPSManager.shared.location.value.longitude)
                        let d = coord0.distance(from: coord1)
                        return MountPointModel(name: $0.name, distance: "\(Int(d/1000))km")
                    }.sorted {
                        $0.name < $1.name
                    }
                    continuation.resume(returning: list)
                })
        }

        return result
    }
}
