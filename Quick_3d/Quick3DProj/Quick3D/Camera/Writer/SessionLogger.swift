//
//  SessionLogger.swift
//  Quick3D
//
//  Ghi lại operation log (thao tác người dùng/UI) và processing log (pipeline, lỗi, RTK/GPS, network)
//  trong suốt một CaptureSession, để đóng gói cùng debug log ZIP chia sẻ cho dev khi cần debug.
//

import Foundation
import UIKit

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

final class SessionLogger {

    private let operationURL: URL
    private let processingURL: URL
    private let isEnabled: Bool

    private let lock = NSLock()
    private var operationBuffer: [String] = []
    private var processingBuffer: [String] = []
    private let maxBufferedLines = 200
    // Cửa sổ mất log tối đa khi app crash = chu kỳ flush này.
    private let flushInterval: TimeInterval = 2
    private var flushTimer: DispatchSourceTimer?
    private var backgroundObserver: NSObjectProtocol?

    private static let timeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init(operationURL: URL, processingURL: URL, isEnabled: Bool = true) {
        self.operationURL = operationURL
        self.processingURL = processingURL
        self.isEnabled = isEnabled
        guard isEnabled else { return }
        try? FileManager.default.createDirectory(at: operationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        // Flush khi app vào background: session có thể bị iOS kill mà không quay lại,
        // nếu không xả buffer thì mất các dòng log cuối.
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil
        ) { [weak self] _ in
            self?.write()
        }
        
        // Flush định kỳ trong suốt session chụp: crash (kể cả OOM/watchdog kill —
        // các loại mà signal handler không bắt được) chỉ mất tối đa flushInterval giây log cuối.
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + flushInterval, repeating: flushInterval)
        timer.setEventHandler { [weak self] in
            self?.write()
        }
        timer.resume()
        flushTimer = timer
    }

    deinit {
        flushTimer?.cancel()
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Operation log (thao tác người dùng / vòng đời UI)

    func logOperation(_ event: String, level: LogLevel = .info, _ detail: [String: Any] = [:]) {
        guard isEnabled else { return }
        let line = format(level: level, tag: "ui", event: event, detail: detail)
        lock.lock()
        operationBuffer.append(line)
        let shouldFlush = operationBuffer.count >= maxBufferedLines
        lock.unlock()
        if shouldFlush { flushOperation() }
    }

    // MARK: - Processing log (pipeline xử lý, lỗi, RTK/GPS, network...)

    func logProcessing(_ tag: String, _ event: String, level: LogLevel = .info, _ detail: [String: Any] = [:]) {
        guard isEnabled else { return }
        let line = format(level: level, tag: tag, event: event, detail: detail)
        lock.lock()
        processingBuffer.append(line)
        let shouldFlush = processingBuffer.count >= maxBufferedLines
        lock.unlock()
        if shouldFlush { flushProcessing() }
    }

    // Đảm bảo toàn bộ log đã ghi ra file trước khi đóng gói ZIP (khi nhấn Save).
    func write() {
        guard isEnabled else { return }
        flushOperation()
        flushProcessing()
    }

    private func flushOperation() {
        lock.lock()
        guard !operationBuffer.isEmpty else { lock.unlock(); return }
        let text = operationBuffer.joined(separator: "\n") + "\n"
        operationBuffer.removeAll(keepingCapacity: true)
        appendSynchronously(operationURL, text: text)
        lock.unlock()
    }

    private func flushProcessing() {
        lock.lock()
        guard !processingBuffer.isEmpty else { lock.unlock(); return }
        let text = processingBuffer.joined(separator: "\n") + "\n"
        processingBuffer.removeAll(keepingCapacity: true)
        appendSynchronously(processingURL, text: text)
        lock.unlock()
    }

    // Ghi thẳng FileHandle (đồng bộ) thay vì qua JobManager queue của StorageManager:
    // dữ liệu đã qua syscall thì sống sót khi process crash, còn job đang xếp hàng thì mất.
    // Gọi bên trong `lock` để giữ thứ tự dòng log giữa các thread.
    private func appendSynchronously(_ url: URL, text: String) {
        guard let data = text.data(using: .utf8) else { return }
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                let fileHandle = try FileHandle(forWritingTo: url)
                defer { try? fileHandle.close() }
                try fileHandle.seekToEnd()
                try fileHandle.write(contentsOf: data)
            } else {
                try data.write(to: url)
            }
        } catch {
        }
    }

    private func format(level: LogLevel, tag: String, event: String, detail: [String: Any]) -> String {
        let time = Self.timeFormatter.string(from: Date())
        guard !detail.isEmpty else {
            return "\(time) [\(level.rawValue)] [\(tag)] \(event)"
        }
        let detailString = detail
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        return "\(time) [\(level.rawValue)] [\(tag)] \(event) \(detailString)"
    }
}
