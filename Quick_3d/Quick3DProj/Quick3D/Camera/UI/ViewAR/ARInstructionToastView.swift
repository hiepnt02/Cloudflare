
import SwiftUI

struct ARInstructionToastView: View {
    let message: String

    @State private var isVisible: Bool = false
    @State private var dismissWork: DispatchWorkItem? = nil

    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    var body: some View {
        Group {
            if isVisible && !message.isEmpty {
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(rubyRed)
                    .cornerRadius(12)
                    .frame(maxWidth: isPhone ? .infinity : nil)
                    .padding(.horizontal, isPhone ? 24 : 0)
                    .transition(.opacity)
                    .alertSound(trigger: message)
            }
        }
        .onAppear { show(for: message) }
        .onChange(of: message) { show(for: $0) }
    }

    private func show(for text: String) {
        guard !text.isEmpty else { return }
        withAnimation { isVisible = true }
        dismissWork?.cancel()
        let work = DispatchWorkItem {
            withAnimation { isVisible = false }
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }
}
