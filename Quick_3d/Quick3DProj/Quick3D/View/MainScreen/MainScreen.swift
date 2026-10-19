//
//  ContentView.swift
//  Quick3D
//  Created by 木皿直規 on 2022/04/04.
//

import SwiftUI

//---------------------------
// MARK: - MainScreen
//---------------------------
struct MainScreen: View {

    // MARK: - Filter State
    @State private var searchStr = ""
    @State private var inputStr = ""
    @State private var selectedStatus: Status = .all
    @State private var fromDate: Date?
    @State private var toDate: Date? = Date()
    @State private var jobsite: JobSite.Site?
    @State private var rtkFilterMode = 2 // GPS:0 RTK:1 RTK/GPS:2
    @State private var isPointRemoveSelected = false

    // MARK: - UI State
    @State private var isLoading: Bool = false
    @State private var isEditing = false
    @State private var isShowSupport = false
    @State private var isShowLoginAlert: Bool = false
    @State private var isShowConfirmDelete: Bool = false
    @State private var isShowDisclaimerAlert: Bool = !UserDefaults.standard.bool(forKey: "didDisclaimerKey")
    @State private var isProductDetailActive = false
    @State private var currentCat: Cat?
    @State private var selectedItem = [String]()
    @State private var isShowShootWarning = false
    @State private var isShowSingleDeletePopup = false
    @State private var deleteCat: Cat?
    @State private var isShowExportComplete = false
    @State private var isShowSettingPopup = false
    @State private var accountWebViewIsShown: Bool = false
    @State private var selectedSort: SortOption = UserSession.sortOption

    // MARK: - Camera / AR State
    @State private var isShowCameraView = false
    @State private var isShowARView = false
    @State private var isShowPointCloudView = false

    // MARK: - AR List Popup State
    @State private var showARListPopup = false
    @State private var selectCat: Cat = Cat(
        userId: nil, id: "", title: "", folderName: "",
        jobsiteId: "", createDate: Date(), captureDate: Date(),
        sourceStr: "", numberOfImage: 0
    )

    // MARK: - Rename State
    @State private var renameCat: Cat = Cat(
        userId: nil, id: "", title: "", folderName: "",
        jobsiteId: "", createDate: Date(), captureDate: Date(),
        sourceStr: "", numberOfImage: 0
    )

    // MARK: - Filter Popup State
    @State private var isShowFilterAlert: Bool = false
    @State private var isShowFromDateSelect = false
    @State private var isShowToDateSelect = false

    // MARK: - JobSite Autocomplete State
    @State private var jobSiteSearchText = ""
    @State private var jobSiteInputText = ""
    @State private var isPopupJobSitesPresented: Bool = false
    @State private var tfJobSitePosition: CGPoint = .zero
    @State private var tfJobSiteWidth: CGFloat = 0
    @State private var tfJobSiteHeight: CGFloat = 0

    // MARK: - Layout State
    @State private var contentWidth: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewARUUID = UUID()
    @State private var shouldScrollUp = false
    @AppStorage("isListView") private var isListView: Bool = false

    // MARK: - Focus
    @FocusState private var focusStateSearch: Bool
    @FocusState private var focusStateJobSite: Bool
    @State private var isKeyboardShow = false

    // MARK: - Task
    @State private var fetchTask: Task<Void, Never>? = nil

    // MARK: - Environment
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var productData: ProductData

    // MARK: - Bindings
    @Binding var navigateToProjectDetail: Bool
    @Binding var navigateCat: Cat?
    @Binding var isActiveContent: Bool
    @Binding var isShowLoginWebview: Bool
    @Binding var isShowRenameAlert: Bool

    // MARK: - Misc
    var initialSet = InitialSet()
    internal let inspection = Inspection<Self>()
    let uploadTask = UploadBackgroundTask()

    // MARK: - Computed Properties
    private var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    private var isLogin: Bool {
        userManager.userInfo != nil
    }


    var status: [Status] {
        userManager.isARAvailable ?
            [.all, .uploadWating, .uploadCompleted, .sfmProcessing, .transformationCompleted, .verificationCompleted, .dashboardUploadCompleted, .arUploadCompleted] :
            [.all, .uploadWating, .uploadCompleted, .sfmProcessing, .transformationCompleted, .verificationCompleted, .dashboardUploadCompleted]
    }

