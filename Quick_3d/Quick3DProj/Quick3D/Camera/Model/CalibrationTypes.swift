//
//  CalibrationTypes.swift
//  Quick3D
//

import Foundation
import simd
import UIKit

enum CalibrationStep: Equatable {
    case selectingModelPoint1
    case selectingModelPoint2
    case selectingCameraPoint1
    case selectingCameraPoint2

    static let initial: CalibrationStep = .selectingModelPoint1

    enum PanelMode: Equatable {
        case expanded
        case collapsed
    }

    var panelMode: PanelMode {
        switch self {
        case .selectingModelPoint1, .selectingModelPoint2:
            return .expanded
        case .selectingCameraPoint1, .selectingCameraPoint2:
            return .collapsed
        }
    }

    /// Camera taps (CP1/CP2) are only handled while the panel is collapsed.
    var isCameraTapActive: Bool { panelMode == .collapsed }
}

struct CalibrationPoint {
    let modelPosition: SIMD3<Float>
    let worldPosition: SIMD3<Float>
}

/// State của luồng manual calibration: step hiện tại, P1/P2 chọn trên model và
/// CP1/CP2 chọn trong AR. ManualCalibrationContext sở hữu và mutate, view chỉ đọc.
struct CalibrationSelection {

    private(set) var step: CalibrationStep = .initial
    private(set) var p1: SIMD3<Float>?
    private(set) var p2: SIMD3<Float>?

    private(set) var cp1: SIMD3<Float>?
    private(set) var cp2: SIMD3<Float>?
    private(set) var isPreviewVisible = false

    var isDirPointEnabled: Bool { p1 != nil }
    var isNextEnabled: Bool { step == .selectingModelPoint2 && p2 != nil }

    var isCameraDirEnabled: Bool { step.panelMode == .collapsed && cp1 != nil }
    var isCameraNextEnabled: Bool { step == .selectingCameraPoint2 && cp2 != nil }
    var isPreviewEnabled: Bool { step.panelMode == .collapsed && cp1 != nil }

    var p1DotColor: UIColor {
        step == .selectingModelPoint1 || step == .selectingCameraPoint1
            ? CalibrationColor.selecting
            : CalibrationColor.confirmed
    }
    var p2DotColor: UIColor {
        step == .selectingModelPoint2 || step == .selectingCameraPoint2
            ? CalibrationColor.selecting
            : CalibrationColor.confirmed
    }
    var cp1DotColor: UIColor { step == .selectingCameraPoint1 ? CalibrationColor.selecting : CalibrationColor.confirmed }
    var cp2DotColor: UIColor { CalibrationColor.selecting }

    var calibrationPointPairs: (point1: CalibrationPoint, point2: CalibrationPoint)? {
        guard let p1 = p1, let p2 = p2, let cp1 = cp1, let cp2 = cp2 else { return nil }
        return (
            CalibrationPoint(modelPosition: p1, worldPosition: cp1),
            CalibrationPoint(modelPosition: p2, worldPosition: cp2)
        )
    }

    // MARK: - Model phase (P1/P2, expanded panel)

    mutating func tapModel(at position: SIMD3<Float>) {
        switch step {
        case .selectingModelPoint1:
            p1 = position
        case .selectingModelPoint2:
            p2 = position
        default:
            break
        }
    }

    mutating func selectModelRefPoint() {
        p2 = nil
        step = .selectingModelPoint1
    }

    mutating func selectModelDirPoint() {
        guard p1 != nil else { return }
        step = .selectingModelPoint2
    }

    mutating func confirmNext() {
        guard isNextEnabled else { return }
        cp1 = nil
        cp2 = nil
        isPreviewVisible = false
        step = .selectingCameraPoint1
    }

    mutating func reopenModelSelection() {
        guard step.panelMode == .collapsed else { return }
        self = CalibrationSelection()
    }

    mutating func returnToModelSelection() {
        guard step.panelMode == .collapsed else { return }
        cp1 = nil
        cp2 = nil
        isPreviewVisible = false
        step = .selectingModelPoint2
    }

    // MARK: - Camera phase (CP1/CP2, collapsed panel)

    mutating func tapCamera(at worldPosition: SIMD3<Float>) {
        switch step {
        case .selectingCameraPoint1:
            cp1 = worldPosition
        case .selectingCameraPoint2:
            cp2 = worldPosition
        default:
            break
        }
    }

    /// AC-10: re-pick CP1 — CP2 is discarded (mirrors BR-3 on the model side), so the
    /// user re-picks both camera points in order; CP1 keeps its position until re-tapped.
    mutating func selectCameraRefPoint() {
        guard step.panelMode == .collapsed else { return }
        cp2 = nil
        step = .selectingCameraPoint1
    }

    mutating func selectCameraDirPoint() {
        guard step.panelMode == .collapsed, cp1 != nil else { return }
        step = .selectingCameraPoint2
    }

    mutating func togglePreview() {
        guard isPreviewEnabled else { return }
        isPreviewVisible.toggle()
    }
}

/// Node name constants for the manual calibration flow — single source of
/// truth so the AR camera layer (ManualCalibrationContext) and the panel picker
/// (SCNCalibrationModelPicker) never duplicate the same string literal.
enum CalibrationNames {

    /// CP1/CP2 marker in the live AR camera layer.
    static let cameraDot = "calibration_dot"

    /// P1 marker in the panel picker.
    static let panelDotP1 = "dot_p1"

    /// P2 marker in the panel picker.
    static let panelDotP2 = "dot_p2"
}
