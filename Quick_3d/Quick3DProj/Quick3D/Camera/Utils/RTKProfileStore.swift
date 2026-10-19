//
//  RTKProfileStore.swift
//  Quick3D
//
//  Created by MOR on 4/9/26.
//

import Foundation
import VigramSDK

/// Kho profile kết nối RTK.
///
/// Nằm *trên* các key config đang active của `UserSession`, không thay thế chúng: toàn bộ
/// đường kết nối (`RTKManager`, `RTKGPSService`, `RTKDevice`, `ViewARContext`,
/// `ImageCalculator`, `CatchLog`, và nhất là `RTKAutoConnectionHelper` chạy khi mở camera)
/// vẫn đọc `UserSession.shared.*`. Chọn profile rồi bấm kết nối = ghi profile xuống các key
/// đó qua `applyToActiveConfig(_:)` rồi gọi `RTKManager.connectTo` như cũ.
final class RTKProfileStore: ObservableObject {

    static let shared = RTKProfileStore()

    @Published private(set) var profiles: [RTKConnectionProfile] = []
    @Published private(set) var selectedId: String?

    var selected: RTKConnectionProfile? {
        profiles.first { $0.id == selectedId }
    }

    private init() {
        load()
    }

    // MARK: - Đọc / ghi

    func load() {
        let stored = UserSession.shared.rtkConnectionProfiles ?? []

        // QUICK-1060: profile nào cũng phải qua `RTKProfileDraft.canSave` (bắt buộc có
        // Mountpoint + hệ toạ độ) trước khi lưu — trừ profile do `migrateIfNeeded()` dựng, hàm
        // đó từng ghi thẳng không validate. Một profile thiếu hai trường này trong storage chỉ
        // có thể là rác migrate từ bản cũ; dọn luôn ở đây để máy đã dính lỗi tự hồi phục mà
        // không cần người dùng vào xoá tay.
        let complete = stored.filter { !$0.mountPoint.isEmpty && $0.coordinateSystem != nil }
        if complete.count != stored.count {
            UserSession.shared.rtkConnectionProfiles = complete
        }

        profiles = complete
        let storedId = UserSession.shared.selectedRTKProfileId
        selectedId = profiles.contains { $0.id == storedId } ? storedId : mostRecentlyConnectedId
    }

    /// Mặc định chọn sẵn card đã kết nối gần nhất; chưa card nào từng kết nối thì lấy card đầu.
    private var mostRecentlyConnectedId: String? {
        let connected = profiles.compactMap { profile -> (String, Date)? in
            profile.lastConnectedAt.map { (profile.id, $0) }
        }
        return connected.max { $0.1 < $1.1 }?.0 ?? profiles.first?.id
    }

    /// Thêm mới hoặc cập nhật tại chỗ, rồi đặt luôn làm profile đang chọn — sau khi lưu ở
    /// màn nhập thì mục vừa lưu phải ở trạng thái được chọn.
    func upsert(_ profile: RTKConnectionProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        persistProfiles()
        select(id: profile.id)
    }

    func delete(id: String) {
        profiles.removeAll { $0.id == id }
        persistProfiles()

        if selectedId == id {
            select(id: mostRecentlyConnectedId)
        }
    }

    /// Chọn profile là đổi luôn bộ cấu hình đang active, giữ bất biến
    /// "profile đang chọn == config mà lần kết nối tới sẽ dùng". Thiếu bước này thì
    /// `RTKAutoConnectionHelper` (tự nối khi mở camera, không đi qua nút kết nối) vẫn dùng
    /// caster và offset của profile cũ.
    func select(id: String?) {
        selectedId = id
        UserSession.shared.selectedRTKProfileId = id

        if let profile = selected {
            applyToActiveConfig(profile)
        }
    }

