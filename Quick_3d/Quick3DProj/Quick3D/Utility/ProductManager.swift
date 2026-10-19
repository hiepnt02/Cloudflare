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

final class ProductData: ObservableObject {
    var products: [Cat] = UserSession.products
    @Published var jobSite: JobSite?
    @Published var displayARSelection = false
    @Published var groupIndex: GroupMode = .month
    @Published var displayProduct = [[Cat]]()
    @Published var totalResult = 0
    @Published var hitsTotal = 0
    @Published var updatedCat: Cat?
    @Published var userList: [User] = []
    @Published var selectedUser: User? = User(userId: UserSession.shared.userInfo?.userId, name: "")
    private var cancelBag = Set<AnyCancellable>()
    var currentSearchStr = ""
    var currentSelectStatus: Status = .all
    var sortOption: SortOption = UserSession.sortOption
    private var lastFetchedOnlineProjects: [Project] = []
    private var lastFetchStatus: Status = .all
    private var lastFetchFromDate: Date? = nil
    private var lastFetchToDate: Date? = nil
    private var lastFetchSite: JobSite.Site? = nil
    private var lastFetchIsRemoved: Bool = false
    private var lastFetchRtkFilterMode: Int = 2
    private var lastSearchResult = UserSession.products
    private var requests = [DataRequest]()
    
    @Published var lishDashboard: [GroupwareModel] = []
    @Published var listDesign: [GroupwareModel] = []
    
    private let copyZipFileName = "copyZipFile.zip"
    private let pjManifestFileName = "projectManifest.json"
    private let catchLogFileName = "catchLog.ndjson"
    private let thumbnailFileName = "thumbnail.png"
    var uploadProjectQueue = ProjectUploadQueue()

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

        var result = [Date: [Cat]]()
        switch mode {
        case .year:
            result = products.sliced(by: [.year], for: { $0.sortValueDate(for: sortOption) })
        case .month:
            result = products.sliced(by: [.year, .month], for: { $0.sortValueDate(for: sortOption) })
        case .day:
            result = products.sliced(by: [.year, .month, .day], for: { $0.sortValueDate(for: sortOption) })
        }
        displayProduct = Array(result.values).sorted(by: { $0[0].sortValueDate(for: sortOption) > $1[0].sortValueDate(for: sortOption) })
        hitsTotal = products.count
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
                UserSession.products = self.products.filter { $0.source == .local }
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
            AF.request(URL(string: Constant.baseUrl + "api/v1/project/\(project.projectId!)")!, method: .delete)
                .validate()
                .responseString { response in
                    print("Delete response: " + (response.value ?? ""))
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
            // Should also remove project in queue
            uploadProjectQueue.dequeue(catId: id)
        }
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
                        createDate: catchLogDatas.0,
                        captureDate: catchLogDatas.0,
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
                var createDate = Date()
                var useVidoc = false
                // Create path of file "catchLog.ndjson"
                let catchLogURL = folder.appendingPathComponent(catchLogFileName)
                if let catchLog = archive[catchLogFileName] {
                    _ = try archive.extract(catchLog, to: catchLogURL)

                    let catchLogDatas = getDataFromCatchLog(catchLogURL)
                    createDate = catchLogDatas.0
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
                    createDate: createDate,
                    captureDate: createDate,
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
        UserSession.products = products.filter { $0.source == .local }
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
    
    func uploadARGroupware(
        cat: Cat,
        jobsiteId: String,
        groupware: GroupwareModel,
        arColor: String,
        completion: @escaping (Bool) -> Void
    ) {
        let url = URL(string: Constant.baseUrl + "api/v1/project/\(cat.projectId ?? "")/ar")!
        let parameters: [String: Any] = [
            "jobsiteId": jobsiteId,
            "projectName": cat.title,
            "timeStamp": cat.createDate.toString(format: Constant.rfcFormat, timeZone: .utc),
            "timezone": TimeZone.current.secondsFromGMT()/60,
            "ARColor":arColor,
            "key": groupware.key,
            "bucketId": groupware.bucketId,
            "nodeId": groupware.nodeId,
            "name": groupware.name,
            "uploadFileName": groupware.name
        ]

        let req = AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default)
            .validate()
            .responseData { response in
                debugPrint(response)
                switch response.result {
                case .success(let value):
                    completion(true)
                case .failure(let error):
                    completion(false)
                }
            }
        requests.append(req)
    }
}

// MARK: Fetch Projects List from Server
extension ProductData {
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
            "status": status == .uploadWating ? Status.all.value : status.value
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
        if let toDate = toDate {
            fallbackProducts = fallbackProducts.filter { ($0.createDate) <= toDate }
        }
        if let jobsiteId = site?.id {
            fallbackProducts = fallbackProducts.filter { $0.jobsiteId == jobsiteId }
        }
        if let fromDate = fromDate {
            fallbackProducts = fallbackProducts.filter { ($0.createDate) >= fromDate }
        }
        
        self.updateProductsInPlace(with: fallbackProducts)
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
        self.totalResult = value.total
        self.hitsTotal = value.hitsTotal

        self.lastFetchedOnlineProjects = value.projects
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
        let projects = value.projects
        let needRemove = offlineProducts.filter { offlineItem in projects.contains { $0.id == offlineItem.projectId } }
        needRemove.forEach { project in
            self.remove(project)
            offlineProducts.removeAll(where: { $0.projectId == project.projectId })
        }
        offlineProducts = offlineProducts.filter { $0.isLocalFolderExist }
        
