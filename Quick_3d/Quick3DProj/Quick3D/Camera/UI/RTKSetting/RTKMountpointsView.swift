//
//  RTKMountpointsPopup.swift
//  Quick3D
//
//  Created by HungNT on 5/1/26.
//

import SwiftUI

struct RTKMountpointsView: View {
    @EnvironmentObject private var userManager: UserManager
    
    @EnvironmentObject private var rtk: RTKProfileDraft
    
    @Binding var isShow: Bool

    var onMountpointSelected: (() -> Void)? = nil

    @State private var isSortMountpointByName = true
    @State private var mountpointsFiltered: [MountPointModel] = []
    
    @State private var mountpoints: [MountPointModel] = []
    
    @State private var recentMountpointsFiltered: [MountPointModel] = []
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                SubBackButton(
                    title: "BACK".localized(userManager.userLanguage),
                    isBoldTitle: true,
                    onBack: {
                        rtk.cancelFetchingMountpoints()
                        isShow = false
                    }
                )
                .padding(.leading, 16)
                
                Spacer()
            }
            
            // Search field
            MountpointSearchField(
                onTextChanged: { keysearch in
                    filterMountpoint(keysearch)
                },
                onCancel: {
                    filterMountpoint("")
                }
            )
            .padding(.horizontal, popupHPadding)
            
            if rtk.isMountpointsFetched {
                // Content
                contentView
            } else {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.black)
                            .scaleEffect(0.8)
                            .frame(width: 40, height: 40)
                        Spacer()
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onLoad {
            if !rtk.isMountpointsFetched {
                rtk.fetchMountpoints(onCompletion: { mountpoints in
                    self.mountpoints = mountpoints
                    self.filterMountpoint("")
                })
            } else {
                self.mountpoints = rtk.mountpoints
                self.filterMountpoint("")
            }
        }
        .background(userManager.setting.themeColor)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    private var contentView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            // Rows stay directly inside the LazyVStack so the full list keeps
            // building lazily while scrolling.
            LazyVStack(spacing: 10) {
                if !recentMountpointsFiltered.isEmpty {
                    MountpointSectionHeader(
                        title: "RTK_NTRIP_MOUNTPOINT_RECENT_SELECTIONS".localized(userManager.userLanguage),
                        textColor: userManager.setting.textColor,
                        dividerColor: userManager.setting.dividerColor
                    )
                    
                    ForEach(recentMountpointsFiltered) { mountpoint in
                        ItemMountPointView(
                            mountpoint: mountpoint,
                            namePointSelected: $rtk.currentMountpoint,
                            textColor: userManager.setting.textColor,
                            onClick: selectMountpoint
                        )
                        .padding(.bottom, 16)
                    }
                }
                
                MountpointSectionHeader(
                    title: "RTK_NTRIP_MOUNTPOINT_ALL_SELECTION".localized(userManager.userLanguage),
                    textColor: userManager.setting.textColor,
                    dividerColor: userManager.setting.dividerColor
                )
                
                ForEach(mountpointsFiltered) { mountpoint in
                    ItemMountPointView(
                        mountpoint: mountpoint,
                        namePointSelected: $rtk.currentMountpoint,
                        textColor: userManager.setting.textColor,
                        onClick: selectMountpoint
                    )
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 16)
    }
    
    private func selectMountpoint(_ pointName: String) {
        rtk.currentMountpoint = pointName
        rtk.saveRecentMountpoint(pointName)
        rtk.isNtripMountpointStatus = true
        isShow = false
        onMountpointSelected?()
    }
    
    func filterMountpoint(_ name: String) {
        if name.isEmpty {
            mountpointsFiltered = mountpoints
            recentMountpointsFiltered = rtk.recentMountpoints
            
        } else {
            let keyword = name.lowercased()
            mountpointsFiltered = mountpoints.filter{
                $0.name.lowercased().contains(keyword)
            }
            recentMountpointsFiltered = rtk.recentMountpoints.filter{
                $0.name.lowercased().contains(keyword)
            }
        }
        sortMountpoint()
    }
    
    func sortMountpoint() {
        if isSortMountpointByName {
            mountpointsFiltered = mountpointsFiltered.sorted {
                $0.name < $1.name
            }
        } else {
            mountpointsFiltered = mountpointsFiltered.sorted {
                $0.distance < $1.distance
            }
        }
    }
}

struct ItemMountPointView: View {
    var mountpoint: MountPointModel
    
    @Binding var namePointSelected: String
    
    var textColor: Color
    
    var onClick: (String) -> Void
    
    var body: some View {
        HStack(alignment: .center) {
            Image("ic_earth_white")
                .renderingMode(.template)
                .resizable()
                .foregroundColor(textColor)
                .frame(width: 24, height: 24)
            
            Text(mountpoint.name)
                .foregroundColor(textColor)
                .font(.system(size: 16))
            
            Spacer()
            
            Text(mountpoint.distance)
                .foregroundColor(textColor.opacity(0.5))
                .font(.system(size: 16))
            
            Image(systemName: "checkmark")
                .renderingMode(.template)
                .resizable()
                .foregroundColor(textColor)
                .frame(width: 16, height: 16)
                .opacity(namePointSelected == mountpoint.name ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onClick(mountpoint.name)
        }
        .padding(.horizontal, popupHPadding)
    }
}

struct MountpointSectionHeader: View {
    var title: String
    
    var textColor: Color
    
    var dividerColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundColor(textColor)
                .font(.system(size: 16, weight: .bold))
            
            Divider()
                .frame(height: 1)
                .background(dividerColor)
        }
        .padding(.horizontal, popupHPadding)
        .padding(.bottom, 8)
    }
}
