//
//  JobSite.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 26/04/2022.
//

import Foundation

struct JobSite: Decodable, Hashable {
    var total: Int
    var sites: [Site]
    
    struct Site: Decodable, Hashable {
        var id: String
        var name: String
    }
}

extension JobSite.Site: DropdownDisplayable {
    /// Site names come from the server already localized; the language is not consulted.
    func dropdownTitle(in language: String) -> String {
        name
    }
}
