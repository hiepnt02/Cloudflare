import Foundation
import ARKit
import Combine

class ARTrackingObject: ObservableObject {
    static let shared = ARTrackingObject()

    @Published private(set) var currentState: ARCamera.TrackingState = .normal

    private init() {}

    func update(state: ARCamera.TrackingState) {
        DispatchQueue.main.async {
            self.currentState = state
        }
    }

    func reset() {
        DispatchQueue.main.async {
            self.currentState = .normal
        }
    }
}
