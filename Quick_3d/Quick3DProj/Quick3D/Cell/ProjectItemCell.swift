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

    var cat: Cat
    @Binding var isEditing: Bool
    let allowTap: Bool
    @Binding var isShowRenameAlert: Bool
    @Binding var isSelected: Bool
    @Binding var isActiveContent: Bool

    let onLongPress: (String) -> Void
    let onTapPress: (String) -> Void
    let onNavigateToDetail: () -> Void

    @Binding var renameCat: Cat
    @Binding var deleteCat: Cat?
    let jobSite: JobSite?
    @Binding var isShowDeletePopup: Bool
    @Binding var isShowExportCompleted: Bool
    @Binding var isLoading: Bool
    @Binding var showARListPopup: Bool
    @Binding var selectCat: Cat
    
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
    
    private var thumbnailImage: UIImage? {
        (cat.source == .local ? cat.image : image) ?? image
    }

    // MARK: - Body
    var body: some View {
        Group {
            if isListView {
                ProjectListCell(
                    cat: cat,
                    isEditing: $isEditing,
                    isSelected: $isSelected,
                    thumbnailImage: thumbnailImage,
                    jobSiteName: jobSiteName,
                    actionMenuItems: AnyView(actionMenuItems),
                    onTap: handleCellTap,
                    onLongPress: {
                        if !isEditing {
                            isSelected = true
                            onLongPress(cat.id)
                        }
                    },
                    isShowNoNetworkAlert: $isShowNoNetworkAlert,
                    cellWidth: $cellWidth
                )
            } else {
                ProjectGridCell(
                    cat: cat,
                    isEditing: $isEditing,
                    isSelected: $isSelected,
                    thumbnailImage: thumbnailImage,
                    jobSiteName: jobSiteName,
                    actionMenuItems: AnyView(actionMenuItems),
                    onTap: handleCellTap,
                    isShowNoNetworkAlert: $isShowNoNetworkAlert
                )
            }
        }
        .allowsHitTesting(allowTap)
        .onAppear { setupCell() }
        .onDisappear { cancelRequests() }
        .onChange(of: contentWidth) { newWidth in
            cellWidth = max(0, (newWidth - 150) / (UIDevice.current.isIphone ? 4 : 5))
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
                        if let projectId = cat.projectId {
                            Task {
                                await Pix4DInfo().openPix4DViewAR(
                                    projectId: projectId,
                                    productData: productData
                                )
                            }
                        } else {
                            print("Error: projectId nil")
                        }
                    }
                }
            } else if userManager.setting.isTester {
                Button("SHOW_POINT_CLOUD".localized(userManager.userLanguage)) {
                    viewLiDAR()
                }
            }
        }
    }

    private func setupCell() {
        cellWidth = max(0, (contentWidth - 150) / (UIDevice.current.isIphone ? 4 : 5))
        
        NotificationCenter.default.addObserver(forName: .updateCell, object: nil, queue: .main) { _ in
            self.isSelected = false
        }

        if cat.source == .remote, let projectID = cat.projectId {
            if let cached = UserSession.shared.cacheThumbnail(for: projectID) {
                self.image = cached
            } else {
                downloadImage(for: projectID)
            }
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
        if uploadProject.isUploading && uploadProject.projectId == cat.id { return }

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
        editProject.isInQueue = productData.uploadProjectQueue.isInQueue(catId: cat.id)
        productData.uploadProjectQueue.dequeue(catId: cat.id)

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

