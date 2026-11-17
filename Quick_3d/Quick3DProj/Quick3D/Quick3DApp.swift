//
//  Quick3DApp.swift
//  Quick3D
//
//  Created by 木皿直規 on 2022/04/04.
//

// https://dev.classmethod.jp/articles/ui_documentinteraction_controller/
// 「ファイル」アプリからフォルダを開く方法はinfo.plist
// Application supports iTunes file sharing
// Supports opening documents in place
// の２つをYESにする

import SwiftUI
import Combine
import Alamofire

@main
struct Quick3DApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State var isShowProjectDetailPopup = false
    @State var isShowVersionAlert = false
    @State var forceShowVersionAlert = false
    @State var showLater = false
    @State private var savedProjectName = ""
    @State private var navigateToProjectDetail = false
    @State private var navigateCat: Cat?
    @StateObject private var productData = ProductData()
    @StateObject private var userManager = UserManager()
    @State var cancellables = Set<AnyCancellable>()
    @StateObject private var themeManager = ThemeManager()
    
    let uploadTask = UploadBackgroundTask()
    @StateObject var newProject = NewProject()
    @StateObject var editProject = EditProject()
    @StateObject var uploadProject = UploadProject()
    @StateObject var cancelUploadProject = CancelUploadProject()
    @StateObject var uploadQueue = UploadQueueManager()
    
    @State var isShowRenameAlert: Bool = false
    
    @StateObject var languageObserver = LanguageChangeObserver()
    
    @State private var isShowSelectFileFromGroupware: Bool = false
    
    @State private var groupwareSelected: GroupwareModel? = nil
    @State private var groupwareTypeSelected: GroupwareType = GroupwareType.dashboard
    @State private var arUploadCase: UploadCase = .Ifc

    @State private var batchResults: [UploadBatchResult] = []
    
    var body: some Scene {
        WindowGroup{
            ZStack {
                StartView(navigateToProjectDetail: $navigateToProjectDetail, navigateCat: $navigateCat, isShowRenameAlert: $isShowRenameAlert)
                    .onOpenURL { url in
                        newProject.isShowUploadPopup = true
                        newProject.jobSiteValue = nil
                        newProject.isCreate = true
                        newProject.currentCat = navigateCat
                        newProject.url = url
                    }
                    .environmentObject(productData)
                    .environmentObject(userManager)
                    .environmentObject(themeManager)
                    .environmentObject(newProject)
                    .environmentObject(uploadProject)
                    .environmentObject(editProject)
                    .environmentObject(cancelUploadProject)
                    .environmentObject(uploadQueue)
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                        if forceShowVersionAlert {
                            isShowVersionAlert = true
                        } else {
                            AF.request(URL(string: Constant.baseUrl + "api/v1/version")!)
                                .validate()
                                .responseDecodable(of: Version.self) { response in
                                    guard let model = response.value else {
                                        return
                                    }
                                    if let force = model.force {
                                        showLater = !force
                                    }
                                    if Bundle.shortVersion.versionCompare(model.version) == .orderedAscending {
                                        isShowVersionAlert = true
                                        forceShowVersionAlert = true
                                    }
                                }
                        }
                    }
                    .alert(isPresented: $isShowVersionAlert) {
                        if showLater {
                            return Alert(title: Text("VersionPopupTitle".localized(userManager.userLanguage)),
                                         message: Text("VersionPopupMessage2".localized(userManager.userLanguage)),
                                         primaryButton: Alert.Button.default(Text("Upgrade".localized(userManager.userLanguage)), action: {
                                if let url = URL(string: Constant.appstoreURL) {
                                    UIApplication.shared.open(url)
                                }
                            }), secondaryButton: Alert.Button.cancel(Text("Later".localized(userManager.userLanguage)), action: {
                                forceShowVersionAlert = false
                            })
                            )
                        } else {
                            return Alert(title: Text("VersionPopupTitle".localized(userManager.userLanguage)),
                                         message: Text("VersionPopupMessage1".localized(userManager.userLanguage)),
                                         dismissButton: Alert.Button.default(Text("Upgrade".localized(userManager.userLanguage)), action: {
                                if let url = URL(string: Constant.appstoreURL) {
                                    UIApplication.shared.open(url)
                                }
                            }))
                        }
                    }

                
                // Popup for upload new project
                UploadPopup(
                    isEdit: false,
                    show: $newProject.isShowUploadPopup,
                    cat: $newProject.currentCat,
                    projectName: $newProject.projectName,
                    searchText: $newProject.jobSiteName,
                    siteSelected: $newProject.jobSiteValue,
                    isInQueue: $newProject.isInQueue
                ) { jobSite, useARMarker, coordinateSetting, linkDashboard, shouldInterpolate, vCoord, hCoord, cat in
                    guard let receiveUrl = newProject.url else {
                        return
                    }
                    savedProjectName = newProject.projectName
                    
                    guard let tmpCat = productData.saveProduct(
                        title: newProject.projectName,
                        jobsiteId: jobSite,
                        zipFileUrl: receiveUrl,
                        cat: nil,
                        coordinateSetting: coordinateSetting,
                        linkDashboard: linkDashboard,
                        verticalCoordinate: vCoord,
                        horizontalCoordinate: hCoord
                    ) else {
                        return
                    }
                    
                    guard let zipUrl = productData.getZipFile(cat: tmpCat) else { return }
                    uploadQueue.enqueue(
                        .projectZip(
                            cat: tmpCat,
                            jobsiteId: jobSite,
                            fileURL: zipUrl,
                            useARMarker: useARMarker,
                            coordinateSetting: coordinateSetting,
                            linkDashboard: linkDashboard,
                            shouldInterpolate: shouldInterpolate
                        )
                    )
                }
                .environmentObject(userManager)
                .environmentObject(productData)
                .environmentObject(editProject)
                
                // Popup for edit project
                UploadPopup(
                    isEdit: true,
                    show: $editProject.isShowUploadPopup,
                    cat: $editProject.currentCat,
                    projectName: $editProject.projectName,
                    searchText: $editProject.jobSiteName,
                    siteSelected: $editProject.jobSiteValue,
                    isInQueue: $editProject.isInQueue
                ) { jobSite, useARMarker, coordinateSetting, linkDashboard, shouldInterpolate, vCoord, hCoord, cat in
                    guard var cat = cat else { return }
                    // Update coordinate
                    cat.vertical = vCoord
                    cat.horizontal = hCoord
                    // Update title
                    productData.updateTitle(for: cat, title: cat.title)
                    // Update jobsite
                    productData.updateJobSite(
                        for: cat,
                        jobSiteId: cat.jobsiteId ?? "",
                        coordinateSetting: coordinateSetting,
                        linkDashboard: linkDashboard
                    )
                    
                    guard let zipUrl = productData.getZipFile(cat: cat) else { return }
                    // Update createDate & captureDate to the time this upload starts
                    // so the project is sorted correctly while uploading
                    cat = productData.refreshUploadDate(for: cat)
                    uploadQueue.enqueue(
                        .projectZip(
                            cat: cat,
                            jobsiteId: jobSite,
                            fileURL: zipUrl,
                            useARMarker: useARMarker,
                            coordinateSetting: coordinateSetting,
                            linkDashboard: linkDashboard,
                            shouldInterpolate: shouldInterpolate
                        )
                    )
                }
                .environmentObject(userManager)
                .environmentObject(productData)
                .environmentObject(editProject)
                
                RenameAlert(presentedAsModal: $isShowRenameAlert) { newTitle in
                    guard let editingCat = editProject.currentCat else { return }
                    guard let zipUrl = productData.getZipFile(cat: editingCat) else { return }
                    // Update createDate & captureDate to the time this upload starts
                    // so the project is sorted correctly while uploading
                    let currentCat = productData.refreshUploadDate(for: editingCat)
                    uploadQueue.enqueue(
                        .projectZip(
                            cat: currentCat,
                            jobsiteId: currentCat.jobsiteId ?? "",
                            fileURL: zipUrl,
                            useARMarker: editProject.isCurrentAR,
                            coordinateSetting: currentCat.coordinateSetting,
                            linkDashboard: currentCat.linkDashboard,
                            shouldInterpolate: true
                        )
                    )
                }
                .environmentObject(userManager)
                .environmentObject(productData)
                .environmentObject(uploadProject)
                .environmentObject(editProject)
                
                BaseUploadPopup(
                    show: $uploadProject.isShowARUploadPopup,
                    cat: $uploadProject.currentCat,
                    projectName: $uploadProject.projectName,
                    jobsite: $uploadProject.jobSiteValue,
                    isCurrentAR: $uploadProject.isCurrentAR,
                    isShowGroupware: $isShowSelectFileFromGroupware,
                    groupwareSelected: $groupwareSelected,
                    groupwareTypeSelected: $groupwareTypeSelected,
                    dataTypeSelected: $arUploadCase,
                    handler: { jobSite, cat, fileURL, fileName, sourceFileNames, ar_color in
                        guard let cat = cat, let fileURL = fileURL else { return }
                        uploadQueue.enqueue(
                            UploadJob(
                                cat: cat,
                                jobsiteId: jobSite,
                                kind: .arFile(
                                    UploadJob.ARFileParameters(
                                        fileURL: fileURL,
                                        fileName: fileName,
                                        arColor: ar_color ?? "",
                                        sourceFileNames: sourceFileNames
                                    )
                                )
                            )
                        )
                    },
                    onUploadGroupware: { cat, jobsiteId, groupwareSelected, newARColor in
                        uploadQueue.enqueue(
                            UploadJob(
                                cat: cat,
                                jobsiteId: jobsiteId,
                                kind: .arData(
                                    UploadJob.ARDataParameters(
                                        source: .groupware(groupwareSelected),
                                        arColor: newARColor
                                    )
                                )
                            )
                        )
                    }
                )
                .environmentObject(userManager)
                .environmentObject(productData)
                .environmentObject(uploadQueue)
                
                GroupwarePopup(
                    isShow: $isShowSelectFileFromGroupware,
                    groupwareTypeSelected: $groupwareTypeSelected,
                    uploadCase: $arUploadCase,
                    jobsite: $uploadProject.jobSiteValue,
                    handler: { groupware in
                        groupwareSelected = groupware
                    }
                )
                .zIndex(10)
                .environmentObject(userManager)
                .environmentObject(productData)
                
                ProjectDetailTransitionPopup(handler: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        navigateToProjectDetail = true
                    }
                }, show: $isShowProjectDetailPopup, projectName: $savedProjectName)
                .environmentObject(userManager)
                .environmentObject(productData)
                
                InsufficientPhotoPopup(uploadProject: uploadProject).environmentObject(userManager)

                UploadBatchResultPopup(result: batchResults.first) {
                    if !batchResults.isEmpty {
                        batchResults.removeFirst()
                    }
                }
                .zIndex(11)
                .environmentObject(userManager)
            }
            .onLoad {
                userManager.getUserInfo {
                    productData.updateSelectedUser()
                }
                
                productData.$updatedCat.sink { updatedCat in
                    if navigateCat?.id == updatedCat?.id {
                        navigateCat = updatedCat
                    }
                }
                .store(in: &cancellables)

                uploadQueue.configure(
                    transportFactory: AppUploadTransportFactory(environment: transportEnvironment)
                )

                productData.onProjectsRemoved = { ids in
                    ids.forEach { uploadQueue.remove(catId: $0) }
                }

                uploadQueue.onBatchFinished = { result in
                    batchResults.append(result)
                }
            }
            .onChange(of: cancelUploadProject.isCancelDownload) { newValue in
                if (newValue) {
                    // Should cancel all upload process when user logout or no network
                    uploadQueue.abortAll(reason: .sessionEnded)
                    cancelUploadProject.isCancelDownload.toggle()
                }
            }
            .onChange(of: languageObserver.currentLanguage) { newValue in
                uploadQueue.abortAll(reason: .sessionEnded)
            }
        }
    }
    
    private var transportEnvironment: UploadTransportEnvironment {
        UploadTransportEnvironment(
            uploadTask: uploadTask,
            productData: productData,
            uploadProject: uploadProject,
            onProjectIdAssigned: { projectId, jobsiteId, cat in
                guard var target = navigateCat, target.id == cat.id else { return }
                target.projectId = projectId
                target.jobsiteId = jobsiteId
                navigateCat = target
            }
        )
    }
}

// 左寄せ
extension View {
    func leftAligned() -> some View {
        return self.modifier(LeftAligned())
    }
}

struct LeftAligned: ViewModifier {
    func body(content: Content) -> some View {
        HStack {
            content
            Spacer()
        }
    }
}
