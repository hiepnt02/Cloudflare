//
//  UIScreen++.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 26/05/2022.
//

import Foundation
import UIKit

extension UIScreen {
    // Screen width
    static var screenWidth: CGFloat {
        return UIScreen.main.bounds.width
    }

    static var safeAreaInset: UIEdgeInsets? {
        return UIApplication.shared.windows.first?.safeAreaInsets
    }

    static var leftSafeArea: CGFloat {
        safeAreaInset?.left ?? 0
    }

    static var rightSafeArea: CGFloat {
        safeAreaInset?.right ?? 0
    }

    static var bottomSafeArea: CGFloat {
        safeAreaInset?.bottom ?? 0
    }

    static var topSafeArea: CGFloat {
        safeAreaInset?.top ?? 0
    }

    // Screen height.
    static var screenHeight: CGFloat {
        return UIScreen.main.bounds.height
    }

    static var maxWidth: CGFloat {
        screenWidth - leftSafeArea - rightSafeArea
    }

    static var maxHeight: CGFloat {
        screenHeight - topSafeArea - bottomSafeArea
    }
}
