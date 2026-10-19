//
//  DropdownLayout.swift
//  Quick3D
//

import UIKit

/// Text width is re-measured every time the jobsite list is filtered, which on a 500+ item
/// list means re-measuring the same names on every keystroke. Titles repeat across filter
/// passes, so each one is measured once per font and reused.
private final class DropdownMeasurementCache {
    static let shared = DropdownMeasurementCache()

    private let lock = NSLock()
    private var widths = [String: CGFloat]()

    func width(for title: String, font: UIFont) -> CGFloat {
        let key = "\(font.fontName)|\(font.pointSize)|\(title)"

        lock.lock()
        defer { lock.unlock() }

        if let cached = widths[key] { return cached }

        let value = title.width(with: font)
        widths[key] = value
        return value
    }
}

/// Geometry for the filter dropdowns on the main screen.
///
/// Deliberately free of SwiftUI so the sizing and clamping rules live in one named place
/// instead of as magic numbers spread through the popup view.
struct DropdownLayout {

    enum Constants {
        /// Gaps kept between the dropdown and the edges of the safe area. Both side edges are
        /// flush by request — the dropdown may sit right against them.
        static let horizontalMargin: CGFloat = 0
        static let bottomMargin: CGFloat = 16
        static let horizontalPadding: CGFloat = 8
        static let maxLines: Int = 2
        static let minRowHeight: CGFloat = 40
        static let rowVerticalPadding: CGFloat = 10
        static let separatorHeight: CGFloat = 0.5
        static let maxWidth: CGFloat = 320
        static let maxHeightIPhone: CGFloat = 200
        static let maxHeightIPad: CGFloat = 280
    }

    struct Frame: Equatable {
        let width: CGFloat
        let height: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    /// Titles of the rows currently displayed, in display order.
    let titles: [String]
    /// The font the rows are actually rendered with.
    let font: UIFont
    /// Frame of the filter field the dropdown hangs off, in the same space as `container`.
    let anchor: CGRect
    /// Size of the app's safe area — not the physical screen, so iPad Split View, the notch
    /// and the home indicator are all accounted for.
    let container: CGSize
    let isIPhone: Bool

    var frame: Frame {
        let width = self.width
        return Frame(width: width, height: height(for: width), x: x(for: width), y: anchor.maxY)
    }

    /// Widest title plus padding, never narrower than the filter field, never wider than
    /// `maxWidth` or the safe area minus its margins. Staying on screen wins if those conflict.
    var width: CGFloat {
        let available = max(0, container.width - 2 * Constants.horizontalMargin)
        let widestTitle = titles
            .map { DropdownMeasurementCache.shared.width(for: $0, font: font) }
            .max() ?? 0
        let content = widestTitle + 2 * Constants.horizontalPadding

        return min(max(anchor.width, content), Constants.maxWidth, available)
    }

    func rowHeight(for title: String, width: CGFloat) -> CGFloat {
        let textWidth = max(1, width - 2 * Constants.horizontalPadding)
        let bounds = CGSize(width: textWidth, height: .greatestFiniteMagnitude)
        let textHeight = title.size(fits: bounds, font: font, maximumNumberOfLines: Constants.maxLines).height

        return max(Constants.minRowHeight, ceil(textHeight) + 2 * Constants.rowVerticalPadding)
    }

    /// Left edge aligned with the filter field, then pushed inward so both edges clear their margin.
    private func x(for width: CGFloat) -> CGFloat {
        let minX = Constants.horizontalMargin
        let maxX = max(minX, container.width - width - Constants.horizontalMargin)

        return min(max(anchor.minX, minX), maxX)
    }

    /// Capped by the device limit and, separately, by whatever room is left between the filter
    /// field and the bottom of the safe area — a long list must scroll rather than run off.
    private func height(for width: CGFloat) -> CGFloat {
        let rows = titles.reduce(CGFloat.zero) { $0 + rowHeight(for: $1, width: width) }
        let separators = titles.count > 1 ? CGFloat(titles.count - 1) * Constants.separatorHeight : 0
        let deviceMax = isIPhone ? Constants.maxHeightIPhone : Constants.maxHeightIPad
        let roomBelowAnchor = max(0, container.height - anchor.maxY - Constants.bottomMargin)

        return min(rows + separators, deviceMax, roomBelowAnchor)
    }
}
