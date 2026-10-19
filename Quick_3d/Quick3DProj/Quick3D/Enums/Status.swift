//
//  Status.swift
//  Quick3D
//
//  Created by HungNT on 20/5/26.
//

import Foundation

enum Status: String {
    case all = "ALL"
    case uploadWating = "UPLOAD_WAITING"
    case uploadCompleted = "UPLOAD_COMPLETE"
    case sfmProcessing = "PROCESSING_DONE"
    case transformationCompleted = "COORDINATE_CHANGE_COMPLETE"
    case verificationCompleted = "ACCURACY_VERIFY_COMP"
    case dashboardUploadCompleted = "DASHBOARD_UPLOAD_COMPLETE"
    case arUploadCompleted = "AR_UPLOAD_COMPLETE"
    
    var value: String {
        switch self {
        case .all: return "all"
        case .uploadWating: return "UploadWating"
        case .uploadCompleted: return "UploadComplete"
        case .sfmProcessing: return "SfMComplete"
        case .transformationCompleted: return "HelmartComplete"
        case .verificationCompleted: return "VerificateComplete"
        case .dashboardUploadCompleted: return "DashboardComplete"
        case .arUploadCompleted: return "ARComplete"
        }
    }
}
