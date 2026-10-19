//
//  MainScreen.swift
//  Quick3D
//  Created by 木皿直規 on 2022/04/04.
//

import SwiftUI

//---------------------------
// MARK: - ProjectFilter
//---------------------------
/// Every criterion the project list can be narrowed by. These values always travel
/// together into `ProductData.fetchProjectList`, so they are kept as one value
/// instead of seven separate `@State` properties.
struct ProjectFilter {
    /// GPS:0 RTK:1 RTK/GPS:2 — matches the value `RTKFilterButtonView` cycles through.
    static let rtkModeAll = 2

    var searchStr = ""
    var status: Status = .all
    var fromDate: Date?
    var toDate: Date? = Date()
    var jobsite: JobSite.Site?
    var rtkMode = rtkModeAll
    var isPointRemoved = false

    static func rtkLabel(for rtkMode: Int) -> String {
        switch rtkMode {
        case 0: return "GPS"
        case 1: return "RTK"
        default: return "GPS RTK"
        }
    }
}

//---------------------------
// MARK: - MainScreen
//---------------------------
struct MainScreen: View {

    /// Which of the two date pickers is open, if any. Replaces a pair of booleans
    /// that could both be true at once.
    private enum ActiveDatePicker {
        case from, to
    }

    /// Sizes and insets that used to be inline magic numbers.
    private enum Layout {
        static let cameraButtonInsetIPhone = CGSize(width: 10, height: 20)
        static let cameraButtonInsetIPad = CGSize(width: 80, height: 50)
        static let loginAlertSize = CGSize(width: 550, height: 400)
        static let loginAlertOffsetIPad: CGFloat = -200
        static let disclaimerSizeIPhone = CGSize(width: 630, height: 290)
        static let disclaimerSizeIPad = CGSize(width: 900, height: 700)
        static let disclaimerOffsetIPad: CGFloat = -50
        static let groupPickerWidth: CGFloat = 150
    }

    // MARK: - Filter State
    @State private var filter = ProjectFilter()
    @State private var inputStr = ""

    // MARK: - UI State
    @State private var isLoading: Bool = false
    @State private var isEditing = false
    @State private var isShowSupport = false
    @State private var isShowLoginAlert: Bool = false
    @State private var isShowNoLicenseAlert: Bool = false
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

    // MARK: - AR / Point cloud State
    @State private var isShowARView = false
    @State private var isShowPointCloudView = false
    @State private var showARListPopup = false
    @State private var selectCat: Cat?

    // MARK: - Filter Popup State
    @State private var isShowFilterAlert: Bool = false
    @State private var activeDatePicker: ActiveDatePicker?

    // MARK: - JobSite Autocomplete State
    @State private var jobSiteSearchText = ""
    @State private var jobSiteInputText = ""
    @State private var isPopupJobSitesPresented: Bool = false
    @State private var tfJobSitePosition: CGPoint = .zero
    @State private var tfJobSiteWidth: CGFloat = 0
    @State private var tfJobSiteHeight: CGFloat = 0

    @State private var isPopupStatusPresented: Bool = false
    @State private var tfStatusPosition: CGPoint = .zero
    @State private var tfStatusWidth: CGFloat = 0
    @State private var tfStatusHeight: CGFloat = 0

    @State private var isPopupUserPresented: Bool = false
    @State private var tfUserPosition: CGPoint = .zero
    @State private var tfUserWidth: CGFloat = 0
    @State private var tfUserHeight: CGFloat = 0

    // MARK: - Layout State
    @State private var contentWidth: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var shouldScrollUp = false

    // MARK: - Project List Preferences
    /// Backed by the account-level setting, not local storage, so the choice follows the user across devices.
    private var isListView: Bool { userManager.setting.projectViewType.isListView }

    private var selectedSort: SortOption { userManager.setting.projectSortBy }

    private var selectedSortBinding: Binding<SortOption> {
        Binding(
            get: { userManager.setting.projectSortBy },
            set: { userManager.setting.projectListSortBy = $0 }
        )
    }

