//
//  ImageManager.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 15/04/2022.
//

import Foundation
import UIKit
import ZIPFoundation
import Combine
import Alamofire

enum ARUploadSource {
    case local(file1URL: URL, file2URL: URL?)
    case groupware(GroupwareModel)
    case groupwareWithLocalFile(GroupwareModel, file2URL: URL)
}

class ProductUtil {
    // 正規表現を一度だけコンパイルして再利用する
    private static let regexHead = try! NSRegularExpression(pattern: "^-")
    private static let regexEnd = try! NSRegularExpression(pattern: "[ 　.]$")
    private static let regexContent = try! NSRegularExpression(pattern: "[\\\\/\r\n]")
    
    static func validationCheck(_ str: String) -> Bool {
        let range = NSRange(location: 0, length: str.utf16.count)
        
        if regexHead.firstMatch(in: str, options: [], range: range) != nil {
            return false
        }
        
        if regexEnd.firstMatch(in: str, options: [], range: range) != nil {
            return false
        }
        
        if regexContent.firstMatch(in: str, options: [], range: range) != nil {
            return false
        }
        
        return true
    }
}

/// One date group of the project list.
///
/// Everything the list needs is prepared here when the data changes (which items are
/// visible, how they are split into grid rows) instead of being recomputed while
/// rendering. `id` is the truncated group date, so it stays stable across updates and
/// SwiftUI can diff the sections properly.
struct ProjectSection: Identifiable, Equatable {
    let id: Date
    /// Every product of the group. The section header is derived from this list.
    let items: [Cat]
    /// The products listed as rows.
    let visibleItems: [Cat]
    /// `visibleItems` split into rows of the grid layout.
    let gridRows: [[Cat]]

    /// Number of grid columns, has to match the layout in `ProjectListView`.
    static var gridColumnCount: Int {
        UIDevice.current.userInterfaceIdiom == .phone ? 4 : 5
    }
}

final class ProductData: ObservableObject {
    var products: [Cat] = UserSession.products
    @Published var jobSite: JobSite?
    @Published var displayARSelection = false
    @Published var groupIndex: GroupMode = .month
    @Published var displayProduct = [ProjectSection]()
    @Published var totalResult = 0
    @Published var hitsTotal = 0
    @Published var updatedCat: Cat?
    @Published var userList: [User] = []
    @Published var selectedUser: User? = User(userId: UserSession.shared.userInfo?.userId, name: "")

    /// Bumped when something outside MainScreen needs the project list reloaded,
    /// e.g. BaseUploadPopup finishing an upload. MainScreen refetches with the
    /// filters the user currently has applied and shows its own loading overlay.
    @Published private(set) var reloadListRequestID = 0

    /// True while the displaying list is being re-grouped / re-sorted.
    /// MainScreen shows its loading overlay so a big list does not look frozen.
    @Published private(set) var isUpdatingList = false

    /// Lists bigger than this are grouped on a background queue, so the UI keeps
    /// responding (and the loading overlay can be shown) while grouping runs.
    /// Smaller lists are grouped inline: hopping threads would only cause a flicker.
    private static let asyncGroupingThreshold = 120

    /// Identifies the newest grouping job so results of an outdated one are dropped.
    private var groupingGeneration = 0

    private var cancelBag = Set<AnyCancellable>()
    var currentSearchStr = ""
    var currentSelectStatus: Status = .all
    var sortOption: SortOption = .capturedDate
    private var lastFetchedOnlineProjects: [Project] = []
    private var lastFetchStatus: Status = .all
    private var lastFetchFromDate: Date? = nil
    private var lastFetchToDate: Date? = nil
    private var lastFetchSite: JobSite.Site? = nil
    private var lastFetchIsRemoved: Bool = false
    private var lastFetchRtkFilterMode: Int = 2
    private var lastSearchResult = UserSession.products
    private var requests = [DataRequest]()
    private var arUploadRequest: DataRequest?
    /// Server projects whose DELETE request is still in flight — excluded from
    /// fetch results so a refresh cannot resurrect a just-deleted row.
    private var pendingDeleteProjectIds = Set<String>()
    
    @Published var lishDashboard: [GroupwareModel] = []
    @Published var listDesign: [GroupwareModel] = []
    
    private let copyZipFileName = "copyZipFile.zip"
    private let pjManifestFileName = "projectManifest.json"
    private let catchLogFileName = "catchLog.ndjson"
    private let thumbnailFileName = "thumbnail.png"
    var onProjectsRemoved: (([String]) -> Void)?

    var groupFormat: String {
        groupIndex.displayFormat
    }

    var enGroupFormat: String {
        groupIndex.enDisplayFormat
    }
    
    init() {
        print("init")
        removeUnusedProject()
        //        Timer.scheduledTimer(withTimeInterval: 1800 , repeats: true) { [weak self] _ in
        //            self?.updateProjectStatus()
        //        }
        
        $groupIndex
            .sink(receiveValue: { [weak self] mode in
                self?.updateDisplayProduct(mode)
            })
            .store(in: &cancelBag)
        
        fetchUsers()
    }
    
