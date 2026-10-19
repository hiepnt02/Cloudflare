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
    @State private var receiveUrl: URL?
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
    
    @State var isShowRenameAlert: Bool = false
    
    @State private var isAttentionPopup = false
    
    @StateObject var languageObserver = LanguageChangeObserver()
    
    @State private var isShowSelectFileFromGroupware: Bool = false
    
    @State private var groupwareSelected: GroupwareModel? = nil
    @State private var groupwareTypeSelected: GroupwareType = GroupwareType.dashboard
    @State private var arUploadCase: UploadCase = .Ifc
    
    var body: some Scene {
        WindowGroup{
            ZStack {
                StartView(navigateToProjectDetail: $navigateToProjectDetail, navigateCat: $navigateCat, isShowRenameAlert: $isShowRenameAlert)
                    .onOpenURL { url in
                        newProject.isShowUploadPopup = true
                        newProject.jobSiteValue = nil
                        newProject.isCreate = true
                        newProject.currentCat = navigateCat
                        receiveUrl = url
                    }
                    .environmentObject(productData)
                    .environmentObject(userManager)
                    .environmentObject(themeManager)
                    .environmentObject(uploadProject)
                    .environmentObject(editProject)
                    .environmentObject(cancelUploadProject)
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
                
                //AttentionPopup(show: $isAttentionPopup,isCrate:$uploadProject.isCreate).environmentObject(userManager)
                
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
                    guard let receiveUrl = receiveUrl else {
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
                    
                    productData.uploadProjectQueue.enqueue(
                        ProjectUploadModel(
                            jobsiteId: jobSite,
                            useARMarker: useARMarker,
                            coordinateSetting: coordinateSetting,
                            linkDashboard: linkDashboard,
                            shouldInterpolate: shouldInterpolate,
                            url: receiveUrl,
                            cat: tmpCat)
                    )
                    
                    if !uploadProject.isUploading {
                        checkUploadProjectQueue()
                    }
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
                    productData.uploadProjectQueue.enqueue(
                        ProjectUploadModel(
                            jobsiteId: jobSite,
                            useARMarker: useARMarker,
                            coordinateSetting: coordinateSetting,
                            linkDashboard: linkDashboard,
                            shouldInterpolate: shouldInterpolate,
                            url: zipUrl,
                            cat: cat)
                    )

                    if !uploadProject.isUploading {
                        checkUploadProjectQueue()
                    }
                }
                .environmentObject(userManager)
                .environmentObject(productData)
                .environmentObject(editProject)
                
                RenameAlert(presentedAsModal: $isShowRenameAlert) { newTitle in
                    guard let currentCat = editProject.currentCat else { return }
                    guard let zipUrl = productData.getZipFile(cat: currentCat) else { return }
                    productData.uploadProjectQueue.enqueue(
                        ProjectUploadModel(
                            jobsiteId: currentCat.jobsiteId ?? "",
                            useARMarker: editProject.isCurrentAR,
                            coordinateSetting: currentCat.coordinateSetting,
                            linkDashboard: currentCat.linkDashboard,
                            shouldInterpolate: true,
                            url: zipUrl,
                            cat: currentCat)
                    )

                    if !uploadProject.isUploading {
                        checkUploadProjectQueue()
                    }
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
                    handler: { jobSite, useARMarker, cat, fileURL, fileName, coordinateSetting, linkDashboard, shouldInterpolate, isAR, ar_color  in
                        if(isAR){
                            if !uploadProject.isUploading {
                                uploadProject.projectId = cat!.id
                                uploadARFile(with: jobSite ,cat: cat! ,fileUrl:fileURL!, fileName: fileName, ar_color: ar_color ?? "")
                            }
                            else{
                                isAttentionPopup = true
                            }
                        } else {
                            guard let receiveUrl = fileURL else {
                                return
                            }
                            let tmpCat = productData.saveProduct(
                                title: uploadProject.projectName,
                                jobsiteId: jobSite,
                                zipFileUrl: receiveUrl,
                                cat:uploadProject.currentCat,
                                coordinateSetting: coordinateSetting,
                                linkDashboard: linkDashboard,
                                verticalCoordinate: "",
                                horizontalCoordinate: ""
                            )
                            if !uploadProject.isUploading {
                                if tmpCat != nil {
                                    uploadProject.currentCat = tmpCat
                                    navigateCat = uploadProject.currentCat
                                    uploadProject.projectId = navigateCat?.id ?? ""
                                    uploadZipFile(with: jobSite, useARMarker: useARMarker, coordinateSetting: coordinateSetting, linkDashboard: linkDashboard, shouldInterpolate: shouldInterpolate, zipUrl: receiveUrl, cat: navigateCat!)
                                }
                            } else {
                                isAttentionPopup = true
                            }
                        }
                    },
                    onUploadGroupware: { cat, jobsiteId, groupwareSelected, newARColor in
                        uploadARGroupware(cat: cat, jobsiteId: jobsiteId, groupware: groupwareSelected, arColor: newARColor)
                    }
                )
                .environmentObject(userManager)
                .environmentObject(productData)
                
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
            }
            .onChange(of: cancelUploadProject.isCancelDownload) { newValue in
                if (newValue) {
                    // Should cancel all upload process when user logout or no network
                    uploadTask.cancelUpload()
                    cancelUploadProject.isCancelDownload.toggle()
                    productData.uploadProjectQueue.dequeueAll()
                }
            }
            .onChange(of: languageObserver.currentLanguage) { newValue in
                productData.uploadProjectQueue.dequeueAll()
            }
        }
    }
    
    private func uploadARGroupware(
        cat: Cat,
        jobsiteId: String,
        groupware: GroupwareModel,
        arColor: String
    ) {
        uploadProject.projectId = cat.id
        uploadProject.isUploading = true
        uploadProject.uploadPercentage = 0
        
        productData.uploadARGroupware(
            cat: cat,
            jobsiteId: jobsiteId,
            groupware: groupware,
            arColor: arColor,
            completion: { result in
                Task { @MainActor in
                    uploadProject.uploadPercentage = 0.5
                    try await productData.fetchProjectList(
                        status: productData.currentSelectStatus,
                        searchStr: productData.currentSearchStr,
                        fromDate: nil,
                        toDate: nil,
                        site:nil,
                        isRemoved: false,
                        rtkFilterMode: 2
                    )
                    
                    uploadProject.uploadPercentage = 1.0
                    uploadProject.isUploading = false
                    APAlert.shared.showAlertWithTheme(
                        title: "",
                        message: "UPLOAD_COMPLETED".localized(userManager.userLanguage),
                        buttonTitle: "CLOSE".localized(userManager.userLanguage),
                        userManager: userManager
                    )
                }
            }
        )
    }
    
    // Check if there is any project in the queue.
    // If there is, upload the project and delete it from the queue.
    private func checkUploadProjectQueue() {
        if let project = productData.uploadProjectQueue.dequeue(),
           let category = project.cat,
           let zipUrl = productData.getZipFile(cat: category) {
            uploadProject.resetData()
            uploadProject.projectId = category.id
            uploadProject.currentCat = category
            uploadProject.projectName = category.title
            uploadProject.jobSiteName = jobSiteName(project.jobsiteId)
            uploadProject.jobSiteValue = jobSiteValue(project.jobsiteId)
            uploadProject.isCreate = false
            uploadFile(with: project.jobsiteId, useARMarker: project.useARMarker, coordinateSetting: project.coordinateSetting, linkDashboard: project.linkDashboard, shouldInterpolate: project.shouldInterpolate, zipUrl: zipUrl, cat: category)
        }
    }
    
    private func jobSiteName(_ jobsiteId: String?) -> String {
        if let site = productData.jobSite?.sites.first(where: {$0.id == jobsiteId}) {
            return site.name
        }
        return ""
    }

    private func jobSiteValue(_ jobsiteId: String?) -> JobSite.Site? {
        return productData.jobSite?.sites.first(where: {$0.id == jobsiteId})
    }
    
    func uploadFile(with jobSite: String, useARMarker: Bool, coordinateSetting: Bool, linkDashboard: Bool, shouldInterpolate: Bool, zipUrl: URL, cat:Cat) {
        uploadTask.uploadStream(with: cat, fileUrl: zipUrl, jobsite: jobSite, useARMarker: useARMarker, coordinateSetting: coordinateSetting, linkDashboard: linkDashboard, shouldInterpolate: shouldInterpolate)
        
        uploadTask.uploadProgress = { progress in
            DispatchQueue.main.async {
                if uploadProject.isUploading == false {
                    uploadProject.isUploading = true
                }
                uploadProject.uploadPercentage = progress
            }
        }
        
        uploadTask.responseHandler = { resp in
            DispatchQueue.main.async {
                Task {
                    productData.removeTempFile()
                    
                    if resp == nil{
                        // Reset data of uploadProject
                        uploadProject.isUploading = false
                        // Check in Queue to upload next project if that exist
                        checkUploadProjectQueue()
                        return
                    }
                    if resp!.isShortageImage != nil && resp!.isShortageImage! {
                        try await productData.removeLocalProjectWithUpload(id: cat.id)
                        try await productData.fetchProjectList(status: productData.currentSelectStatus, searchStr: productData.currentSearchStr, fromDate: nil, toDate: nil,site:nil, isRemoved: false, rtkFilterMode: 2)
                        uploadProject.isInsufficientPhoto = true
                    }
                    else{
                        uploadProject.isUploaded = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            uploadProject.isUploaded = false
                        }
                        guard let projectId = resp?.projectId else {
                            return
                        }
                        let filteredProducts = productData.products.filter { item in
                            item.id == cat.id
                        }
                        
                        if !filteredProducts.isEmpty{
                            try await productData.removeLocalProjectWithUpload(id: cat.id)
                            try await productData.fetchProjectList(
                                status: productData.currentSelectStatus,
                                searchStr: productData.currentSearchStr,
                                fromDate: nil,
                                toDate: nil,
                                site:nil,
                                isRemoved: false,
                                rtkFilterMode: 2
                            )
                        }
                        productData.updateProjectId(projectId, jobsiteId: jobSite, for: cat)
                        if navigateCat != nil{
                            navigateCat?.projectId = projectId
                            navigateCat?.jobsiteId = jobSite
                        }
                        productData.remove(cat)
                    }
                    
                    // Reset data of uploadProject
                    uploadProject.isUploading = false
                    // Check in Queue to upload next project if that exist
                    checkUploadProjectQueue()
                }
            }
        }
    }
    
    func uploadARFile(with jobSite: String, cat:Cat, fileUrl: URL, fileName: String, ar_color:String) {
        uploadTask.uploadARStream(with: cat, jobsite: jobSite ,fileUrl: fileUrl, fileName: fileName,ar_color: ar_color)
        
        uploadTask.uploadProgress = { progress in
            DispatchQueue.main.async {
                if uploadProject.isUploading == false {
                    uploadProject.isUploading = true
                }
                uploadProject.uploadPercentage = progress
                
                // Show alert when upload ar complete
                if progress == 1.0 {
                    APAlert.shared.showAlertWithTheme(
                        title: "",
                        message: "UPLOAD_COMPLETED".localized(userManager.userLanguage),
                        buttonTitle: "CLOSE".localized(userManager.userLanguage),
                        userManager: userManager
                    )
                }
            }
        }
        
        uploadTask.responseHandler = { resp in
            DispatchQueue.main.async {
                Task {
                    try await productData.fetchProjectList(status: productData.currentSelectStatus, searchStr: productData.currentSearchStr, fromDate: nil, toDate: nil,site:nil, isRemoved: false, rtkFilterMode: 2)
                    uploadProject.isUploading = false
                    uploadProject.isUploaded = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        uploadProject.isUploaded = false
                    }
                    productData.removeARTempFile(fileName: fileName)
                }
            }
        }
    }
    
    func uploadZipFile(with jobSite: String, useARMarker: Bool, coordinateSetting: Bool, linkDashboard: Bool, shouldInterpolate: Bool, zipUrl: URL, cat:Cat) {
        uploadTask.uploadZipStream(with: cat, fileUrl: zipUrl, jobsite: jobSite, useARMarker: useARMarker, coordinateSetting: coordinateSetting, linkDashboard: linkDashboard, shouldInterpolate: shouldInterpolate)
        
        uploadTask.uploadProgress = { progress in
            DispatchQueue.main.async {
                if uploadProject.isUploading == false {
                    uploadProject.isUploading = true
                }
                uploadProject.uploadPercentage = progress
            }
        }
        
        uploadTask.responseHandler = { resp in
            DispatchQueue.main.async {
                Task {
                    uploadProject.isUploading = false
                    productData.removeTempFile()
                    if resp == nil{
                        return
                    }
                    if resp!.isShortageImage != nil && resp!.isShortageImage! {
                        uploadProject.isInsufficientPhoto = true
                    } else{
                        try await productData.fetchProjectList(
                            status: productData.currentSelectStatus,
                            searchStr: productData.currentSearchStr,
                            fromDate: nil,
                            toDate: nil,
                            site:nil,
                            isRemoved: false,
                            rtkFilterMode: 2
                        )
                        uploadProject.isUploaded = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            uploadProject.isUploaded = false
                        }
                        guard let projectId = resp?.projectId else {
                            return
                        }
                        
                        let filteredProducts = productData.products.filter { item in
                            item.id == cat.id
                        }
                        productData.updateProjectId(projectId, jobsiteId: jobSite, for: cat)
                        productData.remove(cat)
                    }
                }
            }
        }
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
