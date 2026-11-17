//
//  UploadProject.swift
//  Quick3D
//
//  Created by ryoma.terai on 2024/06/03.
//
import SwiftUI
import Combine


/// Upload state of a single project, handed to the project cells as a plain value.
///
/// The cells do not observe `UploadProject` themselves: with hundreds of cells every
/// published progress change would re-render the whole list. They only re-render when
/// this value really changes for their own project.
struct CellUploadState: Equatable {
    let phase: UploadPhase

    /// The percentage is only relevant for the project being uploaded, keeping it at 0
    /// for the others means their cells stay untouched while an upload is running.
    var percentage: Double { phase.progress }

    var isUploading: Bool { phase.isUploading }

    var isWaiting: Bool { phase == .waiting }

    var isActive: Bool { phase.isActive }

    var statusTextKey: String { isWaiting ? "PREPARING_FOR_DATA_UPLOAD" : "UPLOADING" }

    static let idle = CellUploadState(phase: .idle)

    init(phase: UploadPhase) {
        self.phase = phase
    }

    init(isUploading: Bool, percentage: Double) {
        self.phase = isUploading ? .uploading(percentage) : .idle
    }
}

class UploadProject:ObservableObject  {
    @Published var projectName :String = ""
    @Published var jobSiteName :String  = ""
    @Published var jobSiteValue :JobSite.Site?  = nil
    @Published var isShowUploadPopup = false
    @Published var isCreate = false
    @Published var currentCat :Cat? = nil
    @Published var isShowARUploadPopup = false
    @Published var isCurrentAR = false
    @Published var isInsufficientPhoto = false

    func resetData() {
        projectName = ""
        jobSiteName  = ""
        jobSiteValue = nil
        isShowUploadPopup = false
        isCreate = false
        currentCat = nil
        isShowARUploadPopup = false
        isCurrentAR = false
        isInsufficientPhoto = false
    }
}