    func updateDisplayProduct(_ mode: GroupMode? = nil) {
        let mode = mode ?? groupIndex
        let snapshot = products
        let sortOption = self.sortOption
        // UIKit has to be read on the main thread, the grouping itself can run anywhere.
        let gridColumnCount = ProjectSection.gridColumnCount

        hitsTotal = snapshot.count
        groupingGeneration += 1
        let generation = groupingGeneration

        // Small list: group inline to keep the update in the same UI transaction.
        guard snapshot.count > Self.asyncGroupingThreshold else {
            displayProduct = Self.groupProducts(snapshot, mode: mode, sortOption: sortOption, gridColumnCount: gridColumnCount)
            isUpdatingList = false
            return
        }

        isUpdatingList = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let grouped = Self.groupProducts(snapshot, mode: mode, sortOption: sortOption, gridColumnCount: gridColumnCount)
            DispatchQueue.main.async {
                guard let self = self else { return }
                // A newer grouping job started meanwhile, its result is the one to show.
                guard generation == self.groupingGeneration else { return }
                self.displayProduct = grouped
                self.isUpdatingList = false
            }
        }
    }

    /// Groups the products by the selected group mode, newest group first, and prepares
    /// everything the list needs to render a section.
    /// Pure function so it can run on any queue.
    private static func groupProducts(
        _ products: [Cat],
        mode: GroupMode,
        sortOption: SortOption,
        gridColumnCount: Int
    ) -> [ProjectSection] {
        guard !products.isEmpty else { return [] }

        let dateComponents: Set<Calendar.Component>
        switch mode {
        case .year: dateComponents = [.year]
        case .month: dateComponents = [.year, .month]
        case .day: dateComponents = [.year, .month, .day]
        }

        // Resolve the calendar once: `Calendar.current` is expensive to read per item.
        let calendar = Calendar.current
        var groups = [Date: [Cat]]()

        for product in products {
            let date = product.sortValueDate(for: sortOption)
            guard let groupDate = calendar.date(from: calendar.dateComponents(dateComponents, from: date)) else { continue }
            groups[groupDate, default: []].append(product)
        }

        let columns = max(1, gridColumnCount)

        // `products` is already sorted, so sorting the group keys keeps the item order.
        return groups.keys.sorted(by: >).compactMap { groupDate in
            guard let items = groups[groupDate] else { return nil }
            let visibleItems = items.filter { $0.isShownInProjectList }
            let gridRows = stride(from: 0, to: visibleItems.count, by: columns).map {
                Array(visibleItems[$0..<min($0 + columns, visibleItems.count)])
            }

            return ProjectSection(
                id: groupDate,
                items: items,
                visibleItems: visibleItems,
                gridRows: gridRows
            )
        }
    }

    func updateTotalItemCount(isDelete: Bool, numChanged: Int) {
        totalResult = isDelete ? (totalResult - numChanged) : (totalResult + numChanged)
    }
    
    @objc func updateProjectStatus(completion: (() -> Void)? = nil) {
        removeUnusedProject()
        
        let dispatchGroup = DispatchGroup()
        
        let filterProducts = products.filter { $0.projectId != nil }
        filterProducts.forEach { data in
            dispatchGroup.enter()
            
            fetchStatus(for: data.projectId!) { [weak self] status in
                guard
                    let self = self,
                    let status = status,
                    let index = self.products.firstIndex(where: { $0.projectId == data.projectId }),
                    let indexAtLastSearch = self.lastSearchResult.firstIndex(where: { $0.projectId == data.projectId })
                else {
                    dispatchGroup.leave()
                    return
                }
                self.products[index].statusList = status
                self.lastSearchResult[indexAtLastSearch].statusList = status
                // Update the stored local list in place: rebuilding it from the
                // filtered `products` list would drop any local project the
                // current date/search filter is hiding.
                var localProducts = UserSession.products
                if let localIndex = localProducts.firstIndex(where: { $0.projectId == data.projectId }) {
                    localProducts[localIndex].statusList = status
                    UserSession.products = localProducts
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main, execute: {
            completion?()
        })
    }
    
    private func removeUnusedProject() {
        
        var removedProjectIds: [String] = []
        let idsWithNilImageUrl = products.filter { $0.imageUrl == nil && $0.source == .local }
            .map { $0.id }
        removedProjectIds.append(contentsOf: idsWithNilImageUrl)
        let idsWithMissingFiles = products.filter { !isLocalFileExist(for: $0) }
            .map { $0.id }
        removedProjectIds.append(contentsOf: idsWithMissingFiles)
        products.removeAll { product in
            removedProjectIds.contains(product.id)
        }
        
        lastSearchResult = products
        UserSession.products =  UserSession.products.filter { !removedProjectIds.contains($0.id) }
        updateDisplayProduct()

        // Update total count
        let numOfItemRemoved = removedProjectIds.count
        updateTotalItemCount(isDelete: true, numChanged: numOfItemRemoved)
    }
    
    func removeMissingLocalProjects() {
        products.removeAll { cat in
            cat.source == .local && (cat.zipFolder == nil || !FileManager.default.fileExists(atPath: cat.zipFolder!.path))
        }
        updateDisplayProduct()
    }
    
    func removeLocalProjectWithUpload(id: String) async throws {
        var result = UserSession.products
        if let userId = self.selectedUser?.userId, userId != UserSession.shared.userInfo?.userId {
            result = result.filter { $0.userId == userId }
        }
        UserSession.products = result.filter { $0.id != id }
    }
    
    func getUserList(completion: (() -> Void)? = nil) {
        let req = AF.request(URL(string: Constant.baseUrl + "api/v1/users")!)
            .validate()
            .responseData { [weak self] result in
                guard let data = result.value else {
                    completion?()
                    return
                }
                if let users = try? JSONDecoder().decode([User].self, from: data) {
                    self?.userList = users
                    self?.updateSelectedUser()
                } else if let wrapper = try? JSONDecoder().decode(UserList.self, from: data) {
                    self?.userList = wrapper.users
                    self?.updateSelectedUser()
                }
                completion?()
            }
        requests.append(req)
    }
    
    func fetchUsers(completion: (() -> Void)? = nil) {
        guard let url = URL(string: Constant.baseUrl + "api/v1/users") else {
            completion?()
            return
        }

        let req = AF.request(url)
            .validate()
            .responseData { [weak self] response in
                defer { completion?() }  // Ensure that completion is always called when exiting the block
                guard let self = self, let data = response.value else { return }
                
                let decoder = JSONDecoder()
                
                // Try decoding by array first; if that fails, try decoding by the wrapper object.
                if let users = try? decoder.decode([User].self, from: data) {
                    self.userList = users
                } else if let wrapper = try? decoder.decode(UserList.self, from: data) {
                    self.userList = wrapper.users
                } else {
                    // If the decode fails completely, stop; the defer will handle the completion?()
                    return
                }
                
                // Call update after successfully assigning userList
                self.updateSelectedUser()
            }

        requests.append(req)
    }
    
    func initialSelectedUser() {
        selectedUser = User(userId: UserSession.shared.userInfo?.userId, name: "")
    }
    
    func updateSelectedUser() {
        if let userId = UserSession.shared.userInfo?.userId,
           let filterUser = userList.first(where: { $0.userId == userId })
        {
            selectedUser = filterUser
        }
    }
    
    func name(for userId: String?) -> String? {
        guard let userId = userId else { return nil }
        return userList.first(where: { $0.userId == userId })?.name
    }
    
    
    func getFeaturesData(projectId: String) async throws -> [String: Any]? {
        let url = URL(string: Constant.baseUrl + "api/v1/project/\(projectId)/ar")!
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .get)
                .validate()
                .responseData { response in
                    switch response.result {
                        case .success(let data):
                            do {
                                let features = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                continuation.resume(returning: features)
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        case .failure(let error):
                            continuation.resume(throwing: error)
                    }
                }
        }
    }
    
    func deleteARFile(projectId: String, output_type: String) async throws -> Bool? {
        let url = URL(string: Constant.baseUrl + "api/v1/project/\(projectId)/ar/\(output_type)")!
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .delete)
                .validate()
                .responseData { response in
                    switch response.result {
                        case .success(let data):
                            do {
                                continuation.resume(returning: true)
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        case .failure(let error):
                            continuation.resume(throwing: error)
                    }
                }
        }
    }

    func fetchJobSiteData(completion: (() -> Void)? = nil) {
        let req = AF.request(URL(string: Constant.baseUrl + "api/v1/sites")!)
            .validate()
            .responseDecodable(of: JobSite.self) { [weak self] response in
                self?.jobSite = response.value
                completion?()
            }
        requests.append(req)
    }
    
    func removeRemoteProject() {
        let numerOfItemBeforeDelete = products.count
        products.removeAll(where: { $0.source == .remote })
        lastSearchResult.removeAll(where: { $0.source == .remote })
        updateDisplayProduct()

        // Update total count
        let numOfItemRemoved = numerOfItemBeforeDelete - products.count
        updateTotalItemCount(isDelete: true, numChanged: numOfItemRemoved)
    }
    
    func removeJobsiteData() {
        jobSite = nil
    }
    
    func removeTempFile() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let archiveURL = documentsDirectory.appendingPathComponent("archive.zip")
        if FileManager.default.fileExists(atPath: archiveURL.path) {
            try? FileManager.default.removeItem(at: archiveURL)
        }
        
        do {
            let tmpDirURL = FileManager.default.temporaryDirectory
            let tmpDirectory = try FileManager.default.contentsOfDirectory(atPath: tmpDirURL.path)
            try tmpDirectory.forEach { file in
                let fileUrl = tmpDirURL.appendingPathComponent(file)
                try FileManager.default.removeItem(atPath: fileUrl.path)
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func removeARTempFile(fileName: String) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let archiveURL = documentsDirectory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: archiveURL.path) {
            try? FileManager.default.removeItem(at: archiveURL)
        }
        
        do {
            let tmpDirURL = FileManager.default.temporaryDirectory
            let tmpDirectory = try FileManager.default.contentsOfDirectory(atPath: tmpDirURL.path)
            try tmpDirectory.forEach { file in
                let fileUrl = tmpDirURL.appendingPathComponent(file)
                try FileManager.default.removeItem(atPath: fileUrl.path)
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func removeProducts(ids: [String]) {
        let needRemove = products.filter { ids.contains($0.id) && $0.projectId != nil }
        needRemove.forEach { project in
            let projectId = project.projectId!
            pendingDeleteProjectIds.insert(projectId)
            AF.request(URL(string: Constant.baseUrl + "api/v1/project/\(projectId)")!, method: .delete)
                .validate()
                .responseString { [weak self] response in
                    print("Delete response: " + (response.value ?? ""))
                    Task { @MainActor in
                        guard let self = self else { return }
                        self.pendingDeleteProjectIds.remove(projectId)
                        if case .failure = response.result {
                            self.requestListReload()
                        }
                    }
                }
        }
        
        let removeProduct = products.filter { ids.contains($0.id) }
        removeProduct.forEach {
            remove($0)
        }

        let removedProjectIds = Set(removeProduct.compactMap { $0.projectId })
        lastFetchedOnlineProjects.removeAll { removedProjectIds.contains($0.id) }

        ids.forEach { id in
            products.removeAll(where: { $0.id == id })
            lastSearchResult.removeAll(where: { $0.id == id })
        }
        // Should also remove project in queue
        onProjectsRemoved?(Array(ids))
        UserSession.products =  UserSession.products.filter { !ids.contains($0.id) }
        updateDisplayProduct()

        // Update total count
        let numOfItemRemoved = ids.count
        updateTotalItemCount(isDelete: true, numChanged: numOfItemRemoved)
    }
    
    func remove(_ item: Cat) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        try? FileManager.default.removeItem(at: documentsDirectory.appendingPathComponent(item.folderName))
        if let enumerator = FileManager.default.enumerator(atPath: documentsDirectory.path) {
            while let element = enumerator.nextObject() as? String, let zipFileName = item.zipFileName {
                if element.contains(zipFileName) {
                    try? FileManager.default.removeItem(at: documentsDirectory.appendingPathComponent(element))
                }
            }
        }
    }
    
    private func isLocalFileExist(for item: Cat) -> Bool {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return false }
        return FileManager.default.fileExists(atPath: documentsDirectory.appendingPathComponent(item.folderName).path)
    }
    
    func saveProduct(
        title: String,
        jobsiteId: String,
        zipFileUrl: URL,
        cat:Cat?,
        coordinateSetting: Bool,
        linkDashboard: Bool,
        verticalCoordinate: String,
        horizontalCoordinate: String
    ) -> Cat? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        // Time when the upload starts.
        // Use this for both createDate & captureDate instead of the time get from catchLog file
        // to make sure the uploading project is sorted correctly by both sort options
        // (upload date & captured date), same as the dates returned by server after upload completed.
        let uploadStartDate = Date()
        let folderName = "\(NSUUID().uuidString)"
        let folder = documentsDirectory.appendingPathComponent(folderName)
        let copyZipFile = folder.appendingPathComponent(copyZipFileName)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
            _ = FileManager.default.secureCopyItem(at: zipFileUrl, to: copyZipFile)
            
            // Get data from zip file but not extract that
            let fileManager = FileManager()
            let currentWorkingPath = fileManager.currentDirectoryPath
            var archiveURL = URL(fileURLWithPath: currentWorkingPath)
            archiveURL.appendPathComponent(copyZipFileName)
            let archive = try Archive(url: zipFileUrl, accessMode: .read)

            let projectManifestURL = folder.appendingPathComponent(pjManifestFileName)
            if let projectManifest = archive[pjManifestFileName] {
                // Have file "projectManifest.json" then should get data from new zip file structure
                _ = try archive.extract(projectManifest, to: projectManifestURL)

                let dataProjectManifest = try Data(contentsOf: projectManifestURL)
                guard let projectManifestJson = try JSONSerialization.jsonObject(with: dataProjectManifest, options: []) as? [String: Any] else {
                    throw NSError(
                        domain: "InvalidData",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot read json from projectManifest.json file"]
                    )
                }

                // Get first image in "images" array as ImageThumbnail from "projectManifest.json"
                let projectManifestModel = try JSONDecoder().decode(ProjectManifestModel.self, from: dataProjectManifest)
                guard let firstImageURL: String = projectManifestModel.captured_data?.images?[0].photo else {
                    throw NSError(
                        domain: "InvalidData",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot get first photo from projectManifest.json file"]
                    )
                }
                let thumbnailURL = folder.appendingPathComponent(thumbnailFileName)
                if let fistImage = archive[firstImageURL] {
                    _ = try archive.extract(fistImage, to: thumbnailURL)
                }

                // Get path of file "catchLog.ndjson" in json data of file "projectManifest.json"
                guard let catchLogPath = findValueFromJson(forKey: "catchlog", in: projectManifestJson) else {
                    throw NSError(
                        domain: "InvalidData",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot find catchlog in projectManifest.json file"]
                    )
                }
                // Create path of file "catchLog.ndjson"
                let catchLogURL = folder.appendingPathComponent(catchLogFileName)
                if let catchLog = archive[catchLogPath as! String] {
                    _ = try archive.extract(catchLog, to: catchLogURL)

                    // Get data from catchLog.ndjson file
                    let catchLogDatas = getDataFromCatchLog(catchLogURL)

                    // Create Cat model from data
                    return createCatModel(
                        folder: folder,
                        folderName: folderName,
                        zipFileUrl: zipFileUrl,
                        cat: cat,
                        title: title,
                        jobsiteId: jobsiteId,
                        createDate: uploadStartDate,
                        captureDate: uploadStartDate,
                        useVidoc: catchLogDatas.1,
                        imageThumbnailURL: thumbnailURL,
                        coordinateSetting: coordinateSetting,
                        linkDashboard: linkDashboard,
                        verticalCoordinate: verticalCoordinate,
                        horizontalCoordinate: horizontalCoordinate
                    )
                }
            } else {
                // Does not have file "projectManifest.json" then should get data from old zip file structure
                var useVidoc = false
                // Create path of file "catchLog.ndjson"
                let catchLogURL = folder.appendingPathComponent(catchLogFileName)
                if let catchLog = archive[catchLogFileName] {
                    _ = try archive.extract(catchLog, to: catchLogURL)

                    let catchLogDatas = getDataFromCatchLog(catchLogURL)
                    useVidoc = catchLogDatas.1
                }

                // Get ImageThumbnail is first jpg image from zip folder
                let thumbnailURL = folder.appendingPathComponent(thumbnailFileName)
                if let imageThumbnail = archive["Image_000001.jpg"] {
                    _ = try archive.extract(imageThumbnail, to: thumbnailURL)
                }

                // Create Cat model from data
                return createCatModel(
                    folder: folder,
                    folderName: folderName,
                    zipFileUrl: zipFileUrl,
                    cat: cat,
                    title: title,
                    jobsiteId: jobsiteId,
                    createDate: uploadStartDate,
                    captureDate: uploadStartDate,
                    useVidoc: useVidoc,
                    imageThumbnailURL: thumbnailURL,
                    coordinateSetting: coordinateSetting,
                    linkDashboard: linkDashboard,
                    verticalCoordinate: verticalCoordinate,
                    horizontalCoordinate: horizontalCoordinate
                )
            }
        } catch {
            print("saveProduct have error: \(error)")
            return nil
        }
        return nil
    }
    
    private func getDataFromCatchLog(_ catchLogFileURL: URL) -> (Date, Bool) {
        do {
            // Read json by line from "catchLog.ndjson" file
            guard let jsonLines = readJSONLines(from: catchLogFileURL) else {
                throw NSError(
                    domain: "InvalidData",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Cannot red json from catchLog.ndjson file"]
                )
            }
            
            var createDate = Date()
            var useVidoc = false
            
            // Use these 2 variables to check when the values ​​are found for the first time in the json file
            // then exit the for loop to avoid having to run the for loop until the end of the json file.
            var canFindCreateDate = false
            var canFindUseVidoc = false
            
            for jsonObject in jsonLines {
                if let initData = jsonObject["init"] as? [String: Any] {
                    // Get time create project from "init">"time"
                    if !canFindCreateDate {
                        if let createTime = initData["time"] as? Double {
                            createDate = Date(timeIntervalSince1970: createTime)
                        }
                        canFindCreateDate = true
                    }
                }

                if let gpsConfiguration = jsonObject["gpsConfiguration"] as? [String: Any] {
                    if !canFindUseVidoc {
                        // Get isRTK from "gpsConfiguration">"isRTK"
                        if let isRTK = gpsConfiguration["isRTK"] as? Bool, isRTK == true {
                            canFindUseVidoc = true
                            useVidoc = true
                        }
                    }
                }

                // Check have find both createDate & useVidoc then exit for loop
                if canFindCreateDate && canFindUseVidoc {
                    return (createDate, useVidoc)
                }
            }
            
            return (createDate, useVidoc)
        } catch {
            print("getDataFromCatchLog have error: \(error)")
            return (Date(), false)
        }
    }
    
    private func createCatModel(
        folder: URL,
        folderName: String,
        zipFileUrl: URL,
        cat: Cat?,
        title: String,
        jobsiteId: String,
        createDate: Date,
        captureDate: Date,
        useVidoc: Bool,
        imageThumbnailURL: URL,
        coordinateSetting: Bool,
        linkDashboard: Bool,
        verticalCoordinate: String,
        horizontalCoordinate: String
    ) -> Cat? {
        if(cat != nil){
            let newProduct = Cat(
                userId: cat!.userId,
                id: cat!.id,
                title: cat!.title,
                folderName: folderName,
                jobsiteId: cat!.jobsiteId,
                createDate: createDate,
                captureDate: captureDate,
                sourceStr: cat!.sourceStr,
                numberOfImage: cat?.numberOfImage ?? 0,
                statusList:cat!.statusList,
                imageUrl: imageThumbnailURL,
                projectId:cat!.projectId,
                zipFileName: zipFileUrl.lastPathComponent,
                useVidoc: useVidoc,
                las_file: cat!.las_file,
                ifc_file: cat!.ifc_file,
                vertical: verticalCoordinate,
                horizontal: horizontalCoordinate,
                coordinateSetting: coordinateSetting,
                linkDashboard: linkDashboard
            )
            // Keep the dates of the project in the displaying list in sync with this new upload
            syncUploadDate(createDate, for: cat!)
            return newProduct
        } else{
            let newProduct = Cat(
                userId: nil, 
                id: UUID().uuidString,
                title: title, 
                folderName: folderName,
                jobsiteId: jobsiteId,
                createDate: createDate,
                captureDate: captureDate,
                sourceStr: Cat.Source.local.rawValue,
                numberOfImage: cat?.numberOfImage ?? 0,
                imageUrl: imageThumbnailURL,
                zipFileName: zipFileUrl.lastPathComponent, 
                useVidoc: useVidoc,
                vertical: verticalCoordinate,
                horizontal: horizontalCoordinate,
                coordinateSetting: coordinateSetting,
                linkDashboard: linkDashboard
            )
            products.append(newProduct)
            sortProducts(&products)
            lastSearchResult.append(newProduct)
            sortProducts(&lastSearchResult)
            var localProductsTmp:[Cat] = UserSession.products
            localProductsTmp.append(newProduct)
            UserSession.products = localProductsTmp
            updateDisplayProduct()
            // Update total count
            updateTotalItemCount(isDelete: false, numChanged: 1)
            return newProduct
        }
    }
    
    private func findValueFromJson(forKey key: String, in json: [String: Any]) -> Any? {
        for (jsonKey, value) in json {
            if jsonKey == key {
                return value
            }

            if let nestedDictionary = value as? [String: Any] {
                if let result = findValueFromJson(forKey: key, in: nestedDictionary) {
                    return result
                }
            } else if let array = value as? [Any] {
                for item in array {
                    if let nestedDictionary = item as? [String: Any] {
                        if let result = findValueFromJson(forKey: key, in: nestedDictionary) {
                            return result
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func readJSONLines(from fileURL: URL) -> [[String: Any]]? {
        do {
            let fileContents = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = fileContents.components(separatedBy: .newlines)
            var jsonObjects: [[String: Any]] = []

            for line in lines {
                guard !line.isEmpty else { continue } // Skip empty lines

                if let data = line.data(using: .utf8),
                   let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    jsonObjects.append(jsonObject)
                } else {
                    print("Error: Invalid JSON line: \(line)")
                    return nil // Or you can choose to continue and ignore the invalid line
                }
            }
            return jsonObjects

        } catch {
            print("Error reading file: \(error)")
            return nil
        }
    }
    
    func getShootingDate(in ndJsonUrl: URL) throws -> Date{
        let jsonData = try Data(contentsOf: ndJsonUrl)
        let jsonString = String(data: jsonData, encoding: .utf8)
        
        if let jsonString = jsonString {
            let lines = jsonString.components(separatedBy: "\n")
            
            for line in lines {
                if let data = line.data(using: .utf8) {
                    do {
                        if let jsonLine = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            if let initDict = jsonLine["init"] as? [String: Any] {
                                if let time = initDict["time"] as? Double {
                                    return Date(timeIntervalSince1970: time)
                                }
                            }
                        }
                    } catch {
                        print("JSON変換エラー: \(error)")
                        return Date()
                    }
                }
            }
        } else {
            print("JSON string is nil")
            return Date()
        }
        return Date()
    }
        
    func getZipFile(cat: Cat) -> URL? {
        guard
            let zipFolder = cat.zipFolder,
            FileManager.default.fileExists(atPath: zipFolder.path)
        else {
            return nil
        }
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: zipFolder, includingPropertiesForKeys: nil)
            let i = 0
            for file in contents {
                if file.isZipFile && file.lastPathComponent == copyZipFileName {
                    return file
                }
            }
            return nil
        } catch {
            print("error: \(error)")
            return nil
        }
    }
    
    func updateProjectId(_ projectId: String, jobsiteId: String, for cat: Cat) {
        guard
            let index = products.firstIndex(where: { $0.id == cat.id }),
            let indexAtLastSearch = lastSearchResult.firstIndex(where: { $0.id == cat.id })
        else {
            return
        }
        products[index].projectId = projectId
        products[index].jobsiteId = jobsiteId
        lastSearchResult[indexAtLastSearch].projectId = projectId
        lastSearchResult[indexAtLastSearch].jobsiteId = jobsiteId
        UserSession.products =  UserSession.products.filter { $0.id != cat.id }
        updateDisplayProduct()
        
        updatedCat = products[index]
        
        fetchStatus(for: projectId) { [weak self] status in
            guard let self = self, let status = status else { return }
            self.products[index].statusList = status
            self.lastSearchResult[indexAtLastSearch].statusList = status
            UserSession.products =  UserSession.products.filter { $0.id != cat.id }
            self.updateDisplayProduct()
            
            self.updatedCat = self.products[index]
        }
    }
    
    func updateTitle(for cat: Cat, title: String) {
        guard
            let index = products.firstIndex(where: { $0.id == cat.id }),
            let indexAtLastSearch = lastSearchResult.firstIndex(where: { $0.id == cat.id })
        else {
            return
        }
        products[index].title = title
        lastSearchResult[indexAtLastSearch].title = title

        if let projectId = cat.projectId,
           let onlineIndex = lastFetchedOnlineProjects.firstIndex(where: { $0.id == projectId }) {
            lastFetchedOnlineProjects[onlineIndex].name = title
        }

        var localProject = UserSession.products
        if let index = localProject.firstIndex(where: { $0.id == cat.id }) {
            localProject[index].title = title
        }
        UserSession.products = localProject
        updateDisplayProduct()
        updatedCat = products[index]
    }
    
    func updateProject(for cat: Cat) {
        guard
            let index = products.firstIndex(where: { $0.id == cat.id }),
            let indexAtLastSearch = lastSearchResult.firstIndex(where: { $0.id == cat.id })
        else {
            return
        }
        products[index] = cat
        lastSearchResult[indexAtLastSearch] = cat
        var localProject = UserSession.products
        if let index = localProject.firstIndex(where: { $0.id == cat.id }) {
            localProject[index] = cat
        }
        UserSession.products = localProject
        updateDisplayProduct()
        updatedCat = products[index]
    }
    
    // Update createDate & captureDate to the time the upload starts (re-upload case),
    // so the uploading project is sorted correctly by both sort options
    // (upload date & captured date), same as the new project upload case.
    // Returns the updated Cat that should be used for the upload request.
    @discardableResult
    func refreshUploadDate(for cat: Cat, uploadStartDate: Date = Date()) -> Cat {
        var newCat = cat
        newCat.createDate = uploadStartDate
        newCat.captureDate = uploadStartDate
        syncUploadDate(uploadStartDate, for: cat)
        return newCat
    }

    // Sync the upload dates to the displaying lists & the local (offline) products storage.
    // Only apply for local project because dates of a remote project are always taken from server.
    private func syncUploadDate(_ uploadStartDate: Date, for cat: Cat) {
        guard cat.source == .local else { return }

        if let index = products.firstIndex(where: { $0.id == cat.id }) {
            products[index].createDate = uploadStartDate
            products[index].captureDate = uploadStartDate
            sortProducts(&products)
            updatedCat = products.first(where: { $0.id == cat.id })
        }

        if let index = lastSearchResult.firstIndex(where: { $0.id == cat.id }) {
            lastSearchResult[index].createDate = uploadStartDate
            lastSearchResult[index].captureDate = uploadStartDate
            sortProducts(&lastSearchResult)
        }

        var localProducts = UserSession.products
        if let index = localProducts.firstIndex(where: { $0.id == cat.id }) {
            localProducts[index].createDate = uploadStartDate
            localProducts[index].captureDate = uploadStartDate
            UserSession.products = localProducts
        }

        updateDisplayProduct()
    }

    func updateJobSite(for cat: Cat, jobSiteId: String, coordinateSetting: Bool, linkDashboard: Bool) {
        guard
            let index = products.firstIndex(where: { $0.id == cat.id }),
            let indexAtLastSearch = lastSearchResult.firstIndex(where: { $0.id == cat.id })
        else {
            return
        }
        products[index].jobsiteId = jobSiteId
        products[index].coordinateSetting = coordinateSetting
        products[index].linkDashboard = linkDashboard
        products[index].vertical = cat.vertical
        products[index].horizontal = cat.horizontal

        lastSearchResult[indexAtLastSearch].jobsiteId = jobSiteId
        var localProject = UserSession.products
        if let index = localProject.firstIndex(where: { $0.id == cat.id }) {
            localProject[index].jobsiteId = jobSiteId
            localProject[index].coordinateSetting = coordinateSetting
            localProject[index].linkDashboard = linkDashboard
            localProject[index].vertical = cat.vertical
            localProject[index].horizontal = cat.horizontal
        }
        UserSession.products = localProject
        updateDisplayProduct()
        updatedCat = products[index]
    }
    
    func updateThumbnail(_ imageBase64Str: String, for cat: Cat) {
        guard
            let index = products.firstIndex(where: { $0.id == cat.id }),
            let indexAtLastSearch = lastSearchResult.firstIndex(where: { $0.id == cat.id })
        else {
            return
        }
        products[index].imageBase64Str = imageBase64Str
        lastSearchResult[indexAtLastSearch].imageBase64Str = imageBase64Str
        // Update the stored local list in place: rebuilding it from the
        // filtered `products` list would drop any local project the
        // current date/search filter is hiding.
        var localProject = UserSession.products
        if let localIndex = localProject.firstIndex(where: { $0.id == cat.id }) {
            localProject[localIndex].imageBase64Str = imageBase64Str
            UserSession.products = localProject
        }
        updateDisplayProduct()
    }
    
    func resetTotalCount() {
        totalResult = 0
        hitsTotal = 0
    }
    
    private func fetchStatus(for projectId: String, completion: @escaping (StatusList?) -> Void) {
        AF.request(URL(string: Constant.baseUrl + "api/v1/project/\(projectId)")!)
            .validate()
            .responseDecodable(of: ProjectDetail.self) { response in
                guard let status = response.value?.status else {
                    completion(nil)
                    return
                }
                completion(status)
            }
    }

    // Check current project status.
    // If project is available then response is 200 (can view detail project)
    // If project is preparing then response is 403 (cannot view detail project)
    func checkProcessStatus(projectId: String, completion: @escaping (Bool) -> Void) {
        let url = URL(string: Constant.baseUrl + "api/v1/project/\(projectId)/processCheck")!
        AF.request(url, method: .get).response { response in
            if let httpResponse = response.response {
                switch httpResponse.statusCode {
                case 200:
                    // API call successful. Switch to detail view.
                    completion(true)
                case 403:
                    // API call failed (403 Forbidden). Show pop-up.
                    completion(false)
                default:
                    // Handle other error cases
                    completion(false)
                }
            } else if let error = response.error {
                // Troubleshoot network or other errors
                print("Troubleshoot network or other errors: \(error.localizedDescription)")
                completion(false)
            } else {
                // No response received from server.
                completion(false)
            }
        }
    }
    
    func checkGroupwarePermissions(siteId: String, completion: @escaping (Bool) -> Void) {
        AF.request(URL(string: Constant.baseUrl + "api/v1/checkGroupware?site=\(siteId)")!)
            .response { response in
                debugPrint(response)
                switch response.result {
                case .success(_):
                    if let statusCode = response.response?.statusCode, statusCode == 200 {
                        completion(true)
                    } else {
                        completion(false)
                    }
                    
                case .failure(let error):
                    print("checkGroupwarePermissions Error: \(error)")
                    completion(false)
                }
            }
    }

    func getGroupwares(
        uploadCase: Int,
        siteId: String,
        language: String,
        completion: @escaping () -> Void
    ) {
        let url = URL(string: Constant.baseUrl + "api/v1/groupware")!
        let parameters: [String: Any] = [
            "type": "\(uploadCase)",
            "site_id": siteId,
            "lang": language
        ]

        let req = AF.request(url, method: .post, parameters: parameters)
            .validate()
            .responseDecodable(of: GroupwareResponse.self) { response in
                guard let value = response.value else { return }
                self.lishDashboard = value.filesDashboard ?? []
                self.listDesign = value.filesDesign ?? []

                completion()
            }
        requests.append(req)
    }
    
    func uploadARData(
        cat: Cat,
        jobsiteId: String,
        arColor: String,
        source: ARUploadSource,
        progress progressHandler: ((Double) -> Void)? = nil,
        completion: @escaping (AFDataResponse<Any>) -> Void
    ) {
        let url = URL(string: Constant.baseUrl + "api/v1/project/\(cat.projectId ?? "")/ar")!

        switch source {
        case .groupware(let groupware):
            let parameters: [String: Any] = [
                "jobsiteId": jobsiteId,
                "projectName": cat.title,
                "timeStamp": cat.createDate.toString(format: Constant.rfcFormat, timeZone: .utc),
                "timezone": TimeZone.current.secondsFromGMT() / 60,
                "ARColor": arColor,
                "key": groupware.key,
                "bucketId": groupware.bucketId,
                "nodeId": groupware.nodeId,
                "name": groupware.name,
                "uploadFileName": groupware.name
            ]
            let req = AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default)
                .validate()
                .responseJSON { response in
                    debugPrint(response)
                    completion(response)
                }
            requests.append(req)

        case .local(let file1URL, let file2URL):
            var fields = commonARFields(jobsiteId: jobsiteId, cat: cat, arColor: arColor)
            fields["uploadFileName"] = file1URL.lastPathComponent
            if let f2URL = file2URL { fields["uploadFileName2"] = f2URL.lastPathComponent }
            let req = AF.upload(multipartFormData: { form in
                form.appendTextFields(fields)
                form.append(file1URL, withName: "uploadFile", fileName: file1URL.lastPathComponent, mimeType: "application/octet-stream")
                if let f2URL = file2URL {
                    form.append(f2URL, withName: "uploadFile2", fileName: f2URL.lastPathComponent, mimeType: "application/octet-stream")
                }
            }, to: url, method: .post)
            .uploadProgress { progressHandler?($0.fractionCompleted) }
            .responseJSON { [weak self] response in
                debugPrint(response)
                self?.arUploadRequest = nil
                completion(response)
            }
            arUploadRequest = req
            requests.append(req)

        case .groupwareWithLocalFile(let groupware, let file2URL):
            var fields = commonARFields(jobsiteId: jobsiteId, cat: cat, arColor: arColor)
            fields["key"] = groupware.key
            fields["bucketId"] = groupware.bucketId
            fields["nodeId"] = groupware.nodeId
            fields["name"] = groupware.name
            fields["uploadFileName"] = groupware.name
            fields["uploadFileName2"] = file2URL.lastPathComponent
            AF.upload(multipartFormData: { form in
                form.appendTextFields(fields)
                form.append(file2URL, withName: "uploadFile2", fileName: file2URL.lastPathComponent, mimeType: "application/octet-stream")
            }, to: url, method: .post)
            .responseJSON { response in
                debugPrint(response)
                completion(response)
            }
        }
    }

    func cancelARUpload() {
        arUploadRequest?.cancel()
        arUploadRequest = nil
    }

    private func commonARFields(jobsiteId: String, cat: Cat, arColor: String) -> [String: String] {
        [
            "jobsiteId": jobsiteId,
            "projectName": cat.title,
            "timeStamp": cat.createDate.toString(format: Constant.rfcFormat, timeZone: .utc),
            "timezone": "\(TimeZone.current.secondsFromGMT() / 60)",
            "ARColor": arColor
        ]
    }
}

