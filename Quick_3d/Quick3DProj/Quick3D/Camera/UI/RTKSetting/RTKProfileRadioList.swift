//
//  RTKProfileRadioList.swift
//  Quick3D
//
//  Created by MOR on 6/10/26.
//

import SwiftUI

/// Danh sách profile kết nối RTK chọn bằng radio, nằm thẳng trong màn thiết bị.
///
/// Thứ tự được chụp lúc view được tạo (profile dùng gần nhất lên đầu) rồi chỉ cập nhật
/// theo thêm/xoá, để card không nhảy chỗ khi người dùng đang thao tác.
struct RTKProfileRadioList: View {
    @EnvironmentObject private var userManager: UserManager
    @ObservedObject private var store: RTKProfileStore = .shared

    let isLocked: Bool
    var onEdit: (RTKConnectionProfile) -> Void
    var onCreate: () -> Void

    @State private var orderedIds: [String]
    @State private var profileToDelete: RTKConnectionProfile?
    @State private var isShowDeleteConfirm = false

    private var lang: String { userManager.userLanguage }

    init(isLocked: Bool, onEdit: @escaping (RTKConnectionProfile) -> Void, onCreate: @escaping () -> Void) {
        self.isLocked = isLocked
        self.onEdit = onEdit
        self.onCreate = onCreate
        let store = RTKProfileStore.shared
        _orderedIds = State(initialValue: RTKProfileOrdering.ordered(store.profiles, selectedId: store.selectedId).map(\.id))
    }

    private var displayedProfiles: [RTKConnectionProfile] {
        orderedIds.compactMap { id in store.profiles.first { $0.id == id } }
    }

    var body: some View {
        VStack(spacing: 12) {
            if store.profiles.isEmpty {
                emptyState
            }

            ForEach(displayedProfiles) { profile in
                RTKProfileRadioCard(
                    profile: profile,
                    isSelected: profile.id == store.selectedId,
                    isLocked: isLocked,
                    onSelect: {
                        guard profile.id != store.selectedId else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.select(id: profile.id)
                        }
                    },
                    onEdit: { onEdit(profile) },
                    onDelete: {
                        profileToDelete = profile
                        isShowDeleteConfirm = true
                    }
                )
            }

            createRow
        }
        .onReceive(store.$profiles) { profiles in
            let reconciled = RTKProfileOrdering.reconcile(snapshot: orderedIds, profiles: profiles)
            if reconciled != orderedIds {
                orderedIds = reconciled
            }
        }
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

    private var createRow: some View {
        Button(action: onCreate) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                Text("RTK_PROFILE_NEW".localized(lang))
                    .font(.system(size: 16, weight: .bold))
                Spacer(minLength: 0)
            }
            .foregroundColor(skyBlue)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(skyBlue, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .opacity(isLocked ? 0.5 : 1)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
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
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }
}
