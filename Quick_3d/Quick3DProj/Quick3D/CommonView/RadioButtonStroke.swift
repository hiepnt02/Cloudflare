//
//  RadioButtonStroke.swift
//  Quick3D
//
//  Created by HungNT on 3/7/25.
//

import Foundation
import SwiftUI

struct RadioButtonStroke: View {
    @EnvironmentObject var userManager: UserManager
    
    @Binding private var isSelected: Bool
    private let label: String
    private var isDisabled: Bool = false
    
    init(isSelected: Binding<Bool>, label: String = "") {
        self._isSelected = isSelected
        self.label = label
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            circleView
            labelView
        }
        .contentShape(Rectangle())
        .onTapGesture { isSelected = true }
        .disabled(isDisabled)
    }
}

private extension RadioButtonStroke {
    @ViewBuilder var labelView: some View {
        if !label.isEmpty { // Show label if label is not empty
            Text(label)
                .font(.body)
                .foregroundColor(labelColor)
        }
    }
  
    @ViewBuilder var circleView: some View {
        Circle()
            .fill(innerCircleColor) // Inner circle color
            .padding(4)
            .overlay(
                Circle()
                    .stroke(outlineColor, lineWidth: 1)
            ) // Circle outline
            .frame(width: 20, height: 20)
    }
}

private extension RadioButtonStroke {
    var innerCircleColor: Color {
        guard isSelected else { return Color.clear }
        if isDisabled { return Color.gray.opacity(0.6) }
        return Color.blue
    }

    var outlineColor: Color {
        if isDisabled { return Color.gray.opacity(0.6) }
        return isSelected ? Color.blue : Color.gray
    }

    var labelColor: Color {
        return isDisabled ? Color.gray
            .opacity(0.6) : userManager.setting.textColor
    }
}

extension RadioButtonStroke {
    func disabled(_ value: Bool) -> Self {
        var view = self
        view.isDisabled = value
        return view
    }
}

extension RadioButtonStroke {
    // To support multiple options
    init<V: Hashable>(tag: V, selection: Binding<V>, label: String = "") {
        self._isSelected = Binding(
            get: { selection.wrappedValue == tag },
            set: { _ in selection.wrappedValue = tag }
        )
        self.label = label
    }
}
