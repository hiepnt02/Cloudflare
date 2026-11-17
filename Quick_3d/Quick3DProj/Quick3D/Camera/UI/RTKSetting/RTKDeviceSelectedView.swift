//
//  RTKSearchingView.swift
//  Quick3D
//
//  Created by HaNST on 29/12/25.
//

import SwiftUI
import CoreBluetooth
import Network
import VigramSDK

struct RTKDeviceSelectedView: View {
    @EnvironmentObject private var userManager: UserManager
    @ObservedObject private var rtk: RTKObject = .shared
    @ObservedObject private var store: RTKProfileStore = .shared

    let deviceName: String
    let identifier: UUID
    var back : (() -> Void)? = nil
    var onClose : (() -> Void)? = nil

    @State private var isConnecting = false
    @State private var isDisconnecting = false
    @State private var isClickConnectRTK = false
    @State private var activeAlert: ActiveAlertEnum?

    @State private var editingDraft: RTKProfileDraft?

    /// Profile đã áp xuống config active ở lần bấm kết nối này, để đánh dấu đúng bản ghi
    /// khi kết nối xong.
    @State private var connectingProfileId: String?

    /// QUICK-1061: đang kết nối/ngắt kết nối, hoặc đã kết nối và đang nhận tín hiệu RTK
    /// (`rtk.isReady`, cùng cờ mà nút Disconnect bên dưới đang dùng) thì không cho đổi profile.
    private var isBusy: Bool {
        isConnecting || isDisconnecting || rtk.isReady
    }

    private var lang: String { userManager.userLanguage }

    private var isConnectButtonDisabled: Bool {
        // Không chỉ "đã chọn": profile migrate từ bản cũ có thể thiếu hệ toạ độ, hoặc là
        // .Custom với offset 0. Trước đây nút kết nối chặn các trường hợp đó, giữ nguyên.
        store.selected?.isConnectable != true
    }

    var body: some View {
        ZStack {
            contentView

            if let draft = editingDraft {
                RTKProfileEditView(
                    draft: draft,
                    isShow: Binding(
                        get: { editingDraft != nil },
                        set: { if !$0 { editingDraft = nil } }
                    )
                )
                // Buộc dựng lại view khi đổi profile: `.onLoad` trong các khối con chỉ chạy
                // một lần cho mỗi view identity, thiếu cái này thì mở profile A rồi B sẽ
                // không chạy lại setOffsetOptions().
                .id(draft.id)
            }
        }
        .onAppear {
            isConnecting = rtk.state == .connecting
            isDisconnecting = rtk.state == .disconnecting
            isClickConnectRTK = false
        }
        .onChange(of: rtk.state) { value in
            if value == .connected || value == .disconnected {
                isConnecting = false
                isDisconnecting = false
            }

            if value == .connected && isClickConnectRTK {
                isClickConnectRTK = false
                if let id = connectingProfileId {
                    store.markConnected(id: id)
                }
                connectingProfileId = nil
                onClose?()
            }
        }
        .alert(item: $activeAlert) { alertType in
            getAlert(alertType: alertType)
        }
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            HStack {
                SubBackButton(
                    title: "RTK_BLUETOOTH_DEVICE_MESSAGE_BACK_TO_LIST".localized(lang),
                    isBoldTitle: true,
                    onBack: {
                        RTKManager.shared.disconnect()
                        back?()
                    }
                )
                .padding(.leading, 16)

                Spacer()
            }

            ScrollView(showsIndicators: false) {
                settingsView
            }

            if UIDevice.current.isIphone {
                Divider().background(lightGray)
            }

            bottomActionView
                .padding(16)
        }
        .frame(maxWidth: .infinity)
    }

    private var settingsView: some View {
        VStack(spacing: 0) {
            Text(deviceName)
                .font(.system(size: 32))
                .foregroundColor(userManager.setting.textColor)
                .padding(.vertical, 16)

            VidocInfoSection()

            Text("RTK_PROFILE_LIST_TITLE".localized(lang))
                .font(.system(size: 16))
                .foregroundColor(slateGrey)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)

            RTKProfileRadioList(
                isLocked: isBusy,
                onEdit: { profile in
                    editingDraft = RTKProfileDraft(editing: profile)
                },
                onCreate: {
                    editingDraft = RTKProfileDraft()
                }
            )
        }
        .padding(.horizontal, popupHPadding)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var bottomActionView: some View {
        if rtk.isReady {
            NormalButton(
                label: "RTK_BLUETOOTH_DEVICE_DISCONNECT".localized(lang),
                backgroundColor: materialRed,
                onClick: {
                    isConnecting = false
                    isDisconnecting = true
                    RTKManager.shared.disconnect()
                }
            )
        } else if isConnecting {
            LoadingButton(
                label: "RTK_BLUETOOTH_DEVICE_MESSAGE_ACQUIRING_LOCATION".localized(lang),
                isShowLoading: $isConnecting,
                onClick: {
                }
            )
        }  else if isDisconnecting {
            LoadingButton(
                label: "",
                isShowLoading: $isDisconnecting,
                onClick: {
                }
            )
        } else {
            NormalButton(
                label: "RTK_BLUETOOTH_DEVICE_CONNECT".localized(lang),
                isDisabled: isConnectButtonDisabled,
                onClick: onConnectRTK
            )
        }
    }

    private func onConnectRTK() {
        if !ConnectivityMonitor.shared.isCurrentlyConnected() {
            activeAlert = .noNetwork
            return
        }

        guard let profile = store.selected else { return }

        do {
            // select()/upsert() đã áp rồi, nhưng áp lại ngay trước khi nối để chắc chắn
            // đường kết nối đọc đúng profile này.
            store.applyToActiveConfig(profile)

            connectingProfileId = profile.id
            isClickConnectRTK = true
            RTKConnectionObserver.shared.reset()
            try connectToDevice()
            isConnecting = true
        } catch {
            print("Error \(error)")
            isClickConnectRTK = false
            connectingProfileId = nil
            activeAlert = .custom(
                title: "CONNECTION_FAILED".localized(lang),
                message: "DEVICE_NOT_FOUND".localized(lang)
            )
        }
    }

    private func connectToDevice() throws {
        if let device = rtk.devices.filter({ $0.identifier == identifier }).first {
            try RTKManager.shared.connectTo(device: device, isAutoConnectToNtrip: true)
        } else {
            throw NSError(domain: "", code: 0, userInfo: nil)
        }
    }

    private func getAlert(alertType: ActiveAlertEnum) -> Alert {
        switch alertType {
        case .noNetwork:
            return noNetworkAlert(
                userManager: userManager,
                onDissmiss: {}
            )
        case .custom:
            return Alert(
                title: Text(activeAlert?.title ?? ""),
                message: Text(activeAlert?.message ?? ""),
                dismissButton: .default(
                    Text("OK"),
                    action: {}
                )
            )
        }
    }
}
