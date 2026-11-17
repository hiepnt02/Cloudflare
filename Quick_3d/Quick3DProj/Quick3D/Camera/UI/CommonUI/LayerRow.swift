//
//  LayerRow.swift
//
//  Created by Admin on 4/10/25.
//

import SwiftUI

struct LayerRow: View {
    @EnvironmentObject var userManager: UserManager
    @ObservedObject var node: LayerNode
    var onVisibilityChanged: (LayerNode, Bool) -> Void
    var onLayerOpacityChanged: (LayerNode, Double) -> Void
    var isParentDisabled: Bool
    let onToggleExpand: (LayerNode) -> Void
    
    // Global state bindings for opacity slider
    @Binding var isAnyOpacitySliderOpen: Bool
    @Binding var activeOpacityNodeId: String?
    @Binding var sharedOpacity: Double
    
    var showExpandIcon: Bool = true
    var isVisibilityLocked: Bool = false
        
    private var isThisSliderActive: Bool {
        activeOpacityNodeId == node.id
    }
    
    var body: some View {
        let isDisabled = isParentDisabled || !(node.parent?.isVisible ?? true)
        
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Indentation
                    if node.depth > 0 {
                        Color.clear.frame(width: CGFloat(node.depth) * 20)
                    }
                    
                    // Checkbox + label
                    Button(action: {
                    }) {
                        HStack {
                            Image(systemName: node.isVisible ? "checkmark.square.fill" : "square")
                                .foregroundColor(node.isVisible ? .blue : .gray)
                                .opacity(isVisibilityLocked ? 0.5 : 1.0)
                                .onTapGesture {
                                    guard !isVisibilityLocked else { return }
                                    let newValue = !node.isVisible
                                    node.isVisible = newValue
                                    if !newValue && isThisSliderActive {
                                        isAnyOpacitySliderOpen = false
                                        activeOpacityNodeId = nil
                                    }
                                    onVisibilityChanged(node, newValue)
                                }
                            Text(node.title)
                                .font(.system(size: 12))
                                .foregroundColor((node.isEffectivelyVisible == false) ? .gray : .white)
                                .onTapGesture {
                                    selectNode()
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                    
                    Spacer()
                    
                    // Opacity control icon (only when selected)
                    if node.isSelected {
                        Button(action: {
                            if isDisabled || !node.isVisible {
                                return
                            }
                            if isThisSliderActive {
                                // Close this slider
                                isAnyOpacitySliderOpen = false
                                activeOpacityNodeId = nil
                            } else {
                                // Open this slider and close any other open sliders
                                sharedOpacity = node.opacity
                                isAnyOpacitySliderOpen = true
                                activeOpacityNodeId = node.id
                            }
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(.yellow)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Expand/collapse arrow
                    if !node.children.isEmpty && showExpandIcon {
                        Button(action: {
                            onToggleExpand(node)
                        }) {
                            Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.trailing, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .overlay(
                    Group {
                        if isThisSliderActive && isAnyOpacitySliderOpen && !isDisabled && node.isVisible {
                            TapSlider(value: $sharedOpacity) {
                                onLayerOpacityChanged(node, sharedOpacity)
                            }
                            .frame(width: 150, height: 30)
                            .padding(8)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(8)
                            .offset(y: -20)
                        }
                    },
                    alignment: .top
                )
                
                // Children
                if node.isExpanded && showExpandIcon{
                    ForEach(node.children, id: \.id) { child in
                        LayerRow(
                            node: child,
                            onVisibilityChanged: onVisibilityChanged,
                            onLayerOpacityChanged: onLayerOpacityChanged,
                            isParentDisabled: isDisabled || !node.isVisible,
                            onToggleExpand: onToggleExpand,
                            isAnyOpacitySliderOpen: $isAnyOpacitySliderOpen,
                            activeOpacityNodeId: $activeOpacityNodeId,
                            sharedOpacity: $sharedOpacity
                        )
                    }
                }
            }
        }
        .background(Color.clear)
        .contentShape(Rectangle())
        .padding([.top, .bottom], 4)
        .onAppear {
            sharedOpacity = node.opacity
        }
        .onTapGesture {
            if isDisabled || !node.isVisible {
                return
            }
            selectNode()
        }
    }
    
    private func selectNode() {
        isAnyOpacitySliderOpen = false
        
        deselectAll(root: topParent())
        node.isSelected = true
    }
    
    private func deselectAll(root: LayerNode) {
        root.isSelected = false
        for child in root.children {
            deselectAll(root: child)
        }
    }
    
    private func topParent() -> LayerNode {
        var current = node
        while let parent = current.parent {
            current = parent
        }
        return current
    }
}
