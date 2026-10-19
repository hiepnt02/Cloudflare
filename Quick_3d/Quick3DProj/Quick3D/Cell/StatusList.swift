//
//  StatusList.swift
//  Quick3D
//
//  Created by ryoma.terai on 2024/04/17.
//

import SwiftUI
import Alamofire

enum ProjectStatus: Int {
    case incomplete = 0 // 未完了
    case processing = 1 // 処理中
    case completed = 2 // 完了
    case waiting = 3 // 待機中
    case error = -1 // エラー
}

struct StatusList: Codable, Equatable {
    let lidar_upload: Int
    let sfm_processing: Int
    let helmert_transformation: Int
    let coordinate_transformation: Int
    let verification_sfm: Int
    let verification_helmert: Int
    let dashboard_upload_las_sfm: Int
    let dashboard_upload_las_helmert: Int
    let dashboard_upload_txt_sfm: Int
    let dashboard_upload_txt_helmert: Int
    let landlog_viewer_upload_sfm: Int
    let landlog_viewer_upload_helmert: Int
    let point_splitting_lidar: Int
    let point_splitting_sfm: Int
    let point_splitting_helmert: Int
    let remove_lidar: Int
    let remove_sfm: Int
    let remove_helmert: Int
    let point_txt_lidar: Int
    let point_txt_sfm: Int
    let point_txt_helmert: Int
    let ply_created: Int
    let ply_upload: Int
    let is_ar: Bool
    let ar_processing: Int
    
    static func == (lhs: StatusList, rhs: StatusList) -> Bool {
        // すべてのプロパティが等しいかどうかを比較
        return lhs.lidar_upload == rhs.lidar_upload &&
        lhs.sfm_processing == rhs.sfm_processing &&
        lhs.helmert_transformation == rhs.helmert_transformation &&
        lhs.coordinate_transformation == rhs.coordinate_transformation &&
        lhs.verification_sfm == rhs.verification_sfm &&
        lhs.verification_helmert == rhs.verification_helmert &&
        lhs.dashboard_upload_las_sfm == rhs.dashboard_upload_las_sfm &&
        lhs.dashboard_upload_las_helmert == rhs.dashboard_upload_las_helmert &&
        lhs.dashboard_upload_txt_sfm == rhs.dashboard_upload_txt_sfm &&
        lhs.dashboard_upload_txt_helmert == rhs.dashboard_upload_txt_helmert &&
        lhs.landlog_viewer_upload_sfm == rhs.landlog_viewer_upload_sfm &&
        lhs.landlog_viewer_upload_helmert == rhs.landlog_viewer_upload_helmert &&
        lhs.point_splitting_lidar == rhs.point_splitting_lidar &&
        lhs.point_splitting_sfm == rhs.point_splitting_sfm &&
        lhs.point_splitting_helmert == rhs.point_splitting_helmert &&
        lhs.remove_lidar == rhs.remove_lidar &&
        lhs.remove_sfm == rhs.remove_sfm &&
        lhs.remove_helmert == rhs.remove_helmert &&
        lhs.point_txt_lidar == rhs.point_txt_lidar &&
        lhs.point_txt_sfm == rhs.point_txt_sfm &&
        lhs.point_txt_helmert == rhs.point_txt_helmert &&
        lhs.ply_created == rhs.ply_created &&
        lhs.ply_upload == rhs.ply_upload &&
        lhs.ar_processing == rhs.ar_processing &&
        lhs.is_ar == rhs.is_ar
    }
    
    var isUploadFail: Bool {
        lidar_upload == -1
    }
    
    var isUploaded: Bool {
        lidar_upload == 2 ||
        lidar_upload == ProjectStatus.waiting.rawValue ||
        sfm_processing == 1 ||
        sfm_processing == 3
    }
    
    var isNotUploaded: Bool{
        lidar_upload == 0 || lidar_upload == 1
    }
    
    var isSfmFail: Bool {
        sfm_processing == -1
    }
    
    var isSfmCompleted: Bool {
        sfm_processing == 2
    }
    
    var isHelmertCompleted: Bool {
        helmert_transformation == 2 || coordinate_transformation == 2
    }
    
    var isHelmertFail: Bool {
        helmert_transformation == -1 || coordinate_transformation == -1
    }
    
    var isVerificationCompleted: Bool {
        verification_sfm == 2 || verification_helmert == 2
    }
    var isDashboardUploaded: Bool {
        dashboard_upload_las_sfm == 2 || dashboard_upload_las_helmert == 2 || dashboard_upload_txt_helmert == 2 || dashboard_upload_txt_sfm == 2 || landlog_viewer_upload_sfm == 2 || landlog_viewer_upload_helmert == 2
    }
    
    var isPointRemove: Bool {
        remove_sfm == 2 || remove_lidar == 2 || remove_helmert == 2
    }
    
    var getIsAR: Bool {
        is_ar
    }
    
    var isARProcessing: Bool {
        is_ar && ar_processing == ProjectStatus.processing.rawValue
    }
    
    var isARComplete: Bool {
        is_ar && (ar_processing == ProjectStatus.completed.rawValue || ar_processing == ProjectStatus.incomplete.rawValue)
    }
    
    var isARFail: Bool {
        is_ar && ar_processing == ProjectStatus.error.rawValue
    }
    
    func sfmStatus(for lang: String) -> String? {
        if isARProcessing {
            return "AR_DATA_IS_BEING_CONVERTED".localized(lang)
        }
        else if isARComplete {
            return "AR_UPLOAD_COMPLETE".localized(lang)
        }
        else if isARFail {
            return "AR_DATA_CONVERT_ERROR".localized(lang)
        }
        else if(isHelmertFail && !isHelmertCompleted){
            return "COORDINATE_CHANGE_ERROR".localized(lang)
        }
        else if(isSfmFail){
            return "SFM_PROCESSING_ERROR".localized(lang)
        }
        else if(isUploadFail){
            return "UPLOAD_ERROR".localized(lang)
        }
        else if(isDashboardUploaded){
            return "DASHBOARD_UPLOAD_COMPLETE".localized(lang)
        }
        else if(isVerificationCompleted){
            return "ACCURACY_VERIFY_COMP".localized(lang)
        }
        else if(isHelmertCompleted){
            return "COORDINATE_CHANGE_COMPLETE".localized(lang)
        }
        else if(isSfmCompleted){
            return "PROCESSING_DONE".localized(lang)
        }
        else if(isUploaded){
            return "UPLOAD_COMPLETE".localized(lang)
        }
        return ""
    }
    
}
