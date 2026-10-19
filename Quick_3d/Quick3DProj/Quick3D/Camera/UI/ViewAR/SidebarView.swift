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
    @Binding var layers: [LayerNode]
    @Binding var isAnyOpacitySliderOpen: Bool
    @Binding var activeOpacityNodeId: String?
    @Binding var pointCloudScale: Double
    @Binding var isExpandLayers: Bool
    @Binding var isPointCloudRendered: Bool
    var pointCloudOpacity: CGFloat = 1.0
    @Binding var isDesignVisible: Bool
    @Binding var designOpacity: CGFloat
    
    @State private var searchText: String = ""
    @State private var rootOpacity: Double = LayerNode.defaultOpacity
    
    // Sử dụng computed property để lọc dữ liệu, giúp body sạch hơn
    private var filteredLayers: [LayerNode] {
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
        .onChange(of: designOpacity) { value in
            guard let id = activeOpacityNodeId, layers.contains(where: { $0.id == id }) else { return }
            rootOpacity = Double(value)
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
                if !layers.isEmpty {
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
                ForEach(filteredLayers, id: \.id) { node in
                    LayerRow(
                        node: node,
                        onVisibilityChanged: { node, visible in
                            context?.perform(ViewARIFCVisibleEvent(node, visible))
                            if node.parent == nil {
                                syncDesignVisibility(rootId: node.id, visible: visible)
                            }
                        },
                        onLayerOpacityChanged: { node, scale in
                            if node.parent == nil {
                                syncDesignOpacity(rootId: node.id, scale: scale)
                            } else {
                                node.applyOpacity(scale)
                                context?.perform(ViewARIFCOpacityEvent(node, calculateOpacity(scale)))
                            }
                        },
                        isParentDisabled: false,
                        onToggleExpand: { node in
                            toggleExpand(nodeId: node.id)
                        },
                        isAnyOpacitySliderOpen: $isAnyOpacitySliderOpen,
                        activeOpacityNodeId: $activeOpacityNodeId,
                        sharedOpacity: $rootOpacity,
                        isVisibilityLocked: ViewARVisibilityLock.isLocked(isDesignVisible, designOpacity)
                    )
                    .environmentObject(userManager)
                }
            }
            .padding(.top, 10)
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
    
    private func syncDesignOpacity(rootId: String, scale: Double) {
        layers.first { $0.id == rootId }?.opacity = scale
        designOpacity = CGFloat(scale)
        context?.perform(ViewARIFCOpacityEvent(nil, scale))
    }
    
    private func syncDesignVisibility(rootId: String, visible: Bool) {
        // filteredLayers là bản copy khi đang search
        layers.first { $0.id == rootId }?.isVisible = visible
        let anyRootVisible = layers.contains { $0.isVisible }
        guard anyRootVisible != isDesignVisible else { return }
        isDesignVisible = anyRootVisible
        context?.perform(ViewARIFCVisibleEvent(nil, anyRootVisible))
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
    
    private func toggleExpand(nodeId: String) {
        updateNode(in: &layers, id: nodeId) { node in
            node.isExpanded.toggle()
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
