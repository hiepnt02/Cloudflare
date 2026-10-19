//
//  CapturePendingSettings.swift
//  Quick3D
//
//  Buffer object for CaptureScreen settings.
//  Holds pending values; apply() flushes them to UserSession on Save.
//

import Foundation

final class CapturePendingSettings: ObservableObject {

    // MARK: - Buffered published fields

    @Published var imageResolution: ImageResolutionEnum
    @Published var overlapValue: Double
    @Published var ratioValue: Double
    @Published var smoothValue: Int

    @Published var saveToken: Int = 0

    @Published var isShowMovement: Bool
    @Published var isEnableAlertSound: Bool
    @Published var isShowFeaturePoints: Bool
    @Published var isShowResolution: Bool
    @Published var isShowOverlap: Bool
    @Published var previewMode: PreviewEnum
    @Published var isEnableMesh: Bool
    @Published var isSaveMesh: Bool
    @Published var isEnableLog: Bool

    // MARK: - Initial snapshot (for isDirty comparison)

    private var initialResolution: ImageResolutionEnum
    private var initialOverlapValue: Double
    private var initialRatioValue: Double
    private var initialSmoothValue: Int
    private var initialIsShowMovement: Bool
    private var initialIsEnableAlertSound: Bool
    private var initialIsShowFeaturePoints: Bool
    private var initialIsShowResolution: Bool
    private var initialIsShowOverlap: Bool
    private var initialPreviewMode: PreviewEnum
    private var initialIsEnableMesh: Bool
    private var initialIsSaveMesh: Bool
    private var initialIsEnableLog: Bool

    // MARK: - Init

    init() {
        let s = UserSession.shared
        imageResolution      = s.imageResolution
        overlapValue         = s.overlapValue
        ratioValue           = s.ratioValue
        smoothValue          = s.smoothValue
        isShowMovement       = s.isShowMovement
        isEnableAlertSound   = s.isEnableAlertSound
        isShowFeaturePoints  = s.isShowFeaturePoints
        isShowResolution     = s.isShowResolution
        isShowOverlap        = s.isShowOverlap
        previewMode          = s.previewMode
        isEnableMesh         = s.isEnableMesh
        isSaveMesh           = s.isSaveMesh
        isEnableLog          = s.isEnableLog

        initialResolution          = s.imageResolution
        initialOverlapValue        = s.overlapValue
        initialRatioValue          = s.ratioValue
        initialSmoothValue         = s.smoothValue
        initialIsShowMovement      = s.isShowMovement
        initialIsEnableAlertSound  = s.isEnableAlertSound
        initialIsShowFeaturePoints = s.isShowFeaturePoints
        initialIsShowResolution    = s.isShowResolution
        initialIsShowOverlap       = s.isShowOverlap
        initialPreviewMode         = s.previewMode
        initialIsEnableMesh        = s.isEnableMesh
        initialIsSaveMesh          = s.isSaveMesh
        initialIsEnableLog         = s.isEnableLog
    }

    // MARK: - Dirty detection

    var isDirty: Bool {
        imageResolution     != initialResolution        ||
        abs(overlapValue    -  initialOverlapValue)  > 0.0001 ||
        abs(ratioValue      -  initialRatioValue)    > 0.0001 ||
        smoothValue         != initialSmoothValue       ||
        isShowMovement      != initialIsShowMovement    ||
        isEnableAlertSound  != initialIsEnableAlertSound ||
        isShowFeaturePoints != initialIsShowFeaturePoints ||
        isShowResolution    != initialIsShowResolution  ||
        isShowOverlap       != initialIsShowOverlap     ||
        previewMode         != initialPreviewMode       ||
        isEnableMesh        != initialIsEnableMesh      ||
        isSaveMesh          != initialIsSaveMesh        ||
        isEnableLog         != initialIsEnableLog
    }
    
    // MARK: - Discard
    
    func reset() {
        imageResolution      = initialResolution
        overlapValue         = initialOverlapValue
        ratioValue           = initialRatioValue
        smoothValue          = initialSmoothValue
        isShowMovement       = initialIsShowMovement
        isEnableAlertSound   = initialIsEnableAlertSound
        isShowFeaturePoints  = initialIsShowFeaturePoints
        isShowResolution     = initialIsShowResolution
        isShowOverlap        = initialIsShowOverlap
        previewMode          = initialPreviewMode
        isEnableMesh         = initialIsEnableMesh
        isSaveMesh           = initialIsSaveMesh
    }

    // MARK: - Commit

    func apply() {
        let s = UserSession.shared
        s.imageResolution     = imageResolution
        s.overlapValue        = overlapValue
        s.ratioValue          = ratioValue
        s.smoothValue         = smoothValue
        s.isShowMovement      = isShowMovement
        s.isEnableAlertSound  = isEnableAlertSound
        s.isShowFeaturePoints = isShowFeaturePoints
        s.isShowResolution    = isShowResolution
        s.isShowOverlap       = isShowOverlap
        s.previewMode         = previewMode
        s.isEnableMesh        = isEnableMesh
        s.isSaveMesh          = isSaveMesh
        s.isEnableLog         = isEnableLog

        initialResolution          = imageResolution
        initialOverlapValue        = overlapValue
        initialRatioValue          = ratioValue
        initialSmoothValue         = smoothValue
        initialIsShowMovement      = isShowMovement
        initialIsEnableAlertSound  = isEnableAlertSound
        initialIsShowFeaturePoints = isShowFeaturePoints
        initialIsShowResolution    = isShowResolution
        initialIsShowOverlap       = isShowOverlap
        initialPreviewMode         = previewMode
        initialIsEnableMesh        = isEnableMesh
        initialIsSaveMesh          = isSaveMesh
        initialIsEnableLog         = isEnableLog

        saveToken += 1
    }
}