    private var userList: [User] {
        var initialList: [User] = [.init(name: "ALL".localized(userManager.userLanguage))]
        if let filterUser = productData.userList.first(where: { $0.userId == userManager.userInfo?.userId }) {
            initialList.append(.init(userId: userManager.userInfo?.userId, name: filterUser.name))
        }
        var list = productData.userList
        list.removeAll(where: { $0.userId == userManager.userInfo?.userId })
        list.removeAll(where: { $0.name.isEmpty })
        initialList.append(contentsOf: list)
        return initialList
    }

    private var jobSiteList: [JobSite.Site] {
        let allSite = JobSite.Site(id: "", name: "ALL".localized(userManager.userLanguage))
        guard let list = productData.jobSite?.sites else { return [allSite] }
        return [allSite] + list
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return "\("VERSION".localized(userManager.userLanguage)) \(version) (\(build))"
    }

    // MARK: - Actions
    private func performLogout() {
        userManager.logout()
        productData.removeRemoteProject()
        productData.removeJobsiteData()
        productData.resetTotalCount()
        isActiveContent = false
    }

    private func performFetch() async throws {
        productData.sortOption = selectedSort
        try await productData.fetchProjectList(
            status: selectedStatus,
            searchStr: searchStr,
            fromDate: fromDate,
            toDate: toDate,
            site: jobsite,
            isRemoved: isPointRemoveSelected,
            rtkFilterMode: rtkFilterMode
        )
    }

    private func fetchProjects() {
        fetchTask?.cancel()
        isLoading = true
        fetchTask = Task {
            defer { isLoading = false }
            do {
                try await performFetch()
                if !Task.isCancelled { shouldScrollUp = true }
            } catch {
                if !(error is CancellationError) {
                    print("Fetch error: \(error)")
                }
            }
        }
    }

    private func applySort() {
        UserSession.sortOption = selectedSort
        productData.sortOption = selectedSort
        productData.reapplySortLocally()
        shouldScrollUp = true
    }

    private func strRTKLabel(rtkValue: Int) -> String {
        switch rtkValue {
        case 0: return "GPS"
        case 1: return "RTK"
        default: return "GPS RTK"
        }
    }

