//
//  ManualCalibrationEvent.swift
//  Quick3D
//

import Foundation
import simd

class ManualCalibrationSelectStepEvent: EventIdentity, ManualCalibrationEvent {
    let step: CalibrationStep
    init(_ step: CalibrationStep) { self.step = step }

    func call(_ context: ManualCalibrationContext) {
        context.select(step)
    }
}

class ManualCalibrationTapModelEvent: EventIdentity, ManualCalibrationEvent {
    let position: SIMD3<Float>
    init(_ position: SIMD3<Float>) { self.position = position }

    func call(_ context: ManualCalibrationContext) {
        context.tapModel(at: position)
    }
}

class ManualCalibrationTapCameraEvent: EventIdentity, ManualCalibrationEvent {
    let point: CGPoint
    init(_ point: CGPoint) { self.point = point }

    func call(_ context: ManualCalibrationContext) {
        context.tapCamera(at: point)
    }
}

class ManualCalibrationConfirmModelEvent: EventIdentity, ManualCalibrationEvent {
    func call(_ context: ManualCalibrationContext) {
        context.confirmModelPoints()
    }
}

class ManualCalibrationReopenEvent: EventIdentity, ManualCalibrationEvent {
    func call(_ context: ManualCalibrationContext) {
        context.reopenModelSelection()
    }
}

class ManualCalibrationBackEvent: EventIdentity, ManualCalibrationEvent {
    func call(_ context: ManualCalibrationContext) {
        context.returnToModelSelection()
    }
}

class ManualCalibrationResetEvent: EventIdentity, ManualCalibrationEvent {
    func call(_ context: ManualCalibrationContext) {
        context.reset()
    }
}

class ManualCalibrationTogglePreviewEvent: EventIdentity, ManualCalibrationEvent {
    func call(_ context: ManualCalibrationContext) {
        context.togglePreview()
    }
}

class ManualCalibrationConfirmEvent: EventIdentity, ManualCalibrationEvent {
    func call(_ context: ManualCalibrationContext) {
        context.confirm()
    }
}
