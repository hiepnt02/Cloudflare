import SwiftUI
import Alamofire
import DeviceKit

// MARK: - 1. MAIN CONTROLLER CELL (ProjectItemCell)
struct ProjectItemCell: View {
    // MARK: Environment & Props
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var productData: ProductData
    @EnvironmentObject var uploadProject: UploadProject
    @EnvironmentObject var editProject: EditProject
    @EnvironmentObject var uploadQueue: UploadQueueManager

    var cat: Cat
    @Binding var isEditing: Bool
    let allowTap: Bool
    @Binding var isShowRenameAlert: Bool
    @Binding var isSelected: Bool
    @Binding var isActiveContent: Bool

    let onTapPress: (String) -> Void
    let onNavigateToDetail: () -> Void

    @Binding var deleteCat: Cat?
    let jobSite: JobSite?
    @Binding var isShowDeletePopup: Bool
    @Binding var isShowExportCompleted: Bool
    @Binding var isLoading: Bool
    @Binding var showARListPopup: Bool
    @Binding var selectCat: Cat?
    
    @Binding var isShowCameraView: Bool
    @Binding var isShowPointCloudView: Bool
    @Binding var contentWidth: CGFloat
    @Binding var contentHeight: CGFloat
    
    // Determines whether the cell is laid out as a Grid or a List item
    let isListView: Bool
    
    // MARK: Private State (Shared Logic)
    @State private var resq: DataRequest?
    @State private var resqi: DataRequest?
    @State private var isShowNoNetworkAlert = false
    @State private var cellWidth: CGFloat = 0
    @State private var image: UIImage?
    
    // MARK: Shared Computed Properties
    private var jobSiteName: String {
        jobSite?.sites.first { $0.id == cat.jobsiteId }?.name ?? ""
    }

    private var jobSiteValue: JobSite.Site? {
        jobSite?.sites.first { $0.id == cat.jobsiteId }
    }
    
    /// Upload state of this project only. Handing it to the cells as a plain value keeps
    /// them out of the queue's observers, so a progress change only re-renders the cell of
    /// the project being uploaded.
    private var uploadState: CellUploadState {
        uploadQueue.states[cat.id] ?? .idle
    }

    // MARK: - Body
    var body: some View {
        Group {
            if isListView {
                ProjectListCell(
                    cat: cat,
                    isEditing: $isEditing,
                    isSelected: $isSelected,
                    thumbnailImage: image,
                    jobSiteName: jobSiteName,
                    uploadState: uploadState,
                    actionMenuItems: { AnyView(actionMenuItems) },
                    onTap: handleCellTap,
                    isShowNoNetworkAlert: $isShowNoNetworkAlert,
                    cellWidth: $cellWidth,
                    visibleColumns: userManager.setting.visibleProjectColumns,
                    contentWidth: contentWidth
                )
                .equatable()
            } else {
                ProjectGridCell(
                    cat: cat,
                    isEditing: $isEditing,
                    isSelected: $isSelected,
                    thumbnailImage: image,
                    jobSiteName: jobSiteName,
                    uploadState: uploadState,
                    actionMenuItems: { AnyView(actionMenuItems) },
                    onTap: handleCellTap,
                    isShowNoNetworkAlert: $isShowNoNetworkAlert
                )
                .equatable()
            }
        }
        .allowsHitTesting(allowTap)
        .onAppear { setupCell() }
        .onDisappear { cancelRequests() }
        .onChange(of: contentWidth) { newWidth in
            cellWidth = ProjectListColumnLayout.Metrics.thumbnailWidth(
                contentWidth: newWidth,
                isIPhone: UIDevice.current.isIphone
            )
        }
        .onChange(of: cat.projectId) { projectID in handleProjectIdChange(projectID) }
    }
}

// MARK: - Shared Business Logic Extension
extension ProjectItemCell {
    
