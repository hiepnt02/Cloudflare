//
//  SidebarView.swift
//  Quick3D
//
//  Created by Admin on 10/10/25.
//

import SwiftUI
import Combine

struct SidebarView: View {
    @EnvironmentObject private var userManager: UserManager
    
    var context: ViewARContext? = nil
    
    @Binding var isPointCloudVisible: Bool
    @Binding var ifcLayers: [LayerNode]
    @Binding var scmLayers: [LayerNode]
    @Binding var isAnyOpacitySliderOpen: Bool
    @Binding var activeOpacityNodeId: String?
    @Binding var pointCloudScale: Double
    @Binding var isExpandLayers: Bool
    @Binding var isPointCloudRendered: Bool
    var pointCloudOpacity: CGFloat = 1.0
    @Binding var isIFCDesignVisible: Bool
    @Binding var ifcDesignOpacity: CGFloat
    @Binding var isSCMDesignVisible: Bool
    @Binding var scmDesignOpacity: CGFloat
    
    @State private var searchText: String = ""
    @State private var rootOpacity: Double = LayerNode.defaultOpacity
    
    // Sử dụng computed property để lọc dữ liệu, giúp body sạch hơn
    private func layers(for design: ARDesignType) -> [LayerNode] {
        design == .ifc ? ifcLayers : scmLayers
    }

    private func visibility(for design: ARDesignType) -> Binding<Bool> {
        design == .ifc ? $isIFCDesignVisible : $isSCMDesignVisible
    }

    private func opacity(for design: ARDesignType) -> Binding<CGFloat> {
        design == .ifc ? $ifcDesignOpacity : $scmDesignOpacity
    }

