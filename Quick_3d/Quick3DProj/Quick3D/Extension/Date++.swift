//
//  Date++.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 17/05/2022.
//

import Foundation

/// Creating a DateFormatter is expensive and both `Date.toString` and `String.toDate`
/// are called for every project cell on every render, so the formatters are created
/// once per (format, locale, timeZone) and reused.
final class DateFormatterCache {
    static let shared = DateFormatterCache()

    private let lock = NSLock()
    private var formatters = [String: DateFormatter]()

    private init() {}

    func formatter(format: String, locale: Locale?, timeZone: TimeZone?) -> DateFormatter {
        let key = "\(format)|\(locale?.identifier ?? "")|\(timeZone?.identifier ?? "")"

        lock.lock()
        defer { lock.unlock() }

        if let cached = formatters[key] { return cached }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = format
        if let locale = locale { formatter.locale = locale }
        if let timeZone = timeZone { formatter.timeZone = timeZone }
        formatters[key] = formatter
        return formatter
    }
}

extension Date {
    func toString(format dateFormat: String, locale: Locale = Locale(identifier: "en_US"), timeZone: TimeZone? = nil) -> String {
        DateFormatterCache.shared
            .formatter(format: dateFormat, locale: locale, timeZone: timeZone)
            .string(from: self)
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