// MARK: Fetch Projects List from Server
extension ProductData {
    /// Asks MainScreen to reload the project list using its current filters.
    @MainActor
    func requestListReload() {
        reloadListRequestID += 1
    }

    /// Re-runs the last list request with the filters the user currently has applied.
    /// Callers outside MainScreen (upload finished, AR upload, AR file deleted...) do not
    /// own the filter state, so passing fixed values here used to reset the RTK/GPS filter
    /// to "both" and drop the date / job site filters on the reloaded list.
    func refreshProjectListWithCurrentFilters() async throws {
        try await fetchProjectList(
            status: currentSelectStatus,
            searchStr: currentSearchStr,
            fromDate: lastFetchFromDate,
            toDate: lastFetchToDate,
            site: lastFetchSite,
            isRemoved: lastFetchIsRemoved,
            rtkFilterMode: lastFetchRtkFilterMode
        )
    }

    func fetchProjectList(
        status: Status,
        searchStr: String,
        fromDate: Date?,
        toDate: Date?,
        site: JobSite.Site?,
        isRemoved: Bool,
        rtkFilterMode: Int
    ) async throws -> Void {
        
        currentSearchStr = searchStr
        currentSelectStatus = status

        // Snapshot the requested filters up-front, not only on success: if this
        // request fails or is cancelled, a later local re-sort (sort/group change)
        // must still re-filter with the filters the user currently sees on screen —
        // otherwise it silently falls back to the previous fetch's date range.
        lastFetchStatus = status
        lastFetchFromDate = fromDate
        lastFetchToDate = toDate
        lastFetchSite = site
        lastFetchIsRemoved = isRemoved
        lastFetchRtkFilterMode = rtkFilterMode

        let params = buildRequestParameters(
            status: status,
            searchStr: searchStr,
            fromDate: fromDate,
            toDate: toDate,
            site: site,
            isRemoved: isRemoved,
            rtkFilterMode: rtkFilterMode
        )
        
        print("Param \(params.description)")
        
        var request: DataRequest?
        
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                request = AF.request(URL(string: Constant.baseUrl + "api/v1/projects")!, parameters: params)
                    .validate()
                    .responseDecodable(of: ProjectList.self, queue: .global(qos: .userInitiated)) { [weak self] result in
                        // If the Task was cancelled before the API returned, bail out without further processing
                        if Task.isCancelled {
                            continuation.resume(throwing: CancellationError())
                            return
                        }
                        
                        debugPrint(result)
                        guard let self = self else { return }
                        
                        // API failed -> fall back to the cached data and filter locally
                        guard let value = result.value else {
                            Task { @MainActor in
                                self.handleFetchFailure(searchStr: searchStr, fromDate: fromDate, toDate: toDate, site: site)
                                continuation.resume(returning: ())
                            }
                            return
                        }
                        
                        // API succeeded -> merge the online and offline data
                        Task { @MainActor in
                            self.handleFetchSuccess(
                                value: value,
                                status: status,
                                fromDate: fromDate,
                                toDate: toDate,
                                site: site,
                                isRemoved: isRemoved,
                                rtkFilterMode: rtkFilterMode
                            )
                            
                            continuation.resume(returning: ())
                        }
                    }
            }
        } onCancel: {
            request?.cancel()
        }
    }
    
    // 1. Initialize parameters for the API request.
    private func buildRequestParameters(
        status: Status,
        searchStr: String,
        fromDate: Date?,
        toDate: Date?,
        site: JobSite.Site?,
        isRemoved: Bool,
        rtkFilterMode: Int
    ) -> Parameters {
        var params: Parameters = [
            "status": status == .uploadWating ? Status.all.value : status.value,
            "sortBy": sortOption.rawValue
        ]
        if let userId = selectedUser?.userId {
            params["userId"] = userId
        }
        if let fromDate = fromDate, let startOfDay = fromDate.startOfDay {
            params["from"] = startOfDay.toString(format: Constant.rfcFormat, timeZone: .utc)
        }
        if let toDate = toDate, let endOfDay = toDate.endOfDay {
            params["to"] = endOfDay.toString(format: Constant.rfcFormat, timeZone: .utc)
        }
        if let id = site?.id, !id.isEmpty {
            params["jobsiteid"] = id
        }
        if !searchStr.isEmpty {
            params["like"] = searchStr
        }
        if isRemoved {
            params["isPointRemoved"] = isRemoved
        }
        if rtkFilterMode == 0 {
            params["isRTK"] = false
        } else if rtkFilterMode == 1 {
            params["isRTK"] = true
        }
        return params
    }
    
    // 2. Handling API failures (Local fallback filter on old datasets)
    private func handleFetchFailure(searchStr: String, fromDate: Date?, toDate: Date?, site: JobSite.Site?) {
        var fallbackProducts = self.lastSearchResult
        if !searchStr.isEmpty {
            fallbackProducts = fallbackProducts.filter { $0.title.lowercased().contains(searchStr.lowercased()) }
        }
        fallbackProducts = filterByDateRange(fallbackProducts, fromDate: fromDate, toDate: toDate)
        if let jobsiteId = site?.id {
            fallbackProducts = fallbackProducts.filter { $0.jobsiteId == jobsiteId }
        }
        sortProducts(&fallbackProducts)
        self.replaceProducts(with: fallbackProducts)
        self.updateDisplayProduct()
    }
    
    // 3. Handling API Success
    private func handleFetchSuccess(
        value: ProjectList,
        status: Status,
        fromDate: Date?,
        toDate: Date?,
        site: JobSite.Site?,
        isRemoved: Bool,
        rtkFilterMode: Int
    ) {
        let fetchedProjects = value.projects.filter { !pendingDeleteProjectIds.contains($0.id) }
        let droppedCount = value.projects.count - fetchedProjects.count

        self.totalResult = value.total - droppedCount
        self.hitsTotal = value.hitsTotal - droppedCount

        self.lastFetchedOnlineProjects = fetchedProjects
        self.lastFetchStatus = status
        self.lastFetchFromDate = fromDate
        self.lastFetchToDate = toDate
        self.lastFetchSite = site
        self.lastFetchIsRemoved = isRemoved
        self.lastFetchRtkFilterMode = rtkFilterMode
        
        // Get and filter offline (local) lists.
        var offlineProducts = getFilteredOfflineProducts(
            isRemoved: isRemoved,
            rtkFilterMode: rtkFilterMode,
            fromDate: fromDate,
            toDate: toDate,
            site: site
        )
        
        // Remove any offline projects that are duplicates of the project about to be downloaded from the server.
        let projects = fetchedProjects
        let needRemove = offlineProducts.filter { offlineItem in projects.contains { $0.id == offlineItem.projectId } }
        needRemove.forEach { project in
            self.remove(project)
            offlineProducts.removeAll(where: { $0.projectId == project.projectId })
        }
        offlineProducts = offlineProducts.filter { $0.isLocalFolderExist }
        
        // Map data from the server to an array of Cat (Online) objects.
        // Re-apply the from/to filter locally as well: the visible list must obey
        // the date range the user selected even when the server returns items
        // outside of it.
        let onlineProducts = filterByDateRange(projects.map { mapToCat(from: $0) }, fromDate: fromDate, toDate: toDate)
        
        // Combine them for sorting.
        var combinedProducts = offlineProducts + onlineProducts
        sortProducts(&combinedProducts)
        
        // The final display list is allocated based on the selected Status.
        var finalCalculatedProducts: [Cat] = []
        if status == .all {
            finalCalculatedProducts = combinedProducts
            self.hitsTotal += offlineProducts.count
        } else if status == .uploadWating {
            finalCalculatedProducts = offlineProducts
            self.hitsTotal = offlineProducts.count
        } else {
            finalCalculatedProducts = onlineProducts
        }
        

        let offlineTotalCount = getOfflineProductsForTotal(isRemoved: isRemoved)
            .filter { offlineItem in offlineItem.isLocalFolderExist && !projects.contains { $0.id == offlineItem.projectId } }
            .count
        self.totalResult += offlineTotalCount

        self.replaceProducts(with: finalCalculatedProducts)
        self.lastSearchResult = self.products
        self.updateDisplayProduct()
    }
    
    // 4. Offline data list filtering logic
    private func getOfflineProductsForTotal(isRemoved: Bool) -> [Cat] {
        if isRemoved { return [] }

        var list = UserSession.products
        if let userId = self.selectedUser?.userId, userId != UserSession.shared.userInfo?.userId {
            list = list.filter { $0.userId == userId }
        }
        return list
    }

    private func getFilteredOfflineProducts(
        isRemoved: Bool,
        rtkFilterMode: Int,
        fromDate: Date?,
        toDate: Date?,
        site: JobSite.Site?
    ) -> [Cat] {
        var list = getOfflineProductsForTotal(isRemoved: isRemoved)

        // Filtering in RTK mode
        if rtkFilterMode == 0 {
            list = list.filter { !($0.useVidoc ?? false) }
        } else if rtkFilterMode == 1 {
            list = list.filter { $0.useVidoc ?? false }
        }
        
        // Filter based on UI input conditions.
        if !self.currentSearchStr.isEmpty {
            list = list.filter { $0.title.lowercased().contains(self.currentSearchStr.lowercased()) }
        }
        list = filterByDateRange(list, fromDate: fromDate, toDate: toDate)
        if let jobsiteId = site?.id, !jobsiteId.isEmpty {
            list = list.filter { $0.jobsiteId == jobsiteId }
        }

        return list
    }

    private func filterByDateRange(_ list: [Cat], fromDate: Date?, toDate: Date?) -> [Cat] {
        // Cut by the same date field the server filters by (sortBy): capture date
        // when sorting by captured date, upload date when sorting by upload date.
        let sortOption = self.sortOption
        var result = list
        if let toDate = toDate, let endOfDay = toDate.endOfDay {
            result = result.filter { $0.sortValueDate(for: sortOption) <= endOfDay }
        }
        if let fromDate = fromDate, let startOfDay = fromDate.startOfDay {
            result = result.filter { $0.sortValueDate(for: sortOption) >= startOfDay }
        }
        return result
    }
    
    // 5. Map from API Model to UI Model (Cat)
    private func mapToCat(from project: Project) -> Cat {
        return Cat(
            userId: project.userId,
            id: UUID().uuidString,
            title: project.name ?? "",
            folderName: project.directory ?? "",
            jobsiteId: project.jobSiteId,
            createDate: project.uploadDate,
            captureDate: project.captureDate,
            sourceStr: Cat.Source.remote.rawValue,
            numberOfImage: project.numberOfImage ?? 0,
            statusList: project.status,
            projectId: project.id,
            useVidoc: project.useViDoc ?? false,
            lidarEditing: project.lidarEditing ?? nil,
            sfmEditing: project.sfmEditing ?? nil,
            helmartEditing: project.helmartEditing ?? nil,
            las_file: project.las_file ?? nil,
            ifc_file: project.ifc_file ?? nil,
            design_file: project.design_file ?? nil,
            vertical: project.vertical ?? nil,
            horizontal: project.horizontal ?? nil,
            ar_color: project.ar_color ?? nil,
        )
    }
    
    // 6. List Sorting Function (Supports Japanese/English/Numbers in multiple languages)
    //
    // The date and the title sort value are computed once per item instead of on every
    // comparison: getting the title sort value costs up to 5 regex evaluations, which the
    // comparator used to redo O(n log n) times.
    private func sortProducts(_ list: inout [Cat]) {
        let sortOption = self.sortOption

        var sortKeys = list.map { cat in
            (
                date: cat.sortValueDate(for: sortOption),
                titleSortValue: Self.titleSortValue(for: cat.title),
                cat: cat
            )
        }

        sortKeys.sort { lhs, rhs in
            if lhs.date == rhs.date {
                if lhs.titleSortValue == rhs.titleSortValue {
                    return lhs.cat.title < rhs.cat.title
                }
                return lhs.titleSortValue > rhs.titleSortValue
            }
            return lhs.date > rhs.date
        }

        list = sortKeys.map { $0.cat }
    }

    // Number, english, kanzi, katakana, hiragana - compiled once and reused.
    private static let titleSortPredicates: [NSPredicate] = [
        "[0-9]",
        "[a-zA-Z]",
        "^[一-龠]*$",
        "^[ァ-ヶｱ-ﾝﾞﾟ]*$",
        "^[ぁ-ん]*$"
    ].map { NSPredicate(format: "SELF MATCHES %@", $0) }

    private static func titleSortValue(for title: String) -> Int {
        let firstCharacter = title[0]
        return titleSortPredicates.firstIndex(where: { $0.evaluate(with: firstCharacter) }) ?? 0
    }
    
    // 8. Update `self.products` with the newly calculated list.
    //
    // This used to diff the array item by item and then re-sort it with a comparator
    // that searched `targetProducts` on every comparison (O(n² log n), several seconds
    // on a few hundred projects). The end result was always exactly `targetProducts`,
    // and `products` is not @Published (the UI renders `displayProduct`), so there is
    // nothing to gain from diffing here.
    private func replaceProducts(with targetProducts: [Cat]) {
        self.products = targetProducts
    }
}

