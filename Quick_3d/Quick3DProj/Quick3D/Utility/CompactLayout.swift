//
//  CompactLayout.swift
//  Quick3D
//
//  QU3DW-1418 — điều kiện và tiện ích cho bố cục ở chế độ dọc.
//

import CoreGraphics
import SwiftUI

enum CompactLayout {
    static func isPortrait(_ size: CGSize) -> Bool {
        guard size.width > 0, size.height > 0 else { return false }
        return size.height > size.width
    }
}

extension String {
    /// Some localized strings carry a hard `\n` sized for the narrow landscape columns;
    /// portrait fields are wide enough to show them on one line.
    func joiningHardLineBreaks(language: String) -> String {
        replacingOccurrences(of: "\n", with: language == LanguageMode.ja.rawValue ? "" : " ")
    }
}

private struct IsPortraitLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isPortraitLayout: Bool {
        get { self[IsPortraitLayoutKey.self] }
        set { self[IsPortraitLayoutKey.self] = newValue }
    }
}

extension View {

    @ViewBuilder
    func columnWidth(_ fixed: CGFloat, isPortrait: Bool, alignment: Alignment = .center) -> some View {
        if isPortrait {
            self
        } else {
            frame(width: fixed, alignment: alignment)
        }
    }

    @ViewBuilder
    func adaptiveWidth(fixed: CGFloat,
                       isPortrait: Bool,
                       height: CGFloat,
                       alignment: Alignment = .center) -> some View {
        if isPortrait {
            frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: alignment)
        } else {
            frame(width: fixed, height: height, alignment: alignment)
        }
    }
}

private struct PopupAvailableSizeKey: EnvironmentKey {
    static let defaultValue = CGSize.zero
}

extension EnvironmentValues {

    /// Kích thước còn trống cho popup, do màn hình đang chứa nó bơm xuống.
    /// `.zero` nghĩa là chưa ai đo — popup giữ nguyên kích thước ưa thích.
    var popupAvailableSize: CGSize {
        get { self[PopupAvailableSizeKey.self] }
        set { self[PopupAvailableSizeKey.self] = newValue }
    }
}

private struct AdaptivePopupWidth: ViewModifier {
    let preferred: CGFloat
    let margin: CGFloat

    @Environment(\.popupAvailableSize) private var available

    func body(content: Content) -> some View {
        content.frame(width: PopupSizing.capped(width: preferred,
                                                available: available.width,
                                                margin: margin))
    }
}

extension View {

    /// Giữ bề ngang thiết kế khi còn chỗ, thu lại vừa màn hình khi không.
    func adaptivePopupWidth(_ preferred: CGFloat, margin: CGFloat = 32) -> some View {
        modifier(AdaptivePopupWidth(preferred: preferred, margin: margin))
    }
}
