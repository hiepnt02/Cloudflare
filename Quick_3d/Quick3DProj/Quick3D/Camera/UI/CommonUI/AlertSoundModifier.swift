import SwiftUI

/// Phát âm cảnh báo mỗi lần một message xuất hiện hoặc đổi nội dung.
/// Gắn ở tầng hiển thị nên mọi view cảnh báo dùng chung đều có cùng hành vi.
private struct AlertSoundModifier: ViewModifier {
    let trigger: String

    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear { play(trigger) }
            .onChange(of: trigger) { play($0) }
    }

    private func play(_ message: String) {
        guard !message.isEmpty, scenePhase == .active else { return }
        AudioService.shared.playAlertSound()
    }
}

extension View {
    func alertSound(trigger: String) -> some View {
        modifier(AlertSoundModifier(trigger: trigger))
    }
}
