//
//  RTKCoordinatesPopup.swift
//  Quick3D
//
//  Created by HungNT on 5/1/26.
//

import SwiftUI

struct RTKCoordinatesView: View {
    @EnvironmentObject private var userManager: UserManager
    
    @EnvironmentObject private var rtk: RTKProfileDraft
    
    @State private var ntripCoordinateSystemsData: [CoordinateSystemNtripModel] = []

    @Binding var isShow: Bool

    @State var ntripCoordinateSystems: [CoordinateSystemNtripModel] = []
    
    var body: some View {
        VStack {
            HStack {
                SubBackButton(
                    title: "BACK".localized(userManager.userLanguage),
                    isBoldTitle: true,
                    onBack: {
                        isShow = false
                    }
                )
                .padding(.leading, 16)
                
                Spacer()
            }
            
            // Search field
            MountpointSearchField(
                onTextChanged: { keysearch in
                    filterCoordinateSystemNtrip(keysearch)
                },
                onCancel: {
                    filterCoordinateSystemNtrip("")
                }
            )
            .padding(.horizontal, popupHPadding)
            
            // Content
            contentView
        }
        .background(userManager.setting.themeColor)
        .onAppear {
            let sorted = GeoCoordinateHelper.shared.getSortedGeoCoordinateLabel(
                counts: UserSession.shared.ntripCoordinateSelectionCounts ?? [:]
            )
            ntripCoordinateSystemsData = sorted
            ntripCoordinateSystems = sorted
        }
    }
    
    private var contentView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 10) {
                ForEach(ntripCoordinateSystems) { coordinate in
                    ItemCoordinateView(
                        coordinate: coordinate,
                        coordSelected: $rtk.currentNtripCoordinateSystem,
                        textColor: userManager.setting.textColor,
                        onClick: { coordSelected in
                            rtk.currentNtripCoordinateSystem = coordinate
                            rtk.isNtripCoordinateSystemStatus = true
                            var counts = UserSession.shared.ntripCoordinateSelectionCounts ?? [:]
                            counts[coordinate.code, default: 0] += 1
                            UserSession.shared.ntripCoordinateSelectionCounts = counts
                            isShow = false
                        }
                    )
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 16)
    }
    
    func filterCoordinateSystemNtrip(_ name: String) {
        if name.isEmpty {
            ntripCoordinateSystems = ntripCoordinateSystemsData
            
        } else {
            ntripCoordinateSystems = ntripCoordinateSystemsData.filter{
                $0.name.lowercased().contains(name.lowercased())
            }
            let coordinateSystem = ntripCoordinateSystemsData.first { coordinateSystemModel in
                coordinateSystemModel.code == name
            }
            if let coordinateSystem = coordinateSystem {
                ntripCoordinateSystems = [coordinateSystem]
            }
        }
    }
}

struct ItemCoordinateView: View {
    var coordinate: CoordinateSystemNtripModel
    @Binding var coordSelected: CoordinateSystemNtripModel?
    var textColor: Color
    
    var onClick: (CoordinateSystemNtripModel) -> Void
    
    var body: some View {
        HStack(alignment: .center) {
            Image("ic_coordinate")
                .renderingMode(.template)
                .resizable()
                .foregroundColor(textColor)
                .frame(width: 24, height: 24)
            
            Text(coordinate.name)
                .foregroundColor(textColor)
                .font(.system(size: 16))
            
            Spacer()
            
            Text("\(coordinate.code)")
                .foregroundColor(textColor.opacity(0.5))
                .font(.system(size: 16))
            
            Image(systemName: "checkmark")
                .renderingMode(.template)
                .resizable()
                .foregroundColor(textColor)
                .frame(width: 16, height: 16)
                .opacity(coordinate.code == coordSelected?.code ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onClick(coordinate)
        }
        .padding(.horizontal, popupHPadding)
    }
}