        // Map data from the server to an array of Cat (Online) objects.
        let onlineProducts = projects.map { mapToCat(from: $0) }
        
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
        
        self.totalResult += offlineProducts.count
        
        // In-place updates prevent UI lag.
        self.updateProductsInPlace(with: finalCalculatedProducts)
        self.lastSearchResult = self.products
        self.updateDisplayProduct()
    }
    
    // 4. Offline data list filtering logic
    private func getFilteredOfflineProducts(
        isRemoved: Bool,
        rtkFilterMode: Int,
        fromDate: Date?,
        toDate: Date?,
        site: JobSite.Site?
    ) -> [Cat] {
        if isRemoved { return [] }
        
        var list = UserSession.products
        
        // Filtering in RTK mode
        if rtkFilterMode == 0 {
            list = list.filter { !($0.useVidoc ?? false) }
        } else if rtkFilterMode == 1 {
            list = list.filter { $0.useVidoc ?? false }
        }
        
        // Filter based on UI input conditions.
        if let userId = self.selectedUser?.userId, userId != UserSession.shared.userInfo?.userId {
            list = list.filter { $0.userId == userId }
        }
        if !self.currentSearchStr.isEmpty {
            list = list.filter { $0.title.lowercased().contains(self.currentSearchStr.lowercased()) }
        }
        if let toDate = toDate {
            list = list.filter { ($0.createDate) <= toDate }
        }
        if let jobsiteId = site?.id, !jobsiteId.isEmpty {
            list = list.filter { $0.jobsiteId == jobsiteId }
        }
        if let fromDate = fromDate {
            list = list.filter { ($0.createDate) >= fromDate }
        }
        
        return list
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
    
    // 6. Re-sort and re-group the current data locally without calling the API.
    func reapplySortLocally() {
        guard !lastFetchedOnlineProjects.isEmpty else { return }

        var offlineProducts = getFilteredOfflineProducts(
            isRemoved: lastFetchIsRemoved,
            rtkFilterMode: lastFetchRtkFilterMode,
            fromDate: lastFetchFromDate,
            toDate: lastFetchToDate,
            site: lastFetchSite
        )

        let projects = lastFetchedOnlineProjects
        let needRemove = offlineProducts.filter { offlineItem in projects.contains { $0.id == offlineItem.projectId } }
        needRemove.forEach { project in
            self.remove(project)
            offlineProducts.removeAll(where: { $0.projectId == project.projectId })
        }
        offlineProducts = offlineProducts.filter { $0.isLocalFolderExist }

        let onlineProducts = projects.map { mapToCat(from: $0) }
        var combinedProducts = offlineProducts + onlineProducts
        sortProducts(&combinedProducts)

        var finalProducts: [Cat] = []
        if lastFetchStatus == .all {
            finalProducts = combinedProducts
        } else if lastFetchStatus == .uploadWating {
            finalProducts = offlineProducts
        } else {
            finalProducts = onlineProducts
        }

        self.updateProductsInPlace(with: finalProducts)
        self.lastSearchResult = self.products
        self.updateDisplayProduct()
    }

    // 7. List Sorting Function (Supports Japanese/English/Numbers in multiple languages)
    private func sortProducts(_ list: inout [Cat]) {
        list.sort(by: {
            let lhsDate = sortOption == .capturedDate ? $0.captureDate : $0.createDate
            let rhsDate = sortOption == .capturedDate ? $1.captureDate : $1.createDate

            if lhsDate == rhsDate {
                let regexNumber = "[0-9]"
                let regexEnglish = "[a-zA-Z]"
                let regexKanzi = "^[一-龠]*$"
                let regexKatakana = "^[ァ-ヶｱ-ﾝﾞﾟ]*$"
                let regexHiragana = "^[ぁ-ん]*$"

                func getSortValue(for str: String) -> Int {
                    let sortOrder = [regexNumber, regexEnglish, regexKanzi, regexKatakana, regexHiragana]
                    return sortOrder.firstIndex(where: { regex in str.validateRegex(regex) }) ?? 0
                }

                let aSortValue = getSortValue(for: $0.title[0])
                let bSortValue = getSortValue(for: $1.title[0])
                if aSortValue == bSortValue {
                    return $0.title < $1.title
                } else {
                    return aSortValue > bSortValue
                }
            } else {
                return lhsDate > rhsDate
            }
        })
    }
    
    // 8. Perform an in-place update of the `self.products` array to optimize UI rendering.
    private func updateProductsInPlace(with targetProducts: [Cat]) {
        let targetIds = Set(targetProducts.map { $0.projectId })
        self.products.removeAll { !targetIds.contains($0.projectId) }
        
        for (index, targetItem) in targetProducts.enumerated() {
            if let currentIndex = self.products.firstIndex(where: { $0.projectId == targetItem.projectId }) {
                self.products[currentIndex] = targetItem
            } else {
                if index < self.products.count {
                    self.products.insert(targetItem, at: index)
                } else {
                    self.products.append(targetItem)
                }
            }
        }
        
        // Ensure the order is perfectly synchronized after insertion/deletion.
        let currentIds = self.products.map { $0.projectId }
        let targetIdList = targetProducts.map { $0.projectId }
        if currentIds != targetIdList {
            self.products.sort { (a, b) -> Bool in
                let indexA = targetProducts.firstIndex(where: { $0.projectId == a.projectId }) ?? 0
                let indexB = targetProducts.firstIndex(where: { $0.projectId == b.projectId }) ?? 0
                return indexA < indexB
            }
        }
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
