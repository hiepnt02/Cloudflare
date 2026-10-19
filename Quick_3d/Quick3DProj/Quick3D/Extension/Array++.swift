//
//  Array++.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 13/09/2022.
//

import Foundation

extension Array {
    func sliced(by dateComponents: Set<Calendar.Component>, for key: (Element) -> Date) -> [Date: [Element]] {
        let initial: [Date: [Element]] = [:]
        let groupedByDateComponents = reduce(into: initial) { acc, cur in
            let components = Calendar.current.dateComponents(dateComponents, from: key(cur))
            let date = Calendar.current.date(from: components)!
            let existing = acc[date] ?? []
            acc[date] = existing + [cur]
        }

        return groupedByDateComponents
    }
}
