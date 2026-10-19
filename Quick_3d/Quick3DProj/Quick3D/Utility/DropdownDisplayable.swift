//
//  DropdownDisplayable.swift
//  Quick3D
//

import Foundation

/// What a value shows as one row of a filter dropdown.
///
/// `SearchListPopup` used to cast its generic element down to `JobSite.Site` to reach `name`,
/// which silently rendered nothing for any other type. Conforming here is what lets a type be
/// listed instead.
protocol DropdownDisplayable {
    /// The row's text. Takes the language explicitly because `Status` titles are localization
    /// keys resolved against `UserManager.userLanguage`, not stored strings.
    func dropdownTitle(in language: String) -> String
}