    // MARK: - Focus
    @FocusState private var focusStateSearch: Bool
    @FocusState private var focusStateJobSite: Bool

    // MARK: - Task
    @State private var fetchTask: Task<Void, Never>? = nil
    /// Incremented for every fetch so a cancelled fetch can tell it is no longer the
    /// current one and must not touch `isLoading`.
    @State private var fetchGeneration = 0

    // MARK: - Environment
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var productData: ProductData

    // MARK: - Bindings
    @Binding var navigateToProjectDetail: Bool
    @Binding var navigateCat: Cat?
    @Binding var isActiveContent: Bool
    @Binding var isShowLoginWebview: Bool
    @Binding var isShowRenameAlert: Bool

    // MARK: - Camera
    @State private var isShowCameraView = false
    @State private var viewARUUID = UUID()
    
    // MARK: - Misc
    internal let inspection = Inspection<Self>()

    // MARK: - Computed Properties
    private var isIPhone: Bool {
        UserSession.isIPhone
    }

    private var isLogin: Bool {
        userManager.userInfo != nil
    }

    var status: [Status] {
        var list: [Status] = [
            .all, .uploadWating, .uploadCompleted, .sfmProcessing,
            .transformationCompleted, .verificationCompleted, .dashboardUploadCompleted
        ]
        if userManager.isARAvailable {
            list.append(.arUploadCompleted)
        }
        return list
    }

    private var userList: [User] {
        let currentUserId = userManager.userInfo?.userId
        var list: [User] = [.init(name: "ALL".localized(userManager.userLanguage))]
        if let currentUser = productData.userList.first(where: { $0.userId == currentUserId }) {
            list.append(.init(userId: currentUserId, name: currentUser.name))
        }
        // Everybody else, in the order the backend returned them.
        list.append(contentsOf: productData.userList.filter { $0.userId != currentUserId && !$0.name.isEmpty })
        return list
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
        try await productData.fetchProjectList(
            status: filter.status,
            searchStr: filter.searchStr,
            fromDate: filter.fromDate,
            toDate: filter.toDate,
            site: filter.jobsite,
            isRemoved: filter.isPointRemoved,
            rtkFilterMode: filter.rtkMode
        )
    }
    
    private func fetchProjects() {
        fetchProjects(scrollToTop: true)
    }

    private func fetchProjects(scrollToTop: Bool) {
        fetchTask?.cancel()
        isLoading = true
        fetchGeneration &+= 1
        let generation = fetchGeneration

        fetchTask = Task {
            // A fetch that was cancelled by a newer one must not clear the loading
            // state the newer fetch just turned on.
            defer {
                if generation == fetchGeneration { isLoading = false }
            }
            do {
                try await performFetch()
                if !Task.isCancelled { shouldScrollUp = scrollToTop }
            } catch {
                if !(error is CancellationError) {
                    print("Fetch error: \(error)")
                }
            }
        }
    }

    private func applySort() {
        // productData.sortOption is not @Published, so it must be set before fetchProjects()
        // reads it to build the sortBy request parameter.
        productData.sortOption = selectedSort
        userManager.updateSetting()
        fetchProjects()
    }

    /// Tapping the button of the picker that is already open closes it again.
    private func toggleDatePicker(_ picker: ActiveDatePicker) {
        activeDatePicker = (activeDatePicker == picker) ? nil : picker
    }

