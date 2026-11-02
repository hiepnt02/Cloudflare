//
//  DownloadPrompter.swift
//  Quick3D
//

import Foundation

protocol DownloadPrompter: AnyObject {
    func showError(_ reason: DownloadFailureReason, displayName: String)

    func confirmCellular(bytes: Int64?, onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void)

    func confirmCellularResume(onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void)

    func dismissCellularPrompt()

    func showNetworkLost()

    func confirmUpdate(displayName: String, onConfirm: @escaping () -> Void)

    func showUpToDate(displayName: String)

    func confirmCancel(displayName: String, onConfirm: @escaping () -> Void)

    func showCheckFailed(displayName: String)

    func confirmRemovedFile(displayName: String, onDelete: @escaping () -> Void, onKeep: @escaping () -> Void)
}

final class AppDownloadPrompter: DownloadPrompter {

    private let userManager: UserManager

    init(userManager: UserManager) {
        self.userManager = userManager
    }

    func showError(_ reason: DownloadFailureReason, displayName: String) {
        let key: String
        switch reason {
        case .storageFull: key = "GSX_DOWNLOAD_STORAGE_FULL"
        case .network: key = "GSX_DOWNLOAD_NETWORK_LOST"
        case .interrupted, .unauthorized, .server, .invalidResponse, .unknown: key = "GSX_DOWNLOAD_FAILED"
        }
        APAlert.shared.showAlert(
            title: displayName,
            message: localized(key),
            buttonTitle: localized("CLOSE")
        )
    }

    func confirmCellular(bytes: Int64?, onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        let size = bytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "-"
        askOnCellular(
            message: String(format: localized("GSX_DOWNLOAD_CELLULAR_WARNING"), size),
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }

    func confirmCellularResume(onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        askOnCellular(message: localized("GSX_DOWNLOAD_CELLULAR_RESUME"), onConfirm: onConfirm, onCancel: onCancel)
    }

    func dismissCellularPrompt() {
        APAlert.shared.remove()
    }

    func showNetworkLost() {
        APAlert.shared.showAlert(
            title: "",
            message: localized("GSX_DOWNLOAD_NETWORK_LOST"),
            buttonTitle: localized("CLOSE")
        )
    }

    func confirmUpdate(displayName: String, onConfirm: @escaping () -> Void) {
        APAlert.shared.showAlert(
            title: "",
            message: String(format: localized("GSX_DOWNLOAD_UPDATE_CONFIRM"), displayName),
            leftIconName: "arrow.down.circle",
            textButtonPositive: localized("YES"),
            textButtonNegative: localized("CANCEL"),
            onClickPositive: onConfirm,
            onClickNegative: {},
            userManager: userManager
        )
    }

    func showUpToDate(displayName: String) {
        APAlert.shared.showAlert(
            title: "",
            message: String(format: localized("GSX_DOWNLOAD_UP_TO_DATE"), displayName),
            buttonTitle: localized("CLOSE")
        )
    }

    func confirmCancel(displayName: String, onConfirm: @escaping () -> Void) {
        APAlert.shared.showAlert(
            title: "",
            message: String(format: localized("GSX_DOWNLOAD_CANCEL_CONFIRM"), displayName),
            leftIconName: "xmark.circle",
            textButtonPositive: localized("GSX_DOWNLOAD_CANCEL_YES"),
            textButtonNegative: localized("GSX_DOWNLOAD_CANCEL_NO"),
            onClickPositive: onConfirm,
            onClickNegative: {},
            userManager: userManager
        )
    }

    func showCheckFailed(displayName: String) {
        APAlert.shared.showAlert(
            title: displayName,
            message: localized("GSX_UPDATE_CHECK_FAILED"),
            buttonTitle: localized("CLOSE")
        )
    }

    func confirmRemovedFile(displayName: String, onDelete: @escaping () -> Void, onKeep: @escaping () -> Void) {
        APAlert.shared.showAlert(
            title: "",
            message: String(format: localized("GSX_FILE_REMOVED_CONFIRM"), displayName),
            leftIconName: "exclamationmark.triangle",
            textButtonPositive: localized("GSX_FILE_REMOVED_DELETE"),
            textButtonNegative: localized("GSX_FILE_REMOVED_KEEP"),
            onClickPositive: onDelete,
            onClickNegative: onKeep,
            userManager: userManager
        )
    }

    private func askOnCellular(message: String, onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        APAlert.shared.showAlert(
            title: "",
            message: message,
            leftIconName: "exclamationmark.triangle",
            textButtonPositive: localized("YES"),
            textButtonNegative: localized("CANCEL"),
            onClickPositive: onConfirm,
            onClickNegative: onCancel,
            userManager: userManager
        )
    }

    private func localized(_ key: String) -> String {
        key.localized(userManager.userLanguage)
    }
}
