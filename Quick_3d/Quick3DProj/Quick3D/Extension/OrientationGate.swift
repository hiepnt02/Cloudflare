//
//  OrientationGate.swift
//  Quick3D
//

import UIKit

/// Cấp quyền xoay tự do cho một số màn hình, rồi trả lại nguyên trạng khi rời khỏi chúng.
///
/// Phần còn lại của app vẫn khoá `.landscapeRight`; chỉ các màn hình gắn
/// `allowsFreeRotation()` mới xoay được. Xem `AllowsFreeRotation`.
///
/// App **khởi động** với `rotatableMask` chứ không phải `lockedMask`: màn hình đầu tiên luôn là
/// màn in-scope, và nếu delegate trả `.landscapeRight` lúc launch thì iOS đã dựng scene theo
/// hướng máy (Info.plist cho phép dọc) rồi bị ép sang ngang — interface xoay nhưng kích thước
/// scene giữ nguyên, sinh ra dải trống bên phải cho tới lần xoay tay đầu tiên.
enum OrientationGate {

    static let rotatableMask: UIInterfaceOrientationMask = [.portrait, .landscapeRight]

    /// Mask của phần còn lại của app — mọi màn hình không gắn `allowsFreeRotation()`.
    static let lockedMask: UIInterfaceOrientationMask = .landscapeRight

    private static var activeCount = 0

    /// Giá trị `orientationLock` trước khi màn in-scope đầu tiên xin quyền.
    private static var maskBeforeFirstAcquire: UIInterfaceOrientationMask?

    /// Xin quyền xoay. Gọi từ `onAppear` của màn hình in-scope.
    ///
    /// Phải gọi trên main thread: `AppDelegate.orientationLock` có `didSet` chạm tới
    /// `UIApplication.shared.connectedScenes`, và trạng thái tĩnh ở đây không đồng bộ hoá.
    static func acquire() {
        assert(Thread.isMainThread, "OrientationGate phải được gọi trên main thread")
        if activeCount == 0 {
            maskBeforeFirstAcquire = AppDelegate.orientationLock
            // Gán khi đã bằng vẫn kích hoạt `didSet`. Lúc mở app mask sẵn là `rotatableMask`,
            // một lệnh đổi geometry thừa ở đây sẽ phá đúng hướng mà iOS vừa chọn theo máy.
            if AppDelegate.orientationLock != rotatableMask {
                AppDelegate.orientationLock = rotatableMask
            }
        }
        activeCount += 1
    }

    static func release() {
        assert(Thread.isMainThread, "OrientationGate phải được gọi trên main thread")
        guard activeCount > 0 else { return }
        activeCount -= 1
        guard activeCount == 0 else { return }

        if AppDelegate.orientationLock == rotatableMask {
            // Giá trị lúc mở app chính là `rotatableMask`, trả lại nó thì các màn ngoài phạm vi
            // ticket cũng xoay được. Trường hợp đó phải về `lockedMask`.
            let previous = maskBeforeFirstAcquire ?? lockedMask
            AppDelegate.orientationLock = (previous == rotatableMask) ? lockedMask : previous
        }
        maskBeforeFirstAcquire = nil
    }

}
