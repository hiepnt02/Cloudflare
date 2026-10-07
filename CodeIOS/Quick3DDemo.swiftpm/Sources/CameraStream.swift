//
//  CameraStream.swift
//  Quick3DDemo
//
//  Nguồn ảnh thay cho camera iOS: app "IP Webcam" trên Android.
//  Mỗi ~80 ms tải một ảnh JPEG từ  http://<ip>:8080/shot.jpg  (endpoint của IP Webcam).
//  Đơn giản hơn parse MJPEG (/video) mà đủ ~10–12 fps cho demo.
//

import UIKit
import Combine

@MainActor
final class IPCameraStream: ObservableObject {

    @Published private(set) var image: UIImage?
    @Published private(set) var status: String = "Chưa kết nối"
    @Published private(set) var fps: Double = 0

    private var task: Task<Void, Never>?

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpMaximumConnectionsPerHost = 1
        return URLSession(configuration: config)
    }()

    /// `baseURL` dạng "http://192.168.0.106:8080"
    func start(baseURL: String, interval: TimeInterval = 0.08) {
        stop()
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: trimmed), base.host != nil else {
            status = "URL không hợp lệ: \(trimmed)"
            return
        }
        let shotURL = base.appendingPathComponent("shot.jpg")
        status = "Đang kết nối \(shotURL.absoluteString)…"

        let session = self.session
        task = Task { [weak self] in
            var frames = 0
            var window = Date()
            while !Task.isCancelled {
                do {
                    var request = URLRequest(url: shotURL)
                    request.cachePolicy = .reloadIgnoringLocalCacheData
                    let (data, response) = try await session.data(for: request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        self?.status = "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)"
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        continue
                    }
                    if let img = UIImage(data: data) {
                        self?.image = img
                        frames += 1
                        let dt = Date().timeIntervalSince(window)
                        if dt >= 1 {
                            self?.fps = Double(frames) / dt
                            self?.status = "Đang nhận \(Int(img.size.width))×\(Int(img.size.height))"
                            frames = 0
                            window = Date()
                        }
                    } else {
                        self?.status = "Dữ liệu không phải JPEG"
                    }
                } catch {
                    if Task.isCancelled { break }
                    self?.status = "Lỗi: \(error.localizedDescription)"
                    self?.fps = 0
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        fps = 0
        if status.hasPrefix("Đang") { status = "Đã dừng" }
    }
}
