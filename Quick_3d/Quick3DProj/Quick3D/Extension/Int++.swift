//
//  Int++.swift
//  Quick3D
//
//  Created by HungNT on 27/8/25.
//

import Foundation

extension Int {
    func bytesToHumanReadable() -> String {
        let units = ["Bytes", "KB", "MB", "GB", "TB", "PB"]
        var convertedValue = Double(self)
        var unitIndex = 0

        while convertedValue >= 1024 && unitIndex < units.count - 1 {
            convertedValue /= 1024
            unitIndex += 1
        }
        
        // Use String(format:) to control the number of decimal places
        return String(format: "%.2f %@", convertedValue, units[unitIndex])
    }
}
