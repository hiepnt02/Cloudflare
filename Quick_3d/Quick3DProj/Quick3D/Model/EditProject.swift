//
//  EditProject.swift
//  Quick3D
//
//  Created by HungNT on 10/3/25.
//

import SwiftUI
import Combine

class EditProject: ObservableObject  {
    @Published var isUploading :Bool = false
    @Published var isUploaded :Bool = false
    @Published var projectId :String = ""
    @Published var projectName :String = ""
    @Published var jobSiteName :String  = ""
    @Published var jobSiteValue :JobSite.Site?  = nil
    @Published var uploadPercentage :Double = 0
    @Published var isShowUploadPopup = false
    @Published var isCreate = false
    @Published var currentCat :Cat? = nil
    @Published var isShowARUploadPopup = false
    @Published var isCurrentAR = false
    @Published var isInsufficientPhoto = false
    @Published var isInQueue = false
    
    func resetData() {
        isUploading = false
        isUploaded = false
        projectId = ""
        projectName = ""
        jobSiteName  = ""
        jobSiteValue  = nil
        uploadPercentage = 0
        isShowUploadPopup = false
        isCreate = false
        currentCat = nil
        isShowARUploadPopup = false
        isCurrentAR = false
        isInsufficientPhoto = false
        isInQueue = false
    }
}
