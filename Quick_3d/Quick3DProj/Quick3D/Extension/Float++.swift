//
//  Float++.swift
//  Quick3D
//
//  Created by HaNST on 23/02/26.
//

import Foundation

extension Float {
    var radians: Float {
        self * .pi / 180.0
    }
    
    var degrees: Float {
        self * 180.0 / .pi
    }
}
