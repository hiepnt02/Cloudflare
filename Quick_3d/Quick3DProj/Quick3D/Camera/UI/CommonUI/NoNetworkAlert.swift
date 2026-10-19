//
//  NoNetworkAlert.swift
//  Quick3D
//
//  Created by HungNT on 8/6/26.
//

import SwiftUI

func noNetworkAlert(
    userManager: UserManager,
    onDissmiss: @escaping () -> Void
) -> Alert {
    return Alert(
        title: Text("CONNECTION_FAILED".localized(userManager.userLanguage))
            .font(.headline)
            .foregroundColor(userManager.setting.textColor),
        message: Text("NO_NETWORK_ERROR".localized(userManager.userLanguage))
            .font(.caption)
            .foregroundColor(userManager.setting.textColor),
        dismissButton:.default(
            Text("OK"),
            action: onDissmiss
        )
    )
}
