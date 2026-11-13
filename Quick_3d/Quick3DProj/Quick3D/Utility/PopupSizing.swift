//
//  PopupSizing.swift
//  Quick3D
//

import CoreGraphics

enum PopupSizing {

    static func capped(_ preferred: CGSize,
                       toAvailable available: CGSize,
                       margin: CGFloat = 32) -> CGSize {
        CGSize(width: capped(width: preferred.width, available: available.width, margin: margin),
               height: capped(width: preferred.height, available: available.height, margin: margin))
    }

    static func capped(width preferred: CGFloat, available: CGFloat, margin: CGFloat = 32) -> CGFloat {
        guard available > 0 else { return preferred }
        return min(preferred, max(0, available - margin))
    }
}
