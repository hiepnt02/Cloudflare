//
//  ThermalMonitor.swift
//  Quick3D
//
//  Created by HaNST on 15/5/26.
//

import Foundation
import Combine

@MainActor
final class ThermalMonitor: ObservableObject {
    
    // Singleton chuẩn
    static let shared = ThermalMonitor()
    
    @Published private(set) var preState: ProcessInfo.ThermalState = .nominal
    @Published private(set) var state: ProcessInfo.ThermalState = .nominal
    
    private var cancellables = Set<AnyCancellable>()
    private var isMonitoring = false
    
    var message: String {
        switch state {
        case .fair: return "THERMAL_FAIR"
        case .serious: return "THERMAL_SERIOUS"
        case .critical: return "THERMAL_CRITICAL"
        case .nominal: return ""
        @unknown default: return ""
        }
    }
    
    // Ngăn chặn việc tạo instance mới từ bên ngoài
    private init() {}
    
    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        // Cập nhật ngay trạng thái hiện tại khi bắt đầu
        updateState(ProcessInfo.processInfo.thermalState)
        
        // Dùng Combine để lắng nghe notification thay vì #selector
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateState(ProcessInfo.processInfo.thermalState)
            }
            .store(in: &cancellables)
    }
    
    func stop() {
        // Hủy toàn bộ các luồng lắng nghe
        cancellables.removeAll()
        isMonitoring = false
        
        // Reset state theo logic ban đầu của bạn
        preState = .nominal
        state = .nominal
    }
    
    private func updateState(_ newState: ProcessInfo.ThermalState) {
        guard state != newState else { return }
        preState = state
        state = newState
        CaptureSession.current?.sessionLogger.logProcessing("thermal", "stateChanged", level: newState == .nominal ? .info : .warning, [
            "from": "\(preState)",
            "to": "\(newState)"
        ])
    }
}
