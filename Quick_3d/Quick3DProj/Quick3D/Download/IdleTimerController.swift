//
//  IdleTimerController.swift
//  Quick3D
//

import Combine
import UIKit

final class IdleTimerController {

    private let get: () -> Bool
    private let set: (Bool) -> Void
    private var valueBeforeDownloads: Bool?
    private var subscription: AnyCancellable?

    init(
        queue: DownloadQueueManager,
        get: @escaping () -> Bool = { UIApplication.shared.isIdleTimerDisabled },
        set: @escaping (Bool) -> Void = { UIApplication.shared.isIdleTimerDisabled = $0 }
    ) {
        self.get = get
        self.set = set
        subscription = queue.$states
            .map { $0.values.contains { $0.isActive } }
            .removeDuplicates()
            .sink { [weak self] isDownloading in self?.update(isDownloading: isDownloading) }
    }

    private func update(isDownloading: Bool) {
        if isDownloading {
            guard valueBeforeDownloads == nil else { return }
            valueBeforeDownloads = get()
            set(true)
        } else if let previous = valueBeforeDownloads {
            valueBeforeDownloads = nil
            set(previous)
        }
    }
}
