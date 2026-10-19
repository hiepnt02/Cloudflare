//
//  CameraAlertTypeEnum.swift
//  Quick3D
//
//  Created by HungNT on 30/9/25.
//

import Foundation
import SwiftUI

enum CameraAlertTypeEnum {
    case AbortCapture
    case AbortCaptureFromPreview
    case ConfirmExport
    case OpenSettingLocation
    case OpenSettingCamera
    case OpenSettingBluetooth
    case RTKAutoConnectionFail
    case ARDownloadFail400
    case ARDownloadFail404
    case ARDownloadFail500
    case ARCalculationFail
    case SessionError
    case OutOfMemory
    case Error
    case ThermalFair
    case ThermalSerious
    case ThermalCritical
    case None
    
    var title: String {
        switch self {
        case .ARCalculationFail:
            return "Error"
        case .ARDownloadFail400:
            return "Error"
        case .ARDownloadFail404:
            return "Error"
        case .ARDownloadFail500:
            return "Error"
        case .SessionError:
            return "SAVE_FAILED_TITLE"
        case .AbortCapture, .AbortCaptureFromPreview:
            return "ABORT_CAPTURE_TITLE"
        case .RTKAutoConnectionFail:
            return "CONNECTION_FAILED"
        case .OpenSettingLocation:
            return "LOCATION_PERMISSION_POPUP_TITLE"
        case .OpenSettingCamera:
            return "CAMERA_PERMISSION_POPUP_TITLE"
        case .OpenSettingBluetooth:
            return "BLUETOOTH_PERMISSION_POPUP_TITLE"
        case .ConfirmExport:
            return "EXPORT_DATA_TITLE"
        case .Error:
            return "Error"
        case .OutOfMemory:
            return "OUT_OF_MEMORY_TITLE"
        case .ThermalFair, .ThermalSerious, .ThermalCritical:
            return "WARNING"
        default:
            return ""
        }
    }
    
    var message: String? {
        switch self {
        case .ARCalculationFail:
            return "AR_CALCULATION_FAILED"
        case .ARDownloadFail400:
            return "DOWNLOAD_AR_FAILED_400"
        case .ARDownloadFail404:
            return "DOWNLOAD_AR_FAILED_404"
        case .ARDownloadFail500:
            return "DOWNLOAD_AR_FAILED_500"
        case .SessionError:
            return "SAVE_FAILED_BODY"
        case .AbortCapture, .AbortCaptureFromPreview:
            return "ABORT_CAPTURE_MESSAGE"
        case .RTKAutoConnectionFail:
            return "RTK_NO_NETWORK_MESSAGE"
        case .OpenSettingLocation:
            return "LOCATION_PERMISSION_POPUP_MESSAGE"
        case .OpenSettingCamera:
            return "CAMERA_PERMISSION_POPUP_MESSAGE"
        case .OutOfMemory:
            return "OUT_OF_MEMORY_MESSAGE"
        case .ThermalFair:
            return "THERMAL_FAIR"
        case .ThermalSerious:
            return "THERMAL_SERIOUS"
        case .ThermalCritical:
            return "THERMAL_CRITICAL"
        default:
            return nil
        }
    }
    
    var primaryLabel: String {
        switch self {
        case .ARCalculationFail, .ARDownloadFail400, .ARDownloadFail404, .ARDownloadFail500, .RTKAutoConnectionFail, .OutOfMemory, .ThermalFair, .ThermalSerious, .ThermalCritical:
            return "OK"
        case .SessionError, .Error:
            return "DISSMISS_BTN"
        case .AbortCapture, .AbortCaptureFromPreview:
            return "Abort"
        case .OpenSettingLocation, .OpenSettingCamera, .OpenSettingBluetooth:
            return "OPEN_SETTING"
        case .ConfirmExport:
            return "Exportdata"
        default:
            return ""
        }
    }
    
    var secondaryLabel: String? {
        switch self {
        case .AbortCapture, .AbortCaptureFromPreview, .ConfirmExport:
            return "BACK"
        default:
            return nil
        }
    }
    
    var primaryRole: ButtonRole? {
        switch self {
        case .ARCalculationFail, .ARDownloadFail400, .ARDownloadFail404, .ARDownloadFail500, .RTKAutoConnectionFail, .ConfirmExport, .SessionError, .Error, .OutOfMemory,
                .ThermalFair, .ThermalSerious, .ThermalCritical:
            return .cancel
        case .AbortCapture, .AbortCaptureFromPreview:
            return .destructive
        default:
            return nil
        }
    }
    
    var secondaryRole: ButtonRole? {
        switch self {
        case .AbortCapture, .AbortCaptureFromPreview:
            return .cancel
        default:
            return nil
        }
    }
}
