//
//  Date++.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 17/05/2022.
//

import Foundation

extension Date {
    func toString(format dateFormat: String, locale: Locale = Locale(identifier: "en_US"), timeZone: TimeZone? = nil) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.dateFormat = dateFormat
        dateFormatter.locale = locale
        if timeZone != nil { dateFormatter.timeZone = timeZone }
        return dateFormatter.string(from: self)
    }

    func addingMonth(_ month: Int) -> Date? {
        var dateComponent = DateComponents()
        dateComponent.month = month
        return Calendar(identifier: .gregorian).date(byAdding: dateComponent, to: self)
    }

    var startOfDay: Date? {
        let calendar = Calendar(identifier: .gregorian)
        let unitFlags = Set<Calendar.Component>([.year, .month, .day])
        let components = calendar.dateComponents(unitFlags, from: self)
        return calendar.date(from: components)
    }

    var endOfDay: Date? {
        guard let startOfDay = startOfDay else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.day = 1
        let date = calendar.date(byAdding: components, to: startOfDay)
        return date?.addingTimeInterval(-1)
    }

    func getAllDates() -> [Date] {

        let calendar = Calendar(identifier: .gregorian)

        // geting start date
        let startDate = calendar.date(from: Calendar.current.dateComponents([.year, .month], from: self))!

        let range = calendar.range(of: .day, in: .month, for: startDate)


        // getting date...
        return range!.compactMap{ day -> Date in
            return calendar.date(byAdding: .day, value: day - 1 , to: startDate)!
        }

    }

    var isGreaterThanToday: Bool {
        self > Date()
    }
}

extension TimeZone {
    static let utc = TimeZone(abbreviation: "UTC")
}