    private func updateContentSize(_ size: CGSize) {
        contentWidth = size.width
        contentHeight = size.height
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

                    navigationLinks

                    ButtonOpenCamera(onClick: { isShowShootWarning = true })
                        .position(
                            x: contentWidth - (isIPhone ? Layout.cameraButtonInsetIPhone.width : Layout.cameraButtonInsetIPad.width),
                            y: contentHeight - (isIPhone ? Layout.cameraButtonInsetIPhone.height : Layout.cameraButtonInsetIPad.height)
                        )
                        .tag(18)
                        .zIndex(1.0)

                    selectionLayer
                    popupLayer
                    jobSiteSearchPopup
                    statusSearchPopup
                    userSearchPopup
                }
                .onChange(of: isPopupStatusPresented) { isOpen in
                    if isOpen {
                        isPopupJobSitesPresented = false
                        isPopupUserPresented = false
                        focusStateJobSite = false
                    }
                }
                .onChange(of: isPopupUserPresented) { isOpen in
                    if isOpen {
                        isPopupJobSitesPresented = false
                        isPopupStatusPresented = false
                        focusStateJobSite = false
                    }
                }
                .onChange(of: isPopupJobSitesPresented) { isOpen in
                    if isOpen {
                        isPopupStatusPresented = false
                        isPopupUserPresented = false
                    }
                }
                // Tracks rotation / Split View resizes, not just the first layout pass.
                .onAppear { updateContentSize(contentGeo.size) }
                .onChange(of: contentGeo.size) { updateContentSize($0) }
            }
            .ignoresSafeArea(.keyboard, edges: .all)
            .background(userManager.setting.bodyColor)
            .sheet(isPresented: $isShowSupport) {
                if let url = Constant.supportUrl(for: userManager.userLanguage) {
                    WebView(url: url)
                }
            }
            .sheet(isPresented: $userManager.showLicenseRegister) {
                WebView(url: URL(string: Constant.licenseAssignUrl)!)
            }
            .fullScreenCover(isPresented: $accountWebViewIsShown) {
                AccountWebView()
            }
            .alert("NoLicense".localized(userManager.userLanguage), isPresented: $isShowNoLicenseAlert) {
                Button("OK") { performLogout() }
            }
            .onChange(of: userManager.setting.projectSortBy) { newValue in
                productData.sortOption = newValue
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
                        isShowNoLicenseAlert = true
                    }
                }
            }
            .overlay { datePickerOverlay }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .navigationViewStyle(.stack)
        .buttonStyle(PlainButtonStyle())
        .onChange(of: jobSiteList) { _ in
            if isLogin {
                filter.jobsite = jobSiteList.first
                jobSiteInputText = jobSiteList.first?.name ?? ""
                jobSiteSearchText = ""
                fetchProjects()
            }
        }
        // Reload requested from outside MainScreen, e.g. BaseUploadPopup finishing
        // an upload. Going through fetchProjects() keeps the user's filters and
        // reuses the loading overlay.
        .onChange(of: productData.reloadListRequestID) { _ in
            fetchProjects()
        }
        .onChange(of: isShowARView) { newValue in
            if !newValue { fetchProjects(scrollToTop: false) }
        }
        .onChange(of: isShowPointCloudView) { newValue in
            if !newValue { fetchProjects(scrollToTop: false) }
        }
        .onChange(of: isShowCameraView) { newValue in
            if !newValue { fetchProjects(scrollToTop: false) }
        }
        .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    //---------------------------
    // MARK: - Overlay Layers
    //---------------------------
    /// Hidden links driving the push to `ProductDetailView`.
    @ViewBuilder
    private var navigationLinks: some View {
        if let currentCat = currentCat {
            NavigationLink("", destination: ProductDetailView(cat: currentCat, forceShowJobSitePopup: false, isActiveContent: $isActiveContent), isActive: $isProductDetailActive)
        }
        if let navigateCat = navigateCat {
            NavigationLink("", destination: ProductDetailView(cat: navigateCat, forceShowJobSitePopup: true, isActiveContent: $isActiveContent), isActive: $navigateToProjectDetail)
        }
        
        // MARK: - Camera
        NavigationLink("", destination: LazyView(CaptureScreen(navigateCat: $navigateCat)), isActive: $isShowCameraView)
        NavigationLink("", destination: LazyView(ViewARScreen(selectedCat: $selectCat).id(viewARUUID).onDisappear { viewARUUID = UUID() }), isActive: $isShowARView)
        NavigationLink("", destination: LazyView(ViewPointCloudScreen(selectedCat: $selectCat).id(viewARUUID).onDisappear { viewARUUID = UUID() }), isActive: $isShowPointCloudView)
    }

    @ViewBuilder
    private var selectionLayer: some View {
        if isEditing {
            SelectedManagerView(selectedCount: selectedItem.count, allowTap: !isShowConfirmDelete, didTapDelete: {
                if selectedItem.count > 0 { isShowConfirmDelete = true }
            }, didTapCancel: {
                NotificationCenter.default.post(name: .updateCell, object: nil)
                selectedItem.removeAll()
                isEditing = false
            })
        }
    }

    /// Popups are listed in z-order: later ones draw above earlier ones.
    @ViewBuilder
    private var popupLayer: some View {
        licenseAlertPopup
        confirmDeletePopup
        filterPopup
        captureWarningPopup
        singleDeletePopup
        exportCompletePopup
        settingPopup
        loginAlertPopup
        disclaimerPopup
        arListPopup
    }

    @ViewBuilder
    private var licenseAlertPopup: some View {
        if userManager.showLicenseAlert {
            LicenseAlertPopup(
                isShow: $userManager.showLicenseAlert,
                pointCloudBgcolor: Color(hex: userManager.setting.pointCloudBgcolor)
                    .opacity(userManager.setting.pointCloudBgalpha)
            )
        }
    }

    @ViewBuilder
    private var confirmDeletePopup: some View {
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
    }

    private var filterPopup: some View {
        FilterPopup(presentedAsModal: $isShowFilterAlert, currentSearchStr: $filter.searchStr, currentStatus: $filter.status) { fromDate, toDate, site in
            filter.fromDate = fromDate
            filter.toDate = toDate
            filter.jobsite = site
            fetchProjects()
        }
        .environmentObject(userManager)
        .tag(24)
    }

    @ViewBuilder
    private var captureWarningPopup: some View {
        if isShowShootWarning {
            CaptureWarningPopup(isShow: $isShowShootWarning, isShowCameraView: $isShowCameraView) {
                Pix4DInfo().openPix4DCapture()
            }
            .zIndex(2.0)
            .tag(19)
        }
    }

    @ViewBuilder
    private var singleDeletePopup: some View {
        if isShowSingleDeletePopup || deleteCat != nil {
            DeletePopup(show: $isShowSingleDeletePopup, cat: deleteCat)
                .tag(17)
        }
    }

    @ViewBuilder
    private var exportCompletePopup: some View {
        if isShowExportComplete {
            ExportSuccessPopup(isShow: $isShowExportComplete)
                .tag(20)
        }
    }

    @ViewBuilder
    private var settingPopup: some View {
        if isShowSettingPopup {
            SettingPopup(
                isShow: $isShowSettingPopup,
                pointCloudBgcolor: Color(hex: userManager.setting.pointCloudBgcolor)
                    .opacity(userManager.setting.pointCloudBgalpha)
            )
        }
    }

    @ViewBuilder
    private var loginAlertPopup: some View {
        if isShowLoginAlert {
            LoginAlert(isShow: $isShowLoginAlert, loginHandler: {
                isShowLoginWebview = true
            }, logoutHandler: {
                performLogout()
            })
            .frame(width: Layout.loginAlertSize.width, height: Layout.loginAlertSize.height)
            .cornerRadius(20)
            .offset(x: 0, y: isIPhone ? 0 : Layout.loginAlertOffsetIPad)
        }
    }

    @ViewBuilder
    private var disclaimerPopup: some View {
        if isShowDisclaimerAlert {
            let size = isIPhone ? Layout.disclaimerSizeIPhone : Layout.disclaimerSizeIPad
            DisclaimerAlert(isShow: $isShowDisclaimerAlert)
                .frame(width: size.width, height: size.height)
                .offset(x: 0, y: isIPhone ? 0 : Layout.disclaimerOffsetIPad)
        }
    }

    @ViewBuilder
    private var arListPopup: some View {
        if showARListPopup {
            ARListPopup(show: $showARListPopup, cat: selectCat)
                .tag(40)
        }
    }

    private var statusSearchPopup: some View {
        SearchListPopup<Status>(
            isShow: $isPopupStatusPresented,
            viewPosition: $tfStatusPosition,
            viewWidth: $tfStatusWidth,
            viewHeight: $tfStatusHeight,
            listOriginal: status,
            searchKey: .constant("")
        ) { itemSelected in
            filter.status = itemSelected
            fetchProjects()
        }
        .environmentObject(userManager)
    }

    private var userSearchPopup: some View {
        SearchListPopup<User>(
            isShow: $isPopupUserPresented,
            viewPosition: $tfUserPosition,
            viewWidth: $tfUserWidth,
            viewHeight: $tfUserHeight,
            listOriginal: userList,
            searchKey: .constant("")
        ) { itemSelected in
            productData.selectedUser = itemSelected
            fetchProjects()
        }
        .environmentObject(userManager)
    }

    private var jobSiteSearchPopup: some View {
        SearchListPopup<JobSite.Site>(
            isShow: $isPopupJobSitesPresented,
            viewPosition: $tfJobSitePosition,
            viewWidth: $tfJobSiteWidth,
            viewHeight: $tfJobSiteHeight,
            listOriginal: jobSiteList,
            searchKey: $jobSiteSearchText
        ) { itemSelected in
            filter.jobsite = itemSelected
            jobSiteSearchText = ""
            jobSiteInputText = itemSelected.name
            fetchProjects()
        }
        .environmentObject(userManager)
    }

    /// One overlay for both ends of the range; `activeDatePicker` decides which.
    @ViewBuilder
    private var datePickerOverlay: some View {
        if let picker = activeDatePicker {
            DatePickerOverlay(
                dateBinding: Binding<Date>(
                    get: { (picker == .from ? filter.fromDate : filter.toDate) ?? Date() },
                    set: { newDate in
                        if picker == .from {
                            filter.fromDate = newDate
                        } else {
                            filter.toDate = newDate
                        }
                        activeDatePicker = nil
                        fetchProjects()
                    }
                ),
                otherDate: picker == .from ? filter.toDate : filter.fromDate,
                isToDate: picker == .to,
                isIPhone: isIPhone
            ) {
                activeDatePicker = nil
            }
        }
    }

    //---------------------------
    // MARK: - Structural UI Components
    //---------------------------
    private func headerToolbar() -> some View {
        HStack {
            HStack(alignment: .bottom, spacing: isIPhone ? 5 : 15) {
                StatusFilterField(
                    selectedStatus: $filter.status,
                    isPopupStatusPresented: $isPopupStatusPresented,
                    tfStatusPosition: $tfStatusPosition,
                    tfStatusWidth: $tfStatusWidth,
                    tfStatusHeight: $tfStatusHeight,
                    isIPhone: isIPhone
                )

                UserFilterField(
                    isPopupUserPresented: $isPopupUserPresented,
                    tfUserPosition: $tfUserPosition,
                    tfUserWidth: $tfUserWidth,
                    tfUserHeight: $tfUserHeight,
                    isIPhone: isIPhone
                )

                JobSiteFilterField(
                    jobSiteInputText: $jobSiteInputText,
                    jobSiteSearchText: $jobSiteSearchText,
                    isPopupJobSitesPresented: $isPopupJobSitesPresented,
                    tfJobSitePosition: $tfJobSitePosition,
                    tfJobSiteWidth: $tfJobSiteWidth,
                    tfJobSiteHeight: $tfJobSiteHeight,
                    jobsite: $filter.jobsite,
                    focusStateJobSite: _focusStateJobSite,
                    isIPhone: isIPhone,
                    onClearOrSubmit: fetchProjects
                )

                SearchFieldView(
                    inputStr: $inputStr,
                    searchStr: $filter.searchStr,
                    focusStateSearch: _focusStateSearch,
                    isIPhone: isIPhone,
                    onSearchTriggered: fetchProjects
                )

                RTKFilterButtonView(
                    rtkFilterMode: $filter.rtkMode,
                    isIPhone: isIPhone,
                    labelProvider: ProjectFilter.rtkLabel(for:),
                    onTap: fetchProjects
                )

                PointRemoveFilterButtonView(
                    isPointRemoveSelected: $filter.isPointRemoved,
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
                        contentWidth: contentWidth,
                        isEditing: $isEditing
                    )
                    .padding(.horizontal, ProjectListColumnLayout.Metrics.listOuterPadding(isIPhone: isIPhone))
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
                    deleteCat: $deleteCat,
                    showARListPopup: $showARListPopup,
                    selectCat: $selectCat,
                    isActiveContent: $isActiveContent,
                    isShowCameraView: $isShowARView,
                    isShowPointCloudView: $isShowPointCloudView,
                    contentWidth: $contentWidth,
                    contentHeight: $contentHeight,
                    scrollToTopTrigger: $shouldScrollUp,
                    isListView: isListView,
                    onRefresh: {
                        try? await performFetch()
                        userManager.getSetting()
                    }
                )
                .padding(.horizontal, ProjectListColumnLayout.Metrics.listOuterPadding(isIPhone: isIPhone))
            }

            // Shown while fetching (isLoading) and also while the fetched list is being
            // re-grouped / re-sorted (isUpdatingList), so a big list never looks frozen.
            if isLoading || productData.isUpdatingList {
                ProgressLoadingView(text: "", bgOpacity: 0.3)
                    .ignoresSafeArea()
            }
        }
    }

    private func menuButton() -> some View {
        Menu {
            Button("SELECT".localized(userManager.userLanguage), action: { isEditing = true })
            Button("Setting".localized(userManager.userLanguage), action: {
                // Open the popup once the settings are actually in, instead of
                // guessing how long the request takes.
                userManager.getSetting { isShowSettingPopup = true }
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
                if let url = Constant.userManualUrl {
                    UIApplication.shared.open(url)
                }
            })
            .font(.custom(CustomFonts.FAFreeSolid, size: 10))
            .frame(height: 10)

            Button(action: {
                if let url = Constant.termsOfUseUrl(for: userManager.userLanguage) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("TERMS_OF_SERVICE".localized(userManager.userLanguage))
            }

            Button("SUPPORT".localized(userManager.userLanguage)) { isShowSupport = true }

            Text(appVersionText)
        } label: {
            Image(systemName: "questionmark.circle.fill")
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
                selectedSort: selectedSortBinding,
                isIPhone: isIPhone,
                onSelect: applySort
            )

            DateRangeView(
                fromDate: $filter.fromDate,
                toDate: $filter.toDate,
                onFromTap: { toggleDatePicker(.from) },
                onToTap: { toggleDatePicker(.to) },
                onClear: fetchProjects
            )

            Picker(selection: $productData.groupIndex, label: Text("")) {
                ForEach(GroupMode.allCases, id: \.self) { mode in
                    Text(mode.title.localized(userManager.userLanguage)).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: Layout.groupPickerWidth)
            .tag(21)
            .background(userManager.setting.colorTheme == .light ? Color(hex: 0xECEDEE) : Color.black.opacity(0.1))
            .foregroundColor(userManager.setting.colorTheme == .light ? Color.black : Color.white)
            .onChange(of: productData.groupIndex) { _ in
                shouldScrollUp = true
            }

            Button(action: {
                // Apply locally first so the list flips in the same frame; the sync runs in the background.
                userManager.setting.projectListViewType = isListView ? .grid : .list
                userManager.updateSetting()
            }) {
                Image(systemName: isListView ? "square.grid.2x2" : "list.bullet")
                    .font(.system(size: isIPhone ? 16 : 20))
                    .foregroundColor(userManager.setting.textColor)
            }
        }
        .padding(.horizontal, isIPhone ? 20 : 30)
        .padding(.vertical, 8)
    }
}

//---------------------------
// MARK: - Preview
//---------------------------
struct MainScreen_Previews: PreviewProvider {
    static var previews: some View {
        MainScreen(
            navigateToProjectDetail: .constant(false),
            navigateCat: .constant(nil),
            isActiveContent: .constant(false),
            isShowLoginWebview: .constant(false),
            isShowRenameAlert: .constant(false)
        )
        .environmentObject(UserManager())
        .environmentObject(ProductData())
        .previewDevice("iPad Pro (11-inch)")
        .previewInterfaceOrientation(.landscapeRight)
    }
}
