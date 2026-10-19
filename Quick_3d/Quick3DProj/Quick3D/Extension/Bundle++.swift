//
//  Bundle++.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 31/05/2022.
//

import Foundation
import UIKit

extension Bundle {
    var appIcon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
            let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }

    static func stringValue(_ key: String) -> String? {
        return Bundle.main.infoDictionary?[key] as? String
    }
    
    static var shortVersion: String {
        stringValue("CFBundleShortVersionString") ?? ""
    }
    
    static var buildVersion: String {
        stringValue("CFBundleVersion") ?? ""
    }
}