    func markConnected(id: String) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].lastConnectedAt = Date()
        persistProfiles()
    }

    private func persistProfiles() {
        UserSession.shared.rtkConnectionProfiles = profiles
    }

    // MARK: - Áp profile xuống config đang active

    /// Ghi các key mà đường kết nối đọc, gồm custom offset trước đây được ghi ở màn offset.
    /// Loại rover luôn là viDoc theo `UserSession`, không lấy từ profile cũ.
    func applyToActiveConfig(_ profile: RTKConnectionProfile) {
        UserSession.shared.elevation = profile.elevationValue
        UserSession.shared.gnsss = profile.gnssSet
        UserSession.shared.ntripInfo = profile.ntripInfo
        UserSession.shared.ntripServiceProvider = profile.ntripServiceProvider
        UserSession.shared.mountPointNtrip = profile.mountPoint
        UserSession.shared.coordinateSystemNtrip = profile.coordinateSystem
        UserSession.shared.cameraOffsetSegment = profile.cameraOffsetSegment
        UserSession.shared.customOffsetVidoc = profile.customOffset
    }

    // MARK: - Migration

    /// Dựng profile đầu tiên từ cấu hình đơn lẻ của bản cũ, để người đang dùng không phải
    /// nhập lại host/port/user/password và validate NTRIP lại ngoài hiện trường.
    ///
    /// Cố ý KHÔNG xoá các key cũ: `RTKAutoConnectionHelper` chạy ngay khi mở `CameraView`,
    /// có thể trước khi người dùng mở màn profile lần nào, và nó đọc thẳng các key đó.
    ///
    /// QUICK-1060: nếu Mountpoint/hệ toạ độ cũ rỗng (cấu hình từ trước khi hai trường này tồn
    /// tại, hoặc người dùng chưa từng điền), KHÔNG dựng profile — dựng ra một profile thiếu hai
    /// trường bắt buộc chỉ tạo ra thẻ luôn hiện "-" và không bao giờ kết nối được, trong khi
    /// đường lưu thường (`RTKProfileDraft.canSave`) đã bắt buộc có đủ cả hai từ lâu.
    func migrateIfNeeded() {
        guard !UserSession.shared.didMigrateRTKProfiles else { return }
        UserSession.shared.didMigrateRTKProfiles = true

        // QUICK-1061: `didMigrateRTKProfiles` sống ở UserDefaults nên mất sau khi cài lại app,
        // trong khi `rtkConnectionProfiles` sống ở Keychain nên sống sót qua lần cài đó. Thiếu
        // dòng này, cài lại bản test sẽ làm cờ reset về false, hàm này chạy lại và GHI ĐÈ danh
        // sách profile thật (đã có Mountpoint/hệ toạ độ) bằng đúng một profile dựng lại từ các
        // key đơn lẻ cũ — mà hai key mountPointNtrip/coordinateSystemNtrip cũng ở UserDefaults
        // nên đã rỗng, nên Mountpoint và hệ toạ độ trông như "biến mất" trên profile hiện tại.
        guard profiles.isEmpty else { return }

        // Không ghi gì khi chưa có cấu hình cũ: một lần ghi thừa ở đây là một lần có nguy cơ
        // đè lên dữ liệu đọc hụt.
        guard let info = UserSession.shared.ntripInfo else { return }

        let mountPoint = UserSession.shared.mountPointNtrip ?? ""
        guard !mountPoint.isEmpty, UserSession.shared.coordinateSystemNtrip != nil else { return }

        let name = mountPoint

        let profile = RTKConnectionProfile(
            name: name,
            rtkDeviceType: UserSession.shared.rtkTypeSelected,
            cameraOffsetSegment: UserSession.shared.cameraOffsetSegment,
            customOffset: UserSession.shared.customOffsetVidoc,
            ntripServiceProvider: UserSession.shared.ntripServiceProvider,
            hostnameOrIp: info.hostnameOrIp,
            port: info.port,
            username: info.username,
            password: info.password,
            mountPoint: mountPoint,
            coordinateSystem: UserSession.shared.coordinateSystemNtrip,
            elevation: UserSession.shared.elevation,
            gnss: UserSession.shared.gnsss
        )

        profiles = [profile]
        persistProfiles()
        select(id: profile.id)
    }
}
