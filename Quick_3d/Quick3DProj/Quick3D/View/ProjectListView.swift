import SwiftUI

struct ProjectListView: View {
    // MARK: - Environment & Bindings
    @EnvironmentObject var productData: ProductData
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var cancelUploadProject: CancelUploadProject
    
    @Binding var isEditing: Bool
    @Binding var isShowConfirmDelete: Bool
    @Binding var isShowRenameAlert: Bool
    @Binding var isProductDetailActive: Bool
    @Binding var isShowSingleDeletePopup: Bool
    @Binding var isShowExportComplete: Bool
    @Binding var isLoading: Bool
    @Binding var selectedItem: [String]
    @Binding var currentCat: Cat?
    @Binding var deleteCat: Cat?
    @Binding var showARListPopup: Bool
    @Binding var selectCat: Cat?
    @Binding var isActiveContent: Bool
    @Binding var isShowCameraView: Bool
    @Binding var isShowPointCloudView: Bool
    @Binding var contentWidth: CGFloat
    @Binding var contentHeight: CGFloat
    @Binding var scrollToTopTrigger: Bool
    let isListView: Bool
    
    let onRefresh: () async -> Void
    
    // MARK: - Computed Properties
    private var isIPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }
    
    private var columnCount: Int {
        return isIPhone ? 4 : 5
    }
    
    internal let inspection = Inspection<Self>()
    
    // MARK: - Main Body
    var body: some View {
        ScrollViewReader { proxy in
            List {
                // Sections are identified by their group date (stable across updates) so
                // SwiftUI can diff them instead of rebuilding every section.
                ForEach(productData.displayProduct) { section in
                    Section {
                        sectionHeader(for: section.items)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        if isListView {
                            listView(for: section.visibleItems)
                        } else {
                            gridView(for: section.gridRows)
                        }
                    }
                    .id(isFirstSection(section) ? AnyHashable("top_of_list") : AnyHashable(section.id))
                }
            }
            .listStyle(.plain)
            .refreshable {
                await onRefresh()
            }
            .onChange(of: scrollToTopTrigger) { newValue in
                if newValue {
                    scrollToTop(using: proxy)
                }
            }
            .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
            .onLoad { performInitialSetup() }
            .onDisappear { stopObserving() }
        }
    }
}

// MARK: - @ViewBuilder Sub-Views (avoid deeply nested code)
private extension ProjectListView {
    
    /// Displays the products as vertical rows (List Mode)
    @ViewBuilder
    func listView(for products: [Cat]) -> some View {
        ForEach(products, id: \.id) { cat in
            ProjectItemCell(
                cat: cat,
                isEditing: $isEditing,
                allowTap: !isShowConfirmDelete,
                isShowRenameAlert: $isShowRenameAlert,
                isSelected: isSelectedBinding(for: cat.id),
                isActiveContent: $isActiveContent,
                onTapPress: { handleTapPress(id: $0) },
                onNavigateToDetail: { navigateToDetail(cat: cat) },
                deleteCat: $deleteCat,
                jobSite: productData.jobSite,
                isShowDeletePopup: $isShowSingleDeletePopup,
                isShowExportCompleted: $isShowExportComplete,
                isLoading: $isLoading,
                showARListPopup: $showARListPopup,
                selectCat: $selectCat,
                isShowCameraView: $isShowCameraView,
                isShowPointCloudView: $isShowPointCloudView,
                contentWidth: $contentWidth,
                contentHeight: $contentHeight,
                isListView: isListView
            )
            .id(cat.id)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
    
    /// Displays the products as a column-based grid (Grid Mode).
    /// The rows are already prepared by `ProductData` when the list data changes.
    @ViewBuilder
    func gridView(for chunkedRows: [[Cat]]) -> some View {
        ForEach(chunkedRows.indices, id: \.self) { rowIndex in
            let rowItems = chunkedRows[rowIndex]

            HStack(spacing: 10) {
                ForEach(rowItems, id: \.id) { cat in
                    ProjectItemCell(
                        cat: cat,
                        isEditing: $isEditing,
                        allowTap: !isShowConfirmDelete,
                        isShowRenameAlert: $isShowRenameAlert,
                        isSelected: isSelectedBinding(for: cat.id),
                        isActiveContent: $isActiveContent,
                        onTapPress: { handleTapPress(id: $0) },
                        onNavigateToDetail: { navigateToDetail(cat: cat) },
                        deleteCat: $deleteCat,
                        jobSite: productData.jobSite,
                        isShowDeletePopup: $isShowSingleDeletePopup,
                        isShowExportCompleted: $isShowExportComplete,
                        isLoading: $isLoading,
                        showARListPopup: $showARListPopup,
                        selectCat: $selectCat,
                        isShowCameraView: $isShowCameraView,
                        isShowPointCloudView: $isShowPointCloudView,
                        contentWidth: $contentWidth,
                        contentHeight: $contentHeight,
                        isListView: isListView
                    )
                    .id(cat.id)
                }
                
                // Fill the empty slots of the last row when it has fewer items than columns
                if rowItems.count < columnCount {
                    ForEach(0..<(columnCount - rowItems.count), id: \.self) { _ in
                        Spacer().frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 16)
            .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
}

// MARK: - Helper Methods
private extension ProjectListView {
    
    func scrollToTop(using proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo("top_of_list", anchor: .top)
        }
        scrollToTopTrigger = false
    }
    
    func isFirstSection(_ section: ProjectSection) -> Bool {
        productData.displayProduct.first?.id == section.id
    }

    func sectionHeader(for products: [Cat]) -> some View {
        let format = LanguageMode(rawValue: userManager.userLanguage) == .ja ? productData.groupFormat : productData.enGroupFormat
        let dateString = products.first?.sortValueDate(for: productData.sortOption).toString(format: format) ?? ""
        
        return Text(dateString)
            .foregroundColor(userManager.setting.textColor)
            .font(.system(size: isIPhone ? 16 : 20))
            .bold()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }
}

// MARK: - Logic Handlers
private extension ProjectListView {
    
    func isSelectedBinding(for catId: String) -> Binding<Bool> {
        Binding(
            get: { selectedItem.contains(catId) },
            set: { newValue in
                if newValue {
                    if !selectedItem.contains(catId) {
                        selectedItem.append(catId)
                    }
                } else {
                    selectedItem.removeAll { $0 == catId }
                }
            }
        )
    }

    func handleTapPress(id: String) {
        if let index = selectedItem.firstIndex(of: id) {
            selectedItem.remove(at: index)
        } else {
            selectedItem.append(id)
        }
    }
    
    func navigateToDetail(cat: Cat) {
        currentCat = cat
        isProductDetailActive = true
    }
    
    func performInitialSetup() {
        checkLogin()
        productData.removeMissingLocalProjects()
        
        NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { _ in
            productData.removeMissingLocalProjects()
        }
    }
    
    func stopObserving() {
        NotificationCenter.default.removeObserver(self, name: UIScene.didActivateNotification, object: nil)
    }
    
    func checkLogin() {
        Task {
            let isValid = await userManager.checkTokenValid()
            if isValid {
                try? await userManager.fetchLicense()
                if userManager.numOfLicenses <= 0 {
                    await forceLogout()
                }
            } else {
                await forceLogout()
            }
        }
    }
    
    @MainActor
    func forceLogout() {
        userManager.logout()
        productData.removeRemoteProject()
        productData.removeJobsiteData()
        productData.resetTotalCount()
        userManager.userInfo = nil
        isActiveContent = false
        cancelUploadProject.isCancelDownload = true
    }
}
