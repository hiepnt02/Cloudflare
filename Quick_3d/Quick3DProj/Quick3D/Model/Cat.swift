//
//  Cat.swift
//  Quick3D
//
//  Created by HungNT on 13/5/26.
//

import SwiftUI

// MARK: - Models
struct Cat: Codable, Identifiable, Equatable {
    enum Source: String {
        case local, remote
    }

    // MARK: Core identity
    let userId: String?
    let id: String
    var title: String
    let folderName: String
    var jobsiteId: String?

    // MARK: Dates
    // These dates are updated to the time upload starts (for local project)
    // so the uploading project is sorted correctly in the project list.
    var createDate: Date
    var captureDate: Date

    func sortValueDate(for sortOption: SortOption) -> Date {
        sortOption == .capturedDate ? captureDate : createDate
    }

    // MARK: Source
    let sourceStr: String
    let numberOfImage: Int

    var source: Source {
        projectId == nil ? Source(rawValue: sourceStr) ?? .local : .remote
    }

    var localSourceImage: String { "localResource" }
    var remoteSourceImage: String { "remoteResource" }

    func localSourceColor(colorTheme: ColorThemeEnum) -> Color {
        sourceColor(isActive: source == .local, colorTheme: colorTheme)
    }

    func remoteSourceColor(colorTheme: ColorThemeEnum) -> Color {
        sourceColor(isActive: projectId != nil, colorTheme: colorTheme)
    }

    private func sourceColor(isActive: Bool, colorTheme: ColorThemeEnum) -> Color {
        guard isActive else { return .gray.opacity(0.7) }
        return colorTheme == .light ? .black : .white
    }

    func removePointImage(colorTheme: ColorThemeEnum) -> String {
        colorTheme == .light ? "point_remove" : "point_remove_white"
    }

    /// Whether the project is listed as a row of the project list.
    /// A remote project that is not uploaded yet is hidden, AR projects are always shown.
    var isShownInProjectList: Bool {
        if statusList?.getIsAR == true { return true }
        let isUnuploadedRemote = projectId != nil && (statusList?.isNotUploaded ?? false)
        return !isUnuploadedRemote
    }

    // MARK: Remote project
    var statusList: StatusList?
    var imageUrl: URL?
    var projectId: String?

    var isEditing: Bool {
        guard let status = statusList else { return false }
        let editingFields = [
            status.helmert_transformation,
            status.coordinate_transformation,
            status.point_splitting_lidar,
            status.remove_lidar,
            status.point_txt_lidar,
            status.point_splitting_sfm,
            status.remove_sfm,
            status.point_txt_sfm,
            status.point_splitting_helmert,
            status.remove_helmert,
            status.point_txt_helmert
        ]
        return editingFields.contains(ProjectStatus.processing.rawValue)
    }

    // MARK: Local file system
    var zipFolder: URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return docs.appendingPathComponent(folderName)
    }

    var isLocalFolderExist: Bool {
        guard let path = zipFolder?.path else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    var pointCloudFile: URL? {
        guard let zipFolder = zipFolder else { return nil }
        let contents = try? FileManager.default.contentsOfDirectory(at: zipFolder, includingPropertiesForKeys: nil)
        return contents?.first { $0.isGLTFFile } ?? contents?.first { $0.isPLYFile }
    }

    var image: UIImage? {
        guard let thumbnailURL = zipFolder?.appendingPathComponent("thumbnail.png"),
              FileManager.default.fileExists(atPath: thumbnailURL.path) else { return nil }
        return UIImage(fromLocalUrl: thumbnailURL)
    }

    func projectWebUrl(for language: LanguageMode) -> URL? {
        guard let projectId = projectId else { return nil }
        let rootUrl = (statusList?.getIsAR ?? false) ? Constant.webARUrl : Constant.webUrl
        return URL(string: rootUrl + language.symbol + "/" + projectId)
    }

    // MARK: Upload metadata
    var imageBase64Str: String?
    var zipFileName: String?
    var useVidoc: Bool?
    var lidarEditing: String?
    var sfmEditing: String?
    var helmartEditing: String?
    var las_file: String?
    var ifc_file: String?
    var design_file: String?
    var vertical: String?
    var horizontal: String?
    var ar_color: String?
    var coordinateSetting: Bool = false
    var linkDashboard: Bool = false
}
