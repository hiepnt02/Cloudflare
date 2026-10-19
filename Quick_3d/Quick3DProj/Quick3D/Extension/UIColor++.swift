//
//  UIColor++.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 13/09/2022.
//

import Foundation
import UIKit

extension UIColor {
    convenience init(hex: UInt, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            alpha: alpha
        )
    }
}
