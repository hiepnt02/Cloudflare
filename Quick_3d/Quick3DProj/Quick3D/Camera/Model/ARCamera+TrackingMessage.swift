import ARKit

extension ARCamera.TrackingState {
    var messageKey: String? {
        switch self {
        case .normal:
            return nil
        case .notAvailable:
            return "AR_TRACKING_NOT_AVAILABLE"
        case .limited(let reason):
            switch reason {
            case .initializing:
                return "AR_TRACKING_INITIALIZING"
            case .excessiveMotion:
                return "AR_TRACKING_EXCESSIVE_MOTION"
            case .insufficientFeatures:
                return "AR_TRACKING_INSUFFICIENT_FEATURES"
            case .relocalizing:
                return "AR_TRACKING_RELOCALIZING"
            @unknown default:
                return nil
            }
        }
    }
}
