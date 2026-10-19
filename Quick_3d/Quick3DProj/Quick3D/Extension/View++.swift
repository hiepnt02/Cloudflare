//
//  View++.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 28/07/2022.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    @ViewBuilder func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func persistentToolbarBackground(color: Color) -> some View {
        if #available(iOS 16.0, *) {
            self.toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(color, for: .navigationBar)
        } else {
            // For iOS 15 and older, this modifier does nothing.
            // On older versions, the bar usually stays opaque by default
            // or is managed via UINavigationBarAppearance.
            self
        }
    }
    
    // Forces the removal of the navigation bar divider line
    func hideToolbarDivider() -> some View {
        self.onAppear {
            let appearance = UINavigationBarAppearance()
            appearance.shadowColor = .clear
            appearance.shadowImage = UIImage()
            // Optional: Set background color here if needed
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
#endif

// A ViewModifier that defers its rendering until after the provided threshold surpasses
private struct DeferredViewModifier: ViewModifier {

    // MARK: API
    let threshold: Double

    // MARK: - ViewModifier
    func body(content: Content) -> some View {
        _content(content)
            .onAppear {
               DispatchQueue.main.asyncAfter(deadline: .now() + threshold) {
                   self.shouldRender = true
               }
            }
    }

    // MARK: - Private
    @ViewBuilder
    private func _content(_ content: Content) -> some View {
        if shouldRender {
            content
        } else {
            content
                .hidden()
        }
    }

    @State
    private var shouldRender = false
}

extension View {
    // Use this method to delay view appear after some seconds
    func deferredRendering(for seconds: Double) -> some View {
        modifier(DeferredViewModifier(threshold: seconds))
    }
}

// Squish effect when click to button
struct SquishButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
