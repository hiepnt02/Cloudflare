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
    let isUploading: Bool
    let percentage: Double

    static let idle = CellUploadState(isUploading: false, percentage: 0)

    init(isUploading: Bool, percentage: Double) {
        self.isUploading = isUploading
        // The percentage is only relevant for the project being uploaded, keeping it at 0
        // for the others means their cells stay untouched while an upload is running.
        self.percentage = isUploading ? percentage : 0
    }
}

/// Result of an upload, shown to the user once the progress bar has been hidden.
enum UploadOutcome: Equatable {
    case success
    case failure
}

class UploadProject:ObservableObject  {
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

    /// Delay between hiding the progress bar and showing the upload result, so the user
    /// sees the bar disappear before the popup appears.
    static let resultAlertDelay: TimeInterval = 0.4

    /// Schedules the result popup. Injectable so the sequencing does not depend on real time.
    var scheduleAfter: (TimeInterval, @escaping () -> Void) -> Void = { delay, work in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Shows the upload result. Set by the app so this model stays free of UIKit.
    var presentResult: ((UploadOutcome) -> Void)?

    // Upload lifecycle, not published: the cells must not re-render for these.
    private var hasFinished = false
    private var isCancelled = false
    private var cancelEpoch = 0

    /// Publishes the upload progress only when the percentage shown on screen really
    /// changes. Every project cell observes this object, so assigning the raw progress
    /// of each network callback would re-render the whole list dozens of times a second.
    func updateProgress(_ progress: Double) {
        guard Int(progress * 100) != Int(uploadPercentage * 100) else { return }
        uploadPercentage = progress
    }

    /// Call right before starting an upload whose result is reported with `finishUpload(_:)`.
    func beginUpload() {
        hasFinished = false
        isCancelled = false
        uploadPercentage = 0
    }

    /// Hides the progress bar first, then shows the result after `resultAlertDelay`.
    /// Only the first call per upload has an effect; a cancelled upload shows no result.
    func finishUpload(_ outcome: UploadOutcome) {
        guard !hasFinished else { return }
        hasFinished = true
        isUploading = false

        guard !isCancelled else { return }
        let epoch = cancelEpoch
        scheduleAfter(Self.resultAlertDelay) { [weak self] in
            // A cancel during the delay (logout / no network) drops the pending result.
            guard let self, self.cancelEpoch == epoch else { return }
            self.presentResult?(outcome)
        }
    }

    /// Marks the running upload as cancelled and drops a result that is waiting to be shown.
    func cancelUpload() {
        isCancelled = true
        cancelEpoch += 1
    }

    func resetData() {
        isUploading = false
        isUploaded = false
        projectId = ""
        projectName = ""
        jobSiteName  = ""
        jobSiteValue = nil
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
