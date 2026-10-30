//
//  ProductDetailView.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 23/04/2022.
//

import SwiftUI
import Alamofire
import ZIPFoundation
import ARKit
import Combine

struct ProductDetailView: View {
    @State var cat: Cat
    let forceShowJobSitePopup: Bool
    @EnvironmentObject var productData: ProductData
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @State private var isShowLoginWebview = false
    @State private var gaussianProjectId: String?
    @State private var projectViewerChecked = false
    @EnvironmentObject var userManager: UserManager
    
    @State private var url: URL? = nil
    @State private var isShowUploadPopup = false
    @State private var uploadPercentage: Double = 0
    @State private var isShowUploadingView = false
    @State private var isShowUploadedResult = false
    @State private var isUploadedSuccess = false
    @State private var isShowLoninAlert: Bool = false
    @State private var showingLicenseAlert = false
    @State private var isShowViewerMenu = false
    @State private var isShowStatusView = true
    @State private var isShowRenameAlert = false
    @State private var isShowDeletePopup = false
    @State private var isShowPointCloud = true
    @State private var isDownloading = false
    @State private var uploadMessage = ""
    @State private var isShowCalculationPopup = false
    @State private var toggleFit = true
    //    @State private var viewerAction = ViewerAction.ini
    @State private var toggleCalculationMenu = false
    @State private var toggleCalculation = false
    @State private var toggleView = false
    @State private var isShowSizeView = false
    @State private var pointSize: Double = 4.0
    @State var cancellables = Set<AnyCancellable>()
    @Binding var isActiveContent: Bool;
    
    private let isIPhone = UIDevice.current.isIphone
    @State private var isShowLoginSheet = false
    private var isLogin: Bool {
        return userManager.userInfo != nil
    }
    let uploadTask = UploadBackgroundTask()
    
    private var isUploading: Bool {
        return isShowUploadingView || isShowUploadedResult
    }

    private var hasOtherProjectLayers: Bool {
        [cat.las_file, cat.ifc_file, cat.design_file].contains { !($0?.isEmpty ?? true) }
    }
    
    var btnBack : some View {
        HStack() {
            Button(action: {
                if !isUploading {
                    self.presentationMode.wrappedValue.dismiss()
                    userManager.getSetting()
                }
            }) {
                Image("Back2")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(
                        gaussianProjectId != nil || !projectViewerChecked || cat.projectWebUrl(for: LanguageMode(rawValue: userManager.userLanguage)!) == nil ?
                            .white
                        : userManager.setting.textColor
                    )
                    .frame(width: isIPhone ? 30 : 60, height: isIPhone ? 20 : 40)
                    .padding(EdgeInsets(top: isIPhone ? 20 : 30, leading: isIPhone ? 0 : 25, bottom: 0, trailing: 0))
                    .scaledToFit()
            }
        }
    }
    
    var headerBarButtons : some View {
        ZStack() {
            HStack() {
                
                Menu {
                    Button("CHANGE_PROJECT".localized(userManager.userLanguage), action: {
                        self.isShowRenameAlert = true
                    })
                    Button("REMOVE".localized(userManager.userLanguage), action: {
                        self.isShowDeletePopup = true
                    })
                } label: {
                    Button(
                        action: { },
                        label: {
                            Image("VerticalMenu")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(Color.white)
                                .frame(width: isIPhone ? 25 : 40, height: isIPhone ? 25 : 40)
                        }
                    ).padding(EdgeInsets(top: 5, leading: 0, bottom: 0, trailing: 20))
                }
            }
        }
    }
    
