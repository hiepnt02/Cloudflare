//
//  SupportedOrientations.swift
//  Quick3D
//
//  QU3DW-1418 — modifier cấp quyền xoay cho từng màn hình.
//

import SwiftUI

/// Cho màn hình xoay tự do giữa dọc và ngang trong lúc nó đang hiện, rồi trả lại
/// hướng trước đó khi rời khỏi nó.
///
/// Chỉ gắn vào 3 màn hình nằm trong phạm vi QU3DW-1418: `StartView` (đăng nhập),
/// `MainScreen` (danh sách dự án) và `ProductDetailView` (chi tiết dự án).
/// Mọi màn hình khác **không** gắn modifier này và giữ nguyên hành vi chỉ-ngang (BR-6).
///
/// Việc lồng nhau là an toàn: xem `OrientationGate`.
struct AllowsFreeRotation: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { OrientationGate.acquire() }
            .onDisappear { OrientationGate.release() }
    }
}

extension View {

    /// Cho màn hình này xoay tự do giữa dọc và ngang. Xem `AllowsFreeRotation`.
    func allowsFreeRotation() -> some View {
        modifier(AllowsFreeRotation())
    }
}
