//
//  ImageResolutionEnum.swift
//  Quick3D
//
//  Created by HungNT on 4/9/25.
//

import Foundation

enum ImageResolutionEnum: Int {
    case normal = 0
    case fourK = 1
    case maximum = 2
    
    func getLabel(_ userManager: UserManager) -> String {
        let title = switch UserSession.shared.imageResolution {
            case .normal:
                "NORMAL".localized(userManager.userLanguage)
            case .fourK:
                "4K"
            case .maximum:
                "MAXIMUM_RESOLUTION".localized(userManager.userLanguage)
        }
        return title
    }
}