    private func filteredLayers(for design: ARDesignType) -> [LayerNode] {
        let layers = layers(for: design)
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return layers
        }
        return filterLayersHierarchy(layers, query: searchText)
    }
    
    var isPortrait: Bool {
        AppDelegate.orientationLock == .portrait
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                if isExpandLayers {
                    mainSidebarContent(width: geometry.size.width * (isPortrait ? 0.7 : 0.4))
                        .transition(.move(edge: .leading))
                }
            }
        }
        .onAppear {
            isAnyOpacitySliderOpen = false
            activeOpacityNodeId = nil
        }
        .onChange(of: ifcDesignOpacity) { value in
            syncActiveRootOpacity(.ifc, value: value)
        }
        .onChange(of: scmDesignOpacity) { value in
            syncActiveRootOpacity(.scm, value: value)
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func mainSidebarContent(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("LAYERS".localized(userManager.userLanguage))
                    .font(.headline)
                    .foregroundColor(.white)
                
                // Search Bar
                searchTextField
                
                // Point Cloud Controls
                pointCloudSizeView()
                
                // Layers List
                if !ifcLayers.isEmpty || !scmLayers.isEmpty {
                    layersScrollView
                } else {
                    Spacer()
                }
            }
            .padding()
            .frame(width: width)
            .background(Color.black.opacity(0.85))
            .onTapGesture {
                // Đóng các slider khi chạm vào vùng trống của sidebar
                closeActiveSliders()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .bottom)
    }
    
    private var searchTextField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("SEARCH_LAYER".localized(userManager.userLanguage), text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.white)
        }
        .padding(8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private var layersScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(ARDesignType.allCases) { design in
                    designSection(design)
                }
            }
            .padding(.top, 10)
        }
    }

    @ViewBuilder
    private func designSection(_ design: ARDesignType) -> some View {
        if !layers(for: design).isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(design.rawValue.uppercased()) \("DESIGN".localized(userManager.userLanguage))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.top, 8)

                ForEach(filteredLayers(for: design), id: \.id) { node in
                    LayerRow(
                        node: node,
                        onVisibilityChanged: { node, visible in
                            context?.perform(ViewARDesignVisibleEvent(design, node, visible))
                            if node.parent == nil {
                                syncDesignVisibility(design, rootId: node.id, visible: visible)
                            }
                        },
                        onLayerOpacityChanged: { node, scale in
                            if node.parent == nil {
                                syncDesignOpacity(design, rootId: node.id, scale: scale)
                            } else {
                                node.applyOpacity(scale)
                                context?.perform(ViewARDesignOpacityEvent(design, node, calculateOpacity(scale)))
                            }
                        },
                        isParentDisabled: false,
                        onToggleExpand: { node in
                            toggleExpand(design: design, nodeId: node.id)
                        },
                        isAnyOpacitySliderOpen: $isAnyOpacitySliderOpen,
                        activeOpacityNodeId: opacityNodeId(for: design),
                        sharedOpacity: $rootOpacity,
                        isVisibilityLocked: ViewARVisibilityLock.isLocked(visibility(for: design).wrappedValue, opacity(for: design).wrappedValue)
                    )
                    .environmentObject(userManager)
                }
            }
        }
    }
    
    @ViewBuilder
    private func pointCloudSizeView() -> some View {
        if isPointCloudRendered {
            let isVisibilityLocked = ViewARVisibilityLock.isLocked(isPointCloudVisible, pointCloudOpacity)
            VStack(alignment: .leading, spacing: 8) {
                Button(action: {
                    isPointCloudVisible.toggle()
                    context?.perform(ViewARPointcloudVisibleEvent(isPointCloudVisible))
                }) {
                    HStack {
                        Image(systemName: isPointCloudVisible ? "checkmark.square.fill" : "square")
                            .foregroundColor(isPointCloudVisible ? .blue : .gray)
                        Text("POINT_CLOUD".localized(userManager.userLanguage))
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                }
                .disabled(isVisibilityLocked)
                .opacity(isVisibilityLocked ? 0.5 : 1.0)
                
                Slider(value: $pointCloudScale, in: 0...1.0)
                    .tint(.blue)
                    .onChange(of: pointCloudScale) { newValue in
                        context?.perform(ViewARChangePointCloudSizeEvent(newValue))
                    }
                    .disabled(!isPointCloudVisible)
                    .opacity(isPointCloudVisible ? 1.0 : 0.5)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Helper Functions
    
    // LayerRow uses unqualified IDs; scope the shared selection to its design.
    private func opacityNodeId(for design: ARDesignType) -> Binding<String?> {
        let prefix = "\(design.rawValue):"
        return Binding(
            get: {
                guard let id = activeOpacityNodeId, id.hasPrefix(prefix) else { return nil }
                return String(id.dropFirst(prefix.count))
            },
            set: { id in
                if let id = id {
                    activeOpacityNodeId = prefix + id
                } else if activeOpacityNodeId?.hasPrefix(prefix) == true {
                    activeOpacityNodeId = nil
                }
            }
        )
    }

    private func syncActiveRootOpacity(_ design: ARDesignType, value: CGFloat) {
        guard let id = opacityNodeId(for: design).wrappedValue,
              layers(for: design).contains(where: { $0.id == id }) else { return }
        rootOpacity = Double(value)
    }

    private func syncDesignOpacity(_ design: ARDesignType, rootId: String, scale: Double) {
        layers(for: design).first { $0.id == rootId }?.opacity = scale
        opacity(for: design).wrappedValue = CGFloat(scale)
        context?.perform(ViewARDesignOpacityEvent(design, nil, scale))
    }
    
    private func syncDesignVisibility(_ design: ARDesignType, rootId: String, visible: Bool) {
        // filteredLayers là bản copy khi đang search
        layers(for: design).first { $0.id == rootId }?.isVisible = visible
        let anyRootVisible = layers(for: design).contains { $0.isVisible }
        let designVisible = visibility(for: design)
        guard anyRootVisible != designVisible.wrappedValue else { return }
        designVisible.wrappedValue = anyRootVisible
        context?.perform(ViewARDesignVisibleEvent(design, nil, anyRootVisible))
    }
    
    private func closeActiveSliders() {
        if isAnyOpacitySliderOpen {
            isAnyOpacitySliderOpen = false
            activeOpacityNodeId = nil
        }
    }
    
    private func calculateOpacity(_ scale: Double) -> Double {
        let start = 0.25
        let end = 1.0
        return start + (end - start) * scale
    }
    
    private func filterLayersHierarchy(_ nodes: [LayerNode], query: String) -> [LayerNode] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmedQuery.isEmpty { return nodes }
        
        return nodes.compactMap { node in
            let filteredChildren = filterLayersHierarchy(node.children, query: trimmedQuery)
            let isMatch = node.name.lowercased().contains(trimmedQuery) ||
                          (node.displayName ?? "").lowercased().contains(trimmedQuery)
            
            if isMatch || !filteredChildren.isEmpty {
                return node.copyWith(children: filteredChildren)
            }
            return nil
        }
    }
    
    private func toggleExpand(design: ARDesignType, nodeId: String) {
        if design == .ifc {
            updateNode(in: &ifcLayers, id: nodeId) { $0.isExpanded.toggle() }
        } else {
            updateNode(in: &scmLayers, id: nodeId) { $0.isExpanded.toggle() }
        }
    }
    
    private func updateNode(in nodes: inout [LayerNode], id: String, action: (inout LayerNode) -> Void) {
        for i in nodes.indices {
            if nodes[i].id == id {
                action(&nodes[i])
                return
            }
            updateNode(in: &nodes[i].children, id: id, action: action)
        }
    }
}
