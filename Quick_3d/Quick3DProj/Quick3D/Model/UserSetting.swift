import Foundation
import SwiftUI

// MARK: - User Setting Model
struct UserSetting: Codable {
    var userId: String?
    var colorTheme: ColorThemeEnum = .light
    var coordinateSetting: Bool
    var pointCloudBgcolor: String
    var pointCloudBgalpha: Double
    var linkDashboard: Bool
    var notifyByEmail: Bool
    var isTester: Bool
    var displayListColumnSetting: DisplayListColumnSetting
    var projectListSortBy: SortOption?
    var projectListViewType: ProjectListViewType?
    
    enum CodingKeys: String, CodingKey {
        case userId, colorTheme, coordinateSetting, pointCloudBgcolor,
             pointCloudBgalpha, linkDashboard, notifyByEmail, isTester,
             displayListColumnSetting, projectListSortBy, projectListViewType
    }
    
    func getColorThemeLabel(for userLanguage: String) -> String {
        return colorTheme.rawValue.localized(userLanguage)
    }
    
    // Converts the struct into a [String: Any] dictionary using JSONEncoder safely
    func toDictionary() -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments)
        return json as? [String: Any]
    }
}

// MARK: - Display List Column Setting
struct DisplayListColumnSetting: Codable {
    var showJobsite: Bool = true
    var showPhotographer: Bool = true
    var showType: Bool = true
    var showCaptureDate: Bool = true
    var showUploadDate: Bool = true
    var showImages: Bool = true
    var showStatus: Bool = true
}

// MARK: - UI Theme Extension
extension UserSetting {
    // Quick helper to check if the current theme is light mode
    private var isLight: Bool { colorTheme == .light }
    
    // Background Colors
    var themeColor: Color           { isLight ? .white : .black }
    var bodyColor: Color            { isLight ? platinumColor : raisinBlack }
    var itemBgColor: Color          { isLight ? pearlGrey : charcoalDark }
    var projectCellColor: Color     { isLight ? .white : jetBlack }
    
    // Text Colors
    var textColor: Color            { isLight ? .black : .white }
    var subtileTextColor: Color     { isLight ? pearlGrey : charcoalDark }
    
    // UI Elements Colors
    var iconColor: Color            { isLight ? .black : .white }
    var dividerColor: Color         { isLight ? lightGray : abbeyGray }
    var labelColor: Color           { isLight ? dimGray : .gray }
    var dropdownColor: Color        { isLight ? .white : crowBlack }
    
    // Form & Input Colors
    var gridCellColor: Color        { isLight ? .white : .black }
    var textFieldColor: Color       { isLight ? .white : .black }
    var textFieldBorderColor: Color { isLight ? .black : .white }
    
    // Action Button Colors
    var buttonColor: Color          { isLight ? electricBlue : .blue }
    var deleteButtonColor: Color    { materialRed }
    var buttonCameraColor: Color    { amber }
    
    var projectSortBy: SortOption   { projectListSortBy ?? .capturedDate }
    var projectViewType: ProjectListViewType { projectListViewType ?? .grid }
    
    /// Returns the appropriate color for GPS/RTK buttons based on the mode
    /// - Parameter mode: 0 for GPS, 1 for RTK
    func getGpsRtkButtonColor(_ mode: Int) -> Color {
        return PositioningMode(rawValue: mode)?.buttonColor ?? .blue
    }
}