extension ProductData {
    func fetchLocalProjectList() {
        if let path = Bundle.main.path(forResource: "list", ofType: "json") {
            do {
                requests.forEach { $0.cancel() }
                requests.removeAll()
                
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                let projectList = try JSONDecoder().decode(ProjectList.self, from: data)
                
                let projects = projectList.projects
                totalResult = projectList.total
                hitsTotal = projectList.hitsTotal
                
                var result = [Cat]()
                result.append(contentsOf: projects.map {
                    Cat(
                        userId: $0.userId,
                        id: UUID().uuidString,
                        title: $0.name ?? "",
                        folderName: $0.directory ?? "",
                        jobsiteId: $0.jobSiteId,
                        createDate: $0.uploadDate,
                        captureDate: $0.captureDate,
                        sourceStr: Cat.Source.remote.rawValue,
                        numberOfImage: $0.numberOfImage ?? 0,
                        statusList: $0.status,
                        projectId: $0.id,
                        useVidoc: $0.useViDoc ?? false,
                        lidarEditing: $0.lidarEditing ?? nil,
                        sfmEditing: $0.sfmEditing ?? nil,
                        helmartEditing: $0.helmartEditing ?? nil
                    )
                })
                sortProducts(&result)

                self.products = result
                lastSearchResult = result
                updateDisplayProduct()
            } catch {
                // handle error
            }
        }
    }
    
    func fetchLocalJobSite() {
        if let path = Bundle.main.path(forResource: "jobsites", ofType: "json") {
            do {
                requests.forEach { $0.cancel() }
                requests.removeAll()
                
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                let response = try JSONDecoder().decode(JobSite.self, from: data)
                
                jobSite = response
            } catch {
                // handle error
            }
        }
    }
    
    func fetchLocalUserList() {
        if let path = Bundle.main.path(forResource: "userList", ofType: "json") {
            do {
                requests.forEach { $0.cancel() }
                requests.removeAll()
                
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                let response = try JSONDecoder().decode([User].self, from: data)
                
                userList = response
            } catch {
                // handle error
            }
        }
    }
}

private extension MultipartFormData {
    func appendTextFields(_ fields: [String: String]) {
        fields.forEach { key, value in
            if let data = value.data(using: .utf8) {
                append(data, withName: key)
            }
        }
    }
}
