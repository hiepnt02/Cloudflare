//
//  CameraWarningView.swift
//  Quick3D
//
//  Created by HungNT on 24/9/25.
//
import SwiftUI
import Combine

struct MoveFastWarningView: View {
    @EnvironmentObject var userManager: UserManager
    
    @State private var warningMessage: String = ""
    @State private var isShowAlertMoveFast = false
    
    var body: some View {
        CameraAlertView(
            interval: 3,
            color: orange,
            message: $warningMessage,
            isShow: $isShowAlertMoveFast
        )
        .onAppear {
            // Cập nhật message dựa trên ngôn ngữ
            updateWarningMessage()
        }
        // Chỉ nhận thông báo khi isMoveFast thay đổi giá trị
        .onReceive(
            MotionObject.shared.$data
                .map { $0.isMoveFast }
                .removeDuplicates() // Chỉ phát tín hiệu khi giá trị true/false thực sự thay đổi
        ) { isMoveFast in
            if isMoveFast {
                isShowAlertMoveFast = true
            }
        }
        // Cập nhật lại message nếu user đổi ngôn ngữ giữa chừng
        .onChange(of: userManager.userLanguage) { _ in
            updateWarningMessage()
        }
    }
    
    private func updateWarningMessage() {
        warningMessage = "MOVING_TOO_FAST".localized(userManager.userLanguage).uppercased()
    }
}
