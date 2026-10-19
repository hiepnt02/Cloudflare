import SwiftUI
import Combine

struct ARTrackingAlertView: View {
    @EnvironmentObject var userManager: UserManager

    @State private var warningMessage: String = ""
    @State private var isShowAlert = false
    @State private var alertId = UUID()

    var body: some View {
        CameraAlertView(message: $warningMessage, isShow: $isShowAlert)
            .id(alertId)
            .onAppear {
                let state = ARTrackingObject.shared.currentState
                if let key = state.messageKey {
                    warningMessage = key.localized(userManager.userLanguage)
                    isShowAlert = true
                }
            }
            .onReceive(
                ARTrackingObject.shared.$currentState.removeDuplicates { prev, next in
                    switch (prev, next) {
                    case (.normal, .normal), (.notAvailable, .notAvailable):
                        return true
                    case (.limited(.initializing), .limited(.initializing)),
                         (.limited(.excessiveMotion), .limited(.excessiveMotion)),
                         (.limited(.insufficientFeatures), .limited(.insufficientFeatures)),
                         (.limited(.relocalizing), .limited(.relocalizing)):
                        return true
                    default:
                        return false
                    }
                }
            ) { state in
                if let key = state.messageKey {
                    warningMessage = key.localized(userManager.userLanguage)
                    alertId = UUID()
                    isShowAlert = true
                } else {
                    isShowAlert = false
                }
            }
            .onChange(of: userManager.userLanguage) { _ in
                if let key = ARTrackingObject.shared.currentState.messageKey {
                    warningMessage = key.localized(userManager.userLanguage)
                }
            }
    }
}