    var body: some View {
        ZStack() {
            VStack() {
                if !projectViewerChecked {
                    ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let projectId = gaussianProjectId {
                    GaussianProject3DView(projectId: projectId, title: cat.title)
                        .id(projectId)
                } else {
                ProductWebView(
                    url: cat.projectWebUrl(for: LanguageMode(rawValue: userManager.userLanguage)!),
                    pointCloudUrl: cat.pointCloudFile,
                    cat: cat,
                    updateProjectId: productData.updateProjectId(_:jobsiteId:for:),
                    backToHome: self.backToHome,
                    openSfM: self.openSfM,
                    isActiveContent: $isActiveContent
                )
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .background(
                    cat.projectWebUrl(for: LanguageMode(rawValue: userManager.userLanguage)!) == nil ?
                        .black
                    : userManager.setting.themeColor
                )
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    ProductWebView.webView?.scrollView.isScrollEnabled = true
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
                    ProductWebView.webView?.scrollView.setContentOffset(CGPoint.init(x: 0, y: 0), animated: true)
                    ProductWebView.webView?.scrollView.isScrollEnabled = false
                }
                }
            }
            HStack(alignment: .top) {
                btnBack.position(x: 30, y: 10)
                if cat.projectId == nil || cat.jobsiteId == "" {
                    headerBarButtons.frame(maxWidth:.infinity, alignment: .topTrailing)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
            
            UploadingView(show: $isShowUploadingView, progress: $uploadPercentage)
            UploadingResultView(show: $isShowUploadedResult, success: $isUploadedSuccess, messsage: $uploadMessage)
            RenameAlert(presentedAsModal: $isShowRenameAlert, cat: cat) {newTitle in }
            DeletePopup(show: $isShowDeletePopup, cat: cat)
        }
        .background(.black)
        .alert("NoLicense".localized(userManager.userLanguage), isPresented: $showingLicenseAlert) {
            Button("OK", role: .cancel) {
                showingLicenseAlert = false
                userManager.logout()
                productData.removeRemoteProject()
                productData.removeJobsiteData()
                productData.resetTotalCount()
            }
        }
        .navigationBarHidden(true)
        .edgesIgnoringSafeArea(.bottom)
        .task(id: cat.projectId) {
            projectViewerChecked = false
            gaussianProjectId = nil
            // Native GSX view is for Gaussian-only projects. Mixed projects keep their
            // existing viewer so their point-cloud/design layers and tools stay available.
            if let projectId = cat.projectId, !hasOtherProjectLayers {
                let hasGSX = await GsxProject.isAvailable(projectId: projectId)
                guard !Task.isCancelled, cat.projectId == projectId else { return }
                gaussianProjectId = hasGSX ? projectId : nil
            }
            projectViewerChecked = true
        }
        .onLoad(perform: {
            productData.fetchJobSiteData()
//            productData.fetchARSelectionData()
            if forceShowJobSitePopup {
                isShowUploadPopup = true
            }
        })
    }

    func download() {
        let destination: DownloadRequest.Destination =
            {
                _, _ in
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                let url = documentsDirectory!.appendingPathComponent("test download").appendingPathComponent("archive.zip")

                return (url, [.removePreviousFile, .createIntermediateDirectories])
            }
        guard let projectId = cat.projectId else { return }
        AF.download(URL(string: String(format: Constant.baseUrl + "api/v1/project/%@/download", projectId))!,
                    method: .post,
                    parameters: ["LiDAR": false,
                                 "sfm": false,
                                 "helmet": false,
                                 "referencePoints": true,
                                 "verificationPoints": false,
                                 "images": false,
                                 "qualityReport": false,
                                 "snapshot": ""],
                    encoding: JSONEncoding.default,
                    to: destination)
        .downloadProgress(queue: .main, closure: { (progress) in
            //progress closure
            print(progress.fractionCompleted)
        })
        .response { resp in
            self.isDownloading = false
            switch resp.result {
            case .success(let url):
                guard let url = url else { return }
                let path = url.absoluteString.replacingOccurrences(of: "file://", with: "shareddocuments:///private")
                guard let url = URL(string: path) else { return }
                UIApplication.shared.open(url, options: [:])

            case .failure(let error):
                uploadMessage = error.localizedDescription
                withAnimation(.linear(duration: 0.3)) {
                    isShowUploadedResult = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation(.linear(duration: 0.3)) {
                        isShowUploadedResult = false
                    }
                }
            }
        }
    }
}

extension ProductDetailView {
    
    private func uploadFile(with jobSite: String, useARMarker: Bool, coordinateSetting: Bool, linkDashboard: Bool, shouldInterpolate: Bool) {
        guard let zipUrl = productData.getZipFile(cat: cat) else { return }
        uploadTask.uploadStream(with: cat, fileUrl: zipUrl, jobsite: jobSite, useARMarker: useARMarker, coordinateSetting: coordinateSetting, linkDashboard: linkDashboard, shouldInterpolate: shouldInterpolate)
        uploadTask.uploadProgress = { progress in
            if isShowUploadingView == false {
                withAnimation(.linear(duration: 0.3)) {
                    isShowUploadingView = true
                }
            }
            uploadPercentage = progress
        }
        uploadTask.responseHandler = { resp in
            DispatchQueue.main.async {
                isShowUploadingView = false
                isUploadedSuccess = resp != nil
                uploadMessage = resp != nil ? "UPLOAD_SUCCESS".localized(userManager.userLanguage) : "UPLOAD_ERROR".localized(userManager.userLanguage)
                withAnimation(.linear(duration: 0.3)) {
                    isShowUploadedResult = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.linear(duration: 0.3)) {
                        isShowUploadedResult = false
                    }
                }
                guard let projectId = resp?.projectId else {
                    return
                }
                productData.removeTempFile()
                productData.updateProjectId(projectId, jobsiteId: jobSite, for: cat)
                cat.projectId = projectId
                cat.jobsiteId = jobSite
            }
        }
    }
    
    private func backToHome() {
        self.presentationMode.wrappedValue.dismiss()

    }
    
    private func openSfM() {
        if !isUploading {
            if isLogin {
                userManager.loginProcess(with: UserSession.shared.sessionId ?? "") { success in
                    if success {
                        isShowUploadPopup = true
                    } else {
                        showingLicenseAlert = true
                    }
                }
            } else {
                isShowUploadPopup = true
            }
        }
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}