    //---------------------------
    // MARK: - Body View
    //---------------------------
    var body: some View {
        NavigationView {
            GeometryReader { contentGeo in
                ZStack(alignment: .center) {
                    VStack(spacing: 0) {
                        headerToolbar()
                        bodyContent()
                    }

                    ButtonOpenCamera(onClick: { isShowShootWarning = true })
                        .position(
                            x: contentWidth - (isIPhone ? 10 : 80),
                            y: contentHeight - (isIPhone ? 20 : 50)
                        )
                        .tag(18)
                        .zIndex(1.0)

                    if isEditing {
                        SelectedManagerView(selectedCount: selectedItem.count, allowTap: !isShowConfirmDelete, didTapDelete: {
                            if selectedItem.count > 0 { isShowConfirmDelete = true }
                        }, didTapCancel: {
                            NotificationCenter.default.post(name: .updateCell, object: nil)
                            selectedItem.removeAll()
                            isEditing = false
                        })
                    }

                    if userManager.showLicenseAlert {
                        LicenseAlertPopup(
                            isShow: $userManager.showLicenseAlert,
                            pointCloudBgcolor: Color(hex: userManager.setting.pointCloudBgcolor)
                                .opacity(userManager.setting.pointCloudBgalpha)
                        )
                    }

                    if isShowConfirmDelete {
                        ConfirmDeletePopup(
                            show: $isShowConfirmDelete,
                            alertMessage: String(format: "\("WANT_TO_DELETE".localized(userManager.userLanguage))", selectedItem.count)
                        ) {
                            productData.removeProducts(ids: selectedItem)
                            NotificationCenter.default.post(name: .updateCell, object: nil)
                            selectedItem.removeAll()
                            isEditing = false
                        }
                    }

                    FilterPopup(presentedAsModal: $isShowFilterAlert, currentSearchStr: $searchStr, currentStatus: $selectedStatus) { fromDate, toDate, site in
                        self.fromDate = fromDate
                        self.toDate = toDate
                        self.jobsite = site
                        fetchProjects()
                    }
                    .environmentObject(userManager)
                    .tag(24)

                    if isShowShootWarning {
                        CaptureWarningPopup(
                            isShow: $isShowShootWarning,
                            isShowCameraView: $isShowCameraView)
                        {
                            Pix4DInfo().openPix4DCapture()
                        }
                        .zIndex(2.0)
                        .tag(19)
                    }

                    if let currentCat = currentCat {
                        NavigationLink("", destination: ProductDetailView(cat: currentCat, forceShowJobSitePopup: false, isActiveContent: $isActiveContent), isActive: $isProductDetailActive)
                    }
                    if let navigateCat = navigateCat {
                        NavigationLink("", destination: ProductDetailView(cat: navigateCat, forceShowJobSitePopup: true, isActiveContent: $isActiveContent), isActive: $navigateToProjectDetail)
                    }

                    if isShowSingleDeletePopup || deleteCat != nil {
                        DeletePopup(show: $isShowSingleDeletePopup, cat: deleteCat)
                            .tag(17)
                    }

                    if isShowExportComplete {
                        ExportSuccessPopup(isShow: $isShowExportComplete)
                            .tag(20)
                    }

                    if isShowSettingPopup {
                        SettingPopup(
                            isShow: $isShowSettingPopup,
                            pointCloudBgcolor: Color(hex: userManager.setting.pointCloudBgcolor)
                                .opacity(userManager.setting.pointCloudBgalpha)
                        )
                    }

                    if isShowLoginAlert {
                        LoginAlert(isShow: $isShowLoginAlert, loginHandler: {
                            isShowLoginWebview = true
                        }, logoutHandler: {
                            performLogout()
                        })
                        .frame(width: 550, height: 400)
                        .cornerRadius(20)
                        .offset(x: 0, y: isIPhone ? 0 : -200)
                    }

                    if isShowDisclaimerAlert {
                        DisclaimerAlert(isShow: $isShowDisclaimerAlert)
                            .frame(width: isIPhone ? 630 : 900, height: isIPhone ? 290 : 700)
                            .offset(x: 0, y: isIPhone ? 0 : -50)
                    }

                    if showARListPopup || self.selectCat != nil {
                        ARListPopup(show: $showARListPopup, cat: self.selectCat)
                            .tag(40)
                    }

                    SearchListPopup<JobSite.Site>(
                        isShow: $isPopupJobSitesPresented,
                        viewPosition: $tfJobSitePosition,
                        viewWidth: $tfJobSiteWidth,
                        viewHeight: $tfJobSiteHeight,
                        listOriginal: jobSiteList,
                        searchKey: $jobSiteSearchText
                    ) { itemSelected in
                        self.jobsite = itemSelected
                        jobSiteSearchText = ""
                        jobSiteInputText = itemSelected.name
                        fetchProjects()
                    }
                    .environmentObject(userManager)
                }
                .onAppear {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        contentWidth = contentGeo.size.width
                        contentHeight = contentGeo.size.height
                    }
                }
            }
            .ignoresSafeArea(.keyboard, edges: .all)
            .background(userManager.setting.bodyColor)
            .sheet(isPresented: $isShowSupport) {
                let url = userManager.userLanguage == "ja" ?
                URL(string: "https://support-quick3d.smartconstruction.com/hc/ja") :
                URL(string: "https://support-quick3d.smartconstruction.com/hc/en-us")
                WebView(url: url!)
            }
            .sheet(isPresented: $userManager.showLicenseRegister) {
                WebView(url: URL(string: Constant.licenseAssignUrl)!)
            }
            .fullScreenCover(isPresented: $accountWebViewIsShown) {
                AccountWebView()
            }
            .onLoad {
                userManager.getSetting()
                if isLogin { productData.fetchJobSiteData() }
                Task {
                    try await userManager.fetchLicense()
                    let numOfLicenses = userManager.numOfLicenses
                    if numOfLicenses > 0, numOfLicenses < 1 {
                        userManager.showLicenseAlert = true
                    } else if numOfLicenses <= 0 {
                        alert(title: "NoLicense".localized(userManager.userLanguage), message: "") {
                            performLogout()
                        }
                    }
                }
            }
            .overlay {
                if isShowFromDateSelect {
                    DatePickerOverlay(dateBinding: Binding<Date>(get: { fromDate ?? Date() }, set: {
                        fromDate = $0
                        isShowFromDateSelect = false
                        fetchProjects()
                    }), otherDate: toDate, isToDate: false, isIPhone: isIPhone) {
                        isShowFromDateSelect = false
                    }
                }
            }
            .overlay {
                if isShowToDateSelect {
                    DatePickerOverlay(dateBinding: Binding<Date>(get: { toDate ?? Date() }, set: {
                        toDate = $0
                        isShowToDateSelect = false
                        fetchProjects()
                    }), otherDate: fromDate, isToDate: true, isIPhone: isIPhone) {
                        isShowToDateSelect = false
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .navigationViewStyle(.stack)
        .buttonStyle(PlainButtonStyle())
        .onChange(of: jobSiteList) { value in
            if isLogin {
                jobsite = jobSiteList.first
                jobSiteInputText = jobSiteList.first?.name ?? ""
                jobSiteSearchText = ""
                fetchProjects()
            }
        }
        .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    //---------------------------
    // MARK: - Structural UI Components
    //---------------------------
    private func headerToolbar() -> some View {
        HStack {
            HStack(alignment: .bottom, spacing: isIPhone ? 5 : 15) {
                StatusFilterField(
                    selectedStatus: $selectedStatus,
                    statusList: status,
                    isIPhone: isIPhone,
                    onSelect: fetchProjects
                )

                UserFilterField(
                    userList: userList,
                    isIPhone: isIPhone,
                    onSelect: fetchProjects
                )

                JobSiteFilterField(
                    jobSiteInputText: $jobSiteInputText,
                    jobSiteSearchText: $jobSiteSearchText,
                    isPopupJobSitesPresented: $isPopupJobSitesPresented,
                    tfJobSitePosition: $tfJobSitePosition,
                    tfJobSiteWidth: $tfJobSiteWidth,
                    tfJobSiteHeight: $tfJobSiteHeight,
                    jobsite: $jobsite,
                    focusStateJobSite: _focusStateJobSite,
                    isIPhone: isIPhone,
                    onClearOrSubmit: fetchProjects
                )

                SearchFieldView(
                    inputStr: $inputStr,
                    searchStr: $searchStr,
                    focusStateSearch: _focusStateSearch,
                    isIPhone: isIPhone,
                    onSearchTriggered: fetchProjects
                )

                RTKFilterButtonView(
                    rtkFilterMode: $rtkFilterMode,
                    isIPhone: isIPhone,
                    labelProvider: strRTKLabel,
                    onTap: fetchProjects
                )

                PointRemoveFilterButtonView(
                    isPointRemoveSelected: $isPointRemoveSelected,
                    isIPhone: isIPhone,
                    onTap: fetchProjects
                )

                Spacer()
                menuButton()
                helpButton()
                if isLogin { accountButton() }
                else { loginButton() }
            }
            .padding([.bottom, .leading, .trailing], 12)
            .frame(maxWidth: .infinity)
            .background(userManager.setting.themeColor)
        }
        .onAppear {
            print("TOP画面起動ログ")
            AnalyticsHelper.logScreenView(screenName: "TOP画面起動")
        }
        .preferredColorScheme(userManager.setting.colorTheme == .light ? .light : .dark)
        .zIndex(1.0)
    }

    private func bodyContent() -> some View {
        ZStack {
            VStack {
                dateFilterView()

                if isListView {
                    ProjectColumnHeader(
                        isIPhone: isIPhone,
                        isEditing: $isEditing
                    )
                    .padding(.horizontal, isIPhone ? 20 : 30)
                }

                ProjectListView(
                    isEditing: $isEditing,
                    isShowConfirmDelete: $isShowConfirmDelete,
                    isShowRenameAlert: $isShowRenameAlert,
                    isProductDetailActive: $isProductDetailActive,
                    isShowSingleDeletePopup: $isShowSingleDeletePopup,
                    isShowExportComplete: $isShowExportComplete,
                    isLoading: $isLoading,
                    selectedItem: $selectedItem,
                    currentCat: $currentCat,
                    renameCat: $renameCat,
                    deleteCat: $deleteCat,
                    showARListPopup: $showARListPopup,
                    selectCat: $selectCat,
                    isActiveContent: $isActiveContent,
                    isShowCameraView: $isShowARView,
                    isShowPointCloudView: $isShowPointCloudView,
                    contentWidth: $contentWidth,
                    contentHeight: $contentHeight,
                    scrollToTopTrigger: $shouldScrollUp,
                    isListView: $isListView,
                    onRefresh: {
                        try? await performFetch()
                        userManager.getSetting()
                    }
                )
                .padding(.horizontal, isIPhone ? 20 : 30)
            }

            if isLoading {
                ProgressLoadingView(text: "", bgOpacity: 0.3)
                    .ignoresSafeArea()
            }
        }
    }

    private func menuButton() -> some View {
        Menu {
            Button("SELECT".localized(userManager.userLanguage), action: { isEditing = true })
            Button("Setting".localized(userManager.userLanguage), action: {
                userManager.getSetting()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isShowSettingPopup = true
                }
            })
        } label: {
            Image("VerticalMenu")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(userManager.setting.textColor)
                .frame(width: 40, height: 40)
        }
    }

    private func helpButton() -> some View {
        Menu {
            Button("USER_MANUAL".localized(userManager.userLanguage), action: {
                if let url = URL(string: "https://support-quick3d.smartconstruction.com/hc/ja/articles/11060723222937--Smart-Construction-Quick3D-%E3%83%A6%E3%83%BC%E3%82%B6%E3%83%BC%E3%82%AC%E3%82%A4%E3%83%89") {
                    UIApplication.shared.open(url)
                }
            })
            .font(.custom(CustomFonts.FAFreeSolid, size: 10))
            .frame(height: 10)

            Button(action: {
                let urlStr = "https://terms.smartconstruction.com" + (userManager.userLanguage == "ja" ? "/jp/terms-of-use" : "/na/terms-of-use")
                if let url = URL(string: urlStr) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("TERMS_OF_SERVICE".localized(userManager.userLanguage))
            }

            Button("SUPPORT".localized(userManager.userLanguage)) { isShowSupport = true }

            Text(appVersionText)
        } label: {
            let questionIcon = ""
            Text(questionIcon)
                .foregroundColor(userManager.setting.textColor)
                .font(.system(size: 20))
                .frame(height: 40)
        }
    }

    private func accountButton() -> some View {
        Menu {
            if isLogin {
                Text(userManager.userInfo?.name ?? "")
                Text(userManager.userInfo?.email ?? "")
                Button(action: { accountWebViewIsShown.toggle() }) {
                    Text("MANAGE_MY_SMART_CONSTRUCTION_ACCOUNT".localized(userManager.userLanguage))
                }
                Button(action: { performLogout() }) {
                    Text("LOGOUT".localized(userManager.userLanguage))
                }
            }
        } label: {
            AsyncImage(url: URL(string: userManager.userInfo?.picture ?? "")) { image in
                image.resizable()
            } placeholder: {
                Image("blank-user")
                    .resizable()
                    .scaledToFit()
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        }
    }

    private func loginButton() -> some View {
        Button(action: { isShowLoginWebview = true }) {
            Text("")
                .foregroundColor(userManager.setting.textColor)
                .font(.custom(CustomFonts.FAFreeSolid, size: 40))
                .frame(width: 40, height: 40)
                .dynamicTypeSize(DynamicTypeSize.medium)
        }
    }

    private func dateFilterView() -> some View {
        HStack(alignment: .center, spacing: isIPhone ? 8 : 12) {
            Text(String(format: "SEARCH_RESULTS".localized(userManager.userLanguage), productData.hitsTotal, productData.totalResult))
                .foregroundColor(userManager.setting.textColor)
                .font(.system(size: isIPhone ? 15 : 22))

            Spacer(minLength: 0)

            SelectSortView(
                selectedSort: $selectedSort,
                isIPhone: isIPhone,
                onSelect: applySort
            )

            DateRangeView(
                fromDate: $fromDate,
                toDate: $toDate,
                onFromTap: { isShowFromDateSelect.toggle() },
                onToTap: { isShowToDateSelect.toggle() },
                onClear: fetchProjects
            )

            Picker(selection: $productData.groupIndex, label: Text("")) {
                ForEach(GroupMode.allCases, id: \.self) { mode in
                    Text(mode.title.localized(userManager.userLanguage)).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 150)
            .tag(21)
            .background(userManager.setting.colorTheme == .light ? Color(hex: 0xECEDEE) : Color.black.opacity(0.1))
            .foregroundColor(userManager.setting.colorTheme == .light ? Color.black : Color.white)
            .onChange(of: productData.groupIndex) { _ in
                shouldScrollUp = true
            }

            Button(action: { isListView.toggle() }) {
                Image(systemName: isListView ? "square.grid.2x2" : "list.bullet")
                    .font(.system(size: isIPhone ? 16 : 20))
                    .foregroundColor(userManager.setting.textColor)
            }
        }
        .padding(.horizontal, isIPhone ? 20 : 30)
        .padding(.vertical, 8)
    }

    private func alert(title: String?, message: String?, action: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in action() })
        let scene = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .first as? UIWindowScene
        scene?.windows.first?.rootViewController?.present(alert, animated: true)
    }

    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            MainScreen(
                navigateToProjectDetail: .constant(false),
                navigateCat: .constant(nil),
                isActiveContent: .constant(false),
                isShowLoginWebview: .constant(false),
                isShowRenameAlert: .constant(false)
            )
            .previewDevice("iPad Pro (11-inch)")
            .previewInterfaceOrientation(.landscapeRight)
        }
    }

    class InitialSet: NSObject {
        override init() {
            super.init()
            guard !UserDefaults.standard.bool(forKey: "firstRun") else { return }
            UserDefaults.standard.set(true, forKey: "firstRun")
            UserDefaults.standard.set(false, forKey: "didDisclaimerKey")
        }
    }
}
