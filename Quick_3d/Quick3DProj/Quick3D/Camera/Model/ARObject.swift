//
//  ARObject.swift
//  Quick3D
//
//  Created by HaNST on 20/11/24.
//

import Foundation
import Combine

final class ARObject: ObservableObject {
    
    @Published var prevStatus: ARStatus = .initial
    
    @Published var status: ARStatus = .stopped

    @Published var imageIndex: Int = 0
    
}
