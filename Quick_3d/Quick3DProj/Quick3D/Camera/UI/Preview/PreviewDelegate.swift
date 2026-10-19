//
//  PreviewDelegate.swift
//  Quick3D
//
//  Created by HaNST on 10/10/25.
//

import Foundation
import SceneKit

protocol PreviewDelegate {
    func preview(_ session: CaptureSession?, didControlCamera isControl: Bool)
}
