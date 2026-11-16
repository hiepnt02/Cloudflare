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
    
    @State private var searchText: String = ""
    @State private var rootOpacity: Double = LayerNode.defaultOpacity
    
    private func layers(for design: ARDesignType) -> [LayerNode] {
        design == .ifc ? ifcLayers : scmLayers
    }

    private func filteredLayers(for design: ARDesignType) -> [LayerNode] {
        let nodes = layers(for: design)
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nodes
        }
        return filterLayersHierarchy(nodes, query: searchText)
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
                        },
                        onLayerOpacityChanged: { node, scale in
                            context?.perform(ViewARDesignOpacityEvent(design, node, calculateOpacity(scale)))
                        },
                        isParentDisabled: false,
                        onToggleExpand: { node in
                            toggleExpand(design: design, nodeId: node.id)
                        },
                        isAnyOpacitySliderOpen: $isAnyOpacitySliderOpen,
                        activeOpacityNodeId: opacityNodeId(for: design),
                        sharedOpacity: $rootOpacity
                    )
                    .environmentObject(userManager)
                }
            }
        }
    }

    // LayerRow operates on unqualified IDs. Keep the global selection scoped
    // to its design so identical IFC/SCM names cannot activate both sliders.
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
    
    @ViewBuilder
    private func pointCloudSizeView() -> some View {
        if isPointCloudRendered {
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
