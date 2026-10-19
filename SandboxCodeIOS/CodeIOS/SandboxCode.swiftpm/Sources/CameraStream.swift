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
import simd

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

// MARK: - Cảm biến hướng của điện thoại (thay cho IMU + ARKit)

/// Nhận hướng điện thoại từ app **Sensor Server** (Android, umer0586) qua WebSocket:
///   ws://<ip>:<port>/sensor/connect?type=android.sensor.rotation_vector
/// Mỗi message: {"values":[x, y, z, w?, acc?], "timestamp":…, "accuracy":…}  ~50 Hz.
/// Android "rotation vector" = quaternion xoay hệ điện thoại → hệ thế giới ENU
/// (X = Đông, Y = Bắc, Z = lên trời).
@MainActor
final class PhoneOrientationStream: ObservableObject {

    /// Hướng điện thoại trong hệ ENU của Android (device → world).
    @Published private(set) var orientation: simd_quatf = simd_quatf(angle: 0, axis: SIMD3(0, 1, 0))
    @Published private(set) var status: String = "Chưa bật"
    @Published private(set) var rate: Double = 0
    @Published private(set) var isRunning = false

    private var task: Task<Void, Never>?
    private var socket: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .ephemeral)

    static let sensorType = "android.sensor.rotation_vector"

    /// `baseURL` dạng "ws://192.168.0.106:8081" (chấp nhận cả "http://…", tự đổi sang ws).
    func start(baseURL: String) {
        stop()
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var comps = URLComponents(string: trimmed.contains("://") ? trimmed : "ws://" + trimmed),
              comps.host != nil
        else { status = "URL sensor không hợp lệ: \(trimmed)"; return }
        switch comps.scheme {
        case "https": comps.scheme = "wss"
        case "wss": break
        default: comps.scheme = "ws"
        }
        comps.path = "/sensor/connect"
        comps.queryItems = [URLQueryItem(name: "type", value: Self.sensorType)]
        guard let url = comps.url else { status = "URL sensor không hợp lệ"; return }

        isRunning = true
        let session = self.session
        task = Task { [weak self] in
            // Vòng ngoài: tự kết nối lại khi rớt
            while !Task.isCancelled {
                let ws = session.webSocketTask(with: url)
                self?.socket = ws
                self?.status = "Đang kết nối \(url.host ?? ""):\(url.port ?? 0)…"
                ws.resume()

                var samples = 0
                var window = Date()
                do {
                    while !Task.isCancelled {
                        let message = try await ws.receive()
                        let data: Data?
                        switch message {
                        case .data(let d): data = d
                        case .string(let s): data = s.data(using: .utf8)
                        @unknown default: data = nil
                        }
                        guard let data else { continue }
                        if let q = Self.parseRotationVector(data) {
                            self?.orientation = q
                            samples += 1
                            let dt = Date().timeIntervalSince(window)
                            if dt >= 1 {
                                self?.rate = Double(samples) / dt
                                self?.status = "rotation_vector OK"
                                samples = 0
                                window = Date()
                            }
                        } else if let text = String(data: data, encoding: .utf8) {
                            // Sensor Server trả lỗi dạng text/JSON nếu máy không có sensor này
                            self?.status = "Server: \(text.prefix(80))"
                        }
                    }
                } catch {
                    if Task.isCancelled { break }
                    self?.status = "Mất kết nối (\(error.localizedDescription)) — thử lại…"
                    self?.rate = 0
                }
                ws.cancel(with: .goingAway, reason: nil)
                if Task.isCancelled { break }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        isRunning = false
        rate = 0
    }

    /// {"values":[x,y,z,(w),(acc)]} — Android: (x·sin θ/2, y·sin θ/2, z·sin θ/2, cos θ/2);
    /// máy cũ chỉ gửi 3 thành phần → tự tính w.
    nonisolated static func parseRotationVector(_ data: Data) -> simd_quatf? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let values = root["values"] as? [Double], values.count >= 3
        else { return nil }
        let x = Float(values[0]), y = Float(values[1]), z = Float(values[2])
        let w: Float = values.count >= 4 ? Float(values[3]) : sqrt(max(0, 1 - x * x - y * y - z * z))
        let q = simd_quatf(ix: x, iy: y, iz: z, r: w)
        return simd_length(q.vector) > 0.0001 ? simd_normalize(q) : nil
    }
}
