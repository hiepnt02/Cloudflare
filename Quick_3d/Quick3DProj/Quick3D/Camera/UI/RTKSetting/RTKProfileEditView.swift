//
//  RTKProfileEditView.swift
//  Quick3D
//
//  Created by MOR on 4/9/26.
//

import SwiftUI

/// Màn nhập thông tin kết nối RTK.
///
/// Lấy UI của màn kết nối cũ làm nền: cùng các khối offset / NTRIP / góc ngẩng / GNSS,
/// thêm ô tên ở trên cùng và đổi nút kết nối thành nút lưu. Màn này không kết nối trực
/// tiếp nên không hiển thị tên thiết bị viDoc.
struct RTKProfileEditView: View {
    @EnvironmentObject private var userManager: UserManager
    @ObservedObject var draft: RTKProfileDraft

    @Binding var isShow: Bool

    @State private var isShowMountpoints = false
    @State private var isShowCoordinates = false
    @State private var isProviderExpanded = false
    @State private var isShowUnsavedAlert = false

    private var lang: String { userManager.userLanguage }

    var body: some View {
        ZStack {
            contentView

            if isShowMountpoints {
                RTKMountpointsView(isShow: $isShowMountpoints, onMountpointSelected: {
                    if draft.currentNtripCoordinateSystem == nil {
                        isShowCoordinates = true
                    }
                })
            }

            if isShowCoordinates {
                RTKCoordinatesView(isShow: $isShowCoordinates)
            }
        }
        .overlayPreferenceValue(ProviderPulldownAnchorKey.self) { anchor in
            providerOptionsOverlay(anchor: anchor)
        }
        .onTapGesture {
            hideKeyboard()
            collapseProviderOptions()
        }
        .alert("WARNING".localized(lang), isPresented: $isShowUnsavedAlert) {
            Button("CANCEL".localized(lang), role: .cancel) {}
            Button("YES".localized(lang), role: .none) {
                draft.cancelFetchingMountpoints()
                draft.reset()
                isShow = false
            }
        } message: {
            Text("CHANGES_NOT_SAVED".localized(lang))
        }
        .environmentObject(draft)
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            HStack {
                SubBackButton(
                    title: "BACK".localized(lang),
                    isBoldTitle: true,
                    onBack: handleBack
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

            NormalButton(
                label: "SAVE".localized(lang),
                isDisabled: !draft.canSave,
                onClick: {
                    draft.apply()
                    isShow = false
                }
            )
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(userManager.setting.themeColor)
    }

    private var settingsView: some View {
        VStack(spacing: 0) {
            nameField
                .padding(.bottom, 16)

            RTKDeviceOffsetView()
                .padding(.bottom, 16)

            RTKDeviceNTRIPView(
                isShowMountpoints: $isShowMountpoints,
                isShowCoordinates: $isShowCoordinates,
                isProviderExpanded: $isProviderExpanded
            )
            .padding(.bottom, 16)
            .zIndex(3)

            ElevationSection(currentElev: $draft.elevation)

            Text("ELEVATION_MASK_DESC".localized(lang))
                .font(.system(size: 12))
                .foregroundColor(userManager.setting.textColor.opacity(0.5))
                .padding(.top, 8)
                .padding(.bottom, 16)

            ConstelationsSection(currentGNSS: $draft.gnss)

            Text("GNSS_CONSTELLATIONS_DESC".localized(lang))
                .font(.system(size: 12))
                .foregroundColor(userManager.setting.textColor.opacity(0.5))
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, popupHPadding)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RTK_PROFILE_NAME".localized(lang))
                .font(.system(size: 14))
                .foregroundColor(userManager.setting.colorTheme == .light ? abbeyGray : bombayGray)

            TextField(
                "RTK_PROFILE_NAME_PLACEHOLDER".localized(lang),
                text: $draft.name,
                prompt: Text("RTK_PROFILE_NAME_PLACEHOLDER".localized(lang)).foregroundColor(slateGrey)
            )
            .disableAutocorrection(true)
            .font(.system(size: 16))
            .foregroundColor(userManager.setting.textColor)
            .frame(height: 32)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 2).fill(userManager.setting.colorTheme == .light ? Color.white : abbeyGray)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2).stroke(steelGray, lineWidth: 1)
            )

            // QUICK-1062: cùng quy tắc và caption với hostname/username/password ở
            // RTKDeviceNTRIPView.swift, dùng lại String.containsInvalidNtripCharacter.
            if draft.name.containsInvalidNtripCharacter {
                Text("RTK_NTRIP_INVALID_CHARACTER".localized(lang))
                    .font(.system(size: 12))
                    .foregroundColor(materialRed)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8).fill(userManager.setting.itemBgColor)
        )
    }

    /// Đóng lần lượt từng tầng con trước, chỉ tới tầng ngoài cùng mới hỏi bỏ thay đổi.
    private func handleBack() {
        if isShowCoordinates {
            isShowCoordinates = false
            return
        }

        if isShowMountpoints {
            draft.cancelFetchingMountpoints()
            isShowMountpoints = false
            return
        }

        if draft.isDirty {
            isShowUnsavedAlert = true
        } else {
            draft.cancelFetchingMountpoints()
            isShow = false
        }
    }

    @ViewBuilder
    private func providerOptionsOverlay(anchor: Anchor<CGRect>?) -> some View {
        GeometryReader { proxy in
            if isProviderExpanded, let anchor = anchor {
                let anchorFrame = proxy[anchor]
                let spacing: CGFloat = 8
                let width = min(anchorFrame.width, max(proxy.size.width - 32, 0))
                let fullHeight = NtripProviderOptionsView.fullHeight
                let spaceBelow = proxy.size.height - anchorFrame.maxY - spacing
                let spaceAbove = anchorFrame.minY - spacing
                let opensDown = spaceBelow >= fullHeight || spaceBelow >= spaceAbove
                let height = min(fullHeight, max(opensDown ? spaceBelow : spaceAbove, 0))

                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        collapseProviderOptions()
                    }

                NtripProviderOptionsView(
                    selected: draft.ntripServiceProvider,
                    width: width,
                    height: height,
                    onSelect: { item in
                        draft.applyNtripServiceProvider(item)
                        collapseProviderOptions()
                    }
                )
                .offset(
                    x: max(anchorFrame.maxX - width, 0),
                    y: opensDown ? anchorFrame.maxY + spacing : anchorFrame.minY - spacing - height
                )
            }
        }
        .ignoresSafeArea(.keyboard)
    }

    private func collapseProviderOptions() {
        guard isProviderExpanded else { return }

        withAnimation(.easeInOut(duration: 0.15)) {
            isProviderExpanded = false
        }
    }
}