    private var actionMenuItems: some View {
        Group {
            Button("CHANGE_PROJECT".localized(userManager.userLanguage)) {
                prepareDataForEdit(isShowUploadPopup: false)
                self.isShowRenameAlert = true
            }

            Button("REMOVE".localized(userManager.userLanguage)) {
                deleteCat = cat
                isShowDeletePopup = true
            }

            if let status = cat.statusList {
                if userManager.isARAvailable {
                    Button("UPLOAD".localized(userManager.userLanguage)) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            uploadProject.currentCat = cat
                            uploadProject.projectName = cat.title
                            uploadProject.jobSiteName = jobSiteName
                            uploadProject.jobSiteValue = jobSiteValue
                            uploadProject.isShowARUploadPopup = true
                            uploadProject.isCurrentAR = status.getIsAR
                        }
                    }
                    
                    Button("AR_PIX4D_BOOT".localized(userManager.userLanguage)) {
                        // An AR project (`getIsAR`) is always handed over to Pix4D, whatever
                        // its processing state. For every other project the SFM step has to
                        // have been through processing first - completed (step 2 or later in
                        // `statusIndicatorGroup`) or failed. From that point on neither a
                        // failed SFM nor a failed AR conversion (`isARFail`) blocks Pix4D.
                        if !status.getIsAR && !status.canOpenPix4DAR {
                            showSfmNotCompletedAlert()
                        } else if let projectId = cat.projectId {
                            Task {
                                do {
                                    try await Pix4DInfo().openPix4DViewAR(
                                        projectId: projectId,
                                        productData: productData
                                    )
                                } catch {
                                    showPix4DOpenErrorAlert(error)
                                }
                            }
                        } else {
                            print("Error: projectId nil")
                            showPix4DOpenErrorAlert(Pix4DInfo.OpenError.featuresUnavailable)
                        }
                    }
                    
                    CameraButton(type: .ar) {
                        if !status.getIsAR && !status.canOpenPix4DAR {
                            showSfmNotCompletedAlert()
                        } else {
                            viewAR()
                        }
                    } unsupportedAction: {
                        APAlert.shared.showAlertWithTheme(
                            title: "NOTICE".localized(userManager.userLanguage),
                            message: "LIDAR_UNSUPPORTED".localized(userManager.userLanguage),
                            userManager: userManager
                        )
                    }
                }
            } else if userManager.setting.isTester {
                Button("SHOW_POINT_CLOUD".localized(userManager.userLanguage)) {
                    viewLiDAR()
                }
            }
        }
    }

    /// Tells the user why the project is not handed over to Pix4D.
    private func showSfmNotCompletedAlert() {
        showPix4DAlert(messageKey: "AR_PIX4D_SFM_NOT_COMPLETED")
    }

    /// Tells the user why the hand over to Pix4D failed, instead of letting it fail silently.
    private func showPix4DOpenErrorAlert(_ error: Error) {
        if case .appNotOpened? = error as? Pix4DInfo.OpenError {
            showPix4DAlert(messageKey: "PIX4D_APP_NOT_INSTALLED")
        } else {
            showPix4DAlert(messageKey: "AR_PIX4D_OPEN_ERROR")
        }
    }

    /// The alert runs on its own window, so it is shown once the menu has been dismissed.
    private func showPix4DAlert(messageKey: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            APAlert.shared.showAlertWithTheme(
                title: "",
                message: messageKey.localized(userManager.userLanguage),
                buttonTitle: "CLOSE".localized(userManager.userLanguage),
                userManager: userManager
            )
        }
    }

    private func setupCell() {
        cellWidth = ProjectListColumnLayout.Metrics.thumbnailWidth(
            contentWidth: contentWidth,
            isIPhone: UIDevice.current.isIphone
        )
        loadThumbnail()
    }

    /// Loads the thumbnail once per cell and keeps it in `image`.
    /// Reading it inside `body` (through `cat.image`) used to re-read and re-decode the
    /// file from disk on every render - and every cell re-renders each time the upload
    /// progress or the project list is published.
    private func loadThumbnail() {
        if cat.source == .local {
            guard image == nil else { return }

            if let cached = UserSession.shared.cacheThumbnail(for: cat.id) {
                self.image = cached
                return
            }

            guard let thumbnailURL = cat.zipFolder?.appendingPathComponent("thumbnail.png"),
                  FileManager.default.fileExists(atPath: thumbnailURL.path) else { return }

            DispatchQueue.global(qos: .userInitiated).async {
                guard let loadedImage = UIImage.downsampled(from: thumbnailURL, maxPixelSize: 600) else { return }
                DispatchQueue.main.async {
                    UserSession.shared.saveCacheThumbnail(loadedImage, for: cat.id)
                    self.image = loadedImage
                }
            }
            return
        }

        guard let projectID = cat.projectId else { return }
        if let cached = UserSession.shared.cacheThumbnail(for: projectID) {
            self.image = cached
        } else {
            downloadImage(for: projectID)
        }
    }

    private func handleProjectIdChange(_ projectID: String?) {
        guard let id = projectID else { return }
        if let cached = UserSession.shared.cacheThumbnail(for: id) {
            self.image = cached
        } else {
            downloadImage(for: id)
        }
    }

    private func cancelRequests() {
        resq?.cancel()
        resqi?.cancel()
    }

    private func handleCellTap() {
        if !ConnectivityMonitor.shared.isCurrentlyConnected() {
            isShowNoNetworkAlert = true
            return
        }

        if cat.statusList == nil {
            handleLocalProjectTap()
        } else {
            handleRemoteProjectTap()
        }
    }

    private func handleLocalProjectTap() {
        if uploadState.phase.isActive { return }

        if isEditing {
            onTapPress(cat.id)
        } else {
            prepareDataForEdit(isShowUploadPopup: true)
        }
    }

    private func handleRemoteProjectTap() {
        if isEditing {
            onTapPress(cat.id)
        } else {
            Task {
                let isValid = await userManager.checkTokenValid()
                if isValid {
                    try? await userManager.fetchLicense()
                    if userManager.numOfLicenses <= 0 {
                        await logoutUser()
                    } else {
                        handleOpenProject()
                    }
                } else {
                    await logoutUser()
                }
            }
        }
    }

    @MainActor
    private func logoutUser() {
        userManager.logout()
        productData.removeRemoteProject()
        productData.removeJobsiteData()
        productData.resetTotalCount()
        userManager.userInfo = nil
        isActiveContent = false
    }

    private func prepareDataForEdit(isShowUploadPopup: Bool) {
        editProject.resetData()
        editProject.isInQueue = uploadQueue.isBusy(catId: cat.id)
        uploadQueue.remove(catId: cat.id)

        editProject.currentCat = cat
        editProject.projectName = cat.title
        editProject.jobSiteName = jobSiteName
        editProject.jobSiteValue = jobSiteValue
        editProject.isShowUploadPopup = isShowUploadPopup
    }

    private func viewAR() {
        selectCat = cat
        isShowCameraView = true
    }

    private func viewLiDAR() {
        selectCat = cat
        isShowPointCloudView = true
    }
    
    private func handleOpenProject() {
        productData.checkProcessStatus(projectId: cat.projectId ?? "") { isAvailable in
            if isAvailable {
                onNavigateToDetail()
            } else {
                APAlert.shared.showAlertWithTheme(
                    title: "",
                    message: "CONTENT_IS_BEING_PREPARED".localized(userManager.userLanguage),
                    buttonTitle: "CLOSE".localized(userManager.userLanguage),
                    userManager: userManager
                )
            }
        }
    }

    private func downloadImage(for projectID: String) {
        guard UserSession.shared.cacheThumbnail(for: projectID) == nil else { return }
        
        DispatchQueue.global().async {
            resq?.cancel()
            resq = AF.request(URL(string: Constant.baseUrl + "api/v1/project/\(projectID)/thumbnail")!)
                .validate()
                .responseString { result in
                    guard let urlStr = result.value, let url = URL(string: urlStr) else { return }
                    resqi = AF.request(url).validate().responseData { imgResult in
                        guard let data = imgResult.value,
                              let uiImg = UIImage(data: data)?.scaled(to: CGSize(width: cellWidth, height: cellWidth/2)) else { return }

                        DispatchQueue.main.async {
                            UserSession.shared.saveCacheThumbnail(uiImg, for: projectID)
                            self.image = uiImg
                        }
                    }
                }
        }
    }
}

