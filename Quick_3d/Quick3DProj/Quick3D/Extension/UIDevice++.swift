//
//  UIDevice++.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 22/06/2022.
//

import Foundation
import UIKit

extension UIDevice {
    var isIphone: Bool {
        userInterfaceIdiom == .phone
    }
}
