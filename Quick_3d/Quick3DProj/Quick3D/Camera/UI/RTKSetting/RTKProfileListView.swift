//
//  RTKProfileListView.swift
//  Quick3D
//
//  Created by MOR on 4/9/26.
//

import SwiftUI

/// Màn chọn thông tin kết nối RTK: danh sách card cuộn, nút thêm cố định ở đáy.
struct RTKProfileListView: View {
    @EnvironmentObject private var userManager: UserManager
    @ObservedObject private var store: RTKProfileStore = .shared

    @Binding var isShow: Bool

    var onEdit: (RTKConnectionProfile) -> Void
    var onCreate: () -> Void

    @State private var profileToDelete: RTKConnectionProfile?
    @State private var isShowDeleteConfirm = false

    private var lang: String { userManager.userLanguage }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SubBackButton(
                    title: "BACK".localized(lang),
                    isBoldTitle: true,
                    onBack: { isShow = false }
                )
                .padding(.leading, 16)

                Spacer()
            }

            if store.profiles.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        ForEach(store.profiles) { profile in
                            RTKProfileCard(
                                profile: profile,
                                style: .selectable,
                                isSelected: profile.id == store.selectedId,
                                onSelect: {
                                    store.select(id: profile.id)
                                    isShow = false
                                },
                                onEdit: { onEdit(profile) },
                                onDelete: {
                                    profileToDelete = profile
                                    isShowDeleteConfirm = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, popupHPadding)
                    .padding(.vertical, 16)
                }
            }

            if UIDevice.current.isIphone {
                Divider().background(lightGray)
            }

            NormalButton(
                label: "RTK_PROFILE_CREATE".localized(lang),
                isStroke: true,
                onClick: onCreate
            )
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(userManager.setting.themeColor)
        .alert(
            "REMOVE".localized(lang),
            isPresented: $isShowDeleteConfirm,
            presenting: profileToDelete
        ) { profile in
            Button("CANCEL".localized(lang), role: .cancel) {}
            Button("REMOVE".localized(lang), role: .destructive) {
                store.delete(id: profile.id)
            }
        } message: { profile in
            Text(String(format: "RTK_PROFILE_DELETE_CONFIRM".localized(lang), profile.name))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image("antena_offline")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundColor(userManager.setting.textColor.opacity(0.3))
                .frame(width: 56, height: 56)

            Text("RTK_PROFILE_EMPTY_TITLE".localized(lang))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(userManager.setting.textColor)

            Text("RTK_PROFILE_EMPTY_DESC".localized(lang))
                .font(.system(size: 14))
                .foregroundColor(userManager.setting.textColor.opacity(0.5))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, popupHPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
