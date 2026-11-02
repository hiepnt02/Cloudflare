//
//  DownloadNetworkMonitor.swift
//  Quick3D
//

import Foundation
import Network

enum DownloadNetworkStatus: Equatable {
    case wifi
    case cellular
    case offline
}

protocol DownloadNetworkObserving: AnyObject {
    var status: DownloadNetworkStatus { get }
    var onStatusChange: ((DownloadNetworkStatus) -> Void)? { get set }
}

final class DownloadNetworkMonitor: DownloadNetworkObserving {

    typealias Schedule = (_ delay: TimeInterval, _ work: @escaping () -> Void) -> () -> Void

    private(set) var status: DownloadNetworkStatus = .wifi
    var onStatusChange: ((DownloadNetworkStatus) -> Void)?

    private let grace: TimeInterval
    private let schedule: Schedule
    private var cancelPendingOffline: (() -> Void)?
    private var pathMonitor: NWPathMonitor?

    init(
        grace: TimeInterval = Constant.downloadOfflineGrace,
        schedule: @escaping Schedule = DownloadNetworkMonitor.scheduleOnMain,
        observesSystem: Bool = true
    ) {
        self.grace = grace
        self.schedule = schedule
        guard observesSystem else { return }

        let monitor = NWPathMonitor()
        status = Self.status(of: monitor.currentPath)
        monitor.pathUpdateHandler = { [weak self] path in
            let next = Self.status(of: path)
            DispatchQueue.main.async { self?.receive(next) }
        }
        monitor.start(queue: DispatchQueue(label: "QUICK-1086.DownloadNetworkMonitor"))
        pathMonitor = monitor
    }

    deinit {
        pathMonitor?.cancel()
    }

    func receive(_ raw: DownloadNetworkStatus) {
        guard raw != .offline else {
            guard status != .offline, cancelPendingOffline == nil else { return }
            cancelPendingOffline = schedule(grace) { [weak self] in
                self?.cancelPendingOffline = nil
                self?.update(.offline)
            }
            return
        }
        cancelPendingOffline?()
        cancelPendingOffline = nil
        update(raw)
    }

    private func update(_ next: DownloadNetworkStatus) {
        guard next != status else { return }
        status = next
        onStatusChange?(next)
    }

    private static func status(of path: NWPath) -> DownloadNetworkStatus {
        guard path.status == .satisfied else { return .offline }
        if path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet) { return .wifi }
        return path.usesInterfaceType(.cellular) ? .cellular : .wifi
    }

    static func scheduleOnMain(_ delay: TimeInterval, _ work: @escaping () -> Void) -> () -> Void {
        let item = DispatchWorkItem(block: work)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        return item.cancel
    }
}
