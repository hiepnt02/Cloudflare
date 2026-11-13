//
//  String++.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 21/04/2022.
//

import AVFoundation
import UIKit

/// `localized(_:)` is called dozens of times per project cell on every render.
/// Looking up the ".lproj" path and creating a Bundle each time hits the file system,
/// so the bundle of each language is resolved once and reused.
final class LocalizationBundleCache {
    static let shared = LocalizationBundleCache()

    private let lock = NSLock()
    private var bundles = [String: Bundle?]()

    private init() {}

    func bundle(for lang: String) -> Bundle? {
        lock.lock()
        defer { lock.unlock() }

        if let cached = bundles[lang] { return cached }

        let bundle = Bundle.main.path(forResource: lang, ofType: "lproj").flatMap { Bundle(path: $0) }
        bundles[lang] = bundle
        return bundle
    }
}

extension String {
    func width(with font: UIFont, maximumNumberOfLines: Int = 0) -> CGFloat {
        let size = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        return self.size(fits: size, font: font, maximumNumberOfLines: maximumNumberOfLines).width
    }
    
    func boundingRect(with size: CGSize, attributes: [NSAttributedString.Key: Any]) -> CGRect {
      let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
      return self.boundingRect(with: size, options: options, attributes: attributes, context: nil)
    }
    
    func size(fits size: CGSize, font: UIFont, maximumNumberOfLines: Int = 0) -> CGSize {
      let attributes: [NSAttributedString.Key: Any] = [.font: font]
      var size = self.boundingRect(with: size, attributes: attributes).size
      if maximumNumberOfLines > 0 {
        size.height = min(size.height, CGFloat(maximumNumberOfLines) * font.lineHeight)
      }
      return size
    }
    
    func toDate(format dateFormat: String, locale: Locale? = Locale(identifier: "en_US_POSIX"), timeZone: TimeZone? = nil) -> Date? {
        DateFormatterCache.shared
            .formatter(format: dateFormat, locale: locale, timeZone: timeZone)
            .date(from: self)
    }

    func localized(_ lang: String) -> String {
        guard let bundle = LocalizationBundleCache.shared.bundle(for: lang) else {
            return self
        }

        return NSLocalizedString(self, tableName: nil, bundle: bundle, value: "", comment: "")
    }

    func validateRegex(_ regex: String) -> Bool {
        let fieldCheck = NSPredicate(format: "SELF MATCHES %@", regex)
        return fieldCheck.evaluate(with: self)
    }
    
    subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }

    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(count, r.lowerBound)),
                                            upper: min(count, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
    
    // Rule of project name:
    // Must not start with: \ (backslash), / (slash), - (dash)
    // Must not end with: space (space), . (dot)
    // Must not contain: \ (backslash), / (slash)
    func validateProjectName() -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: #"^(?![\\/-])(?!.*[\\/]$)[^\\/]*(?<![ .])$"#)
            let range = NSRange(location: 0, length: self.utf16.count)
            let matches = regex.numberOfMatches(in: self, options: [], range: range)
            return matches > 0
        } catch {
            print("Error creating regex: \(error)")
            return false
        }
    }
    
    /// Returns the file extension of the string path, or nil if none exists.
    var fileExtension: String? {
        let url = URL(fileURLWithPath: self)
        let ext = url.pathExtension
        return ext.isEmpty ? nil : ext
    }
    
    /// Returns the filename from a path (e.g., "report.pdf")
    var fileName: String? {
        let url = URL(fileURLWithPath: self)
        let name = url.lastPathComponent
        
        // Check if the string is empty or not a valid filename.
        return name.isEmpty || name == "/" ? nil : name
    }
    
    /// Returns the filename WITHOUT the extension (e.g., "report")
    var fileNameWithoutExtension: String? {
        let url = URL(fileURLWithPath: self)
        let name = url.deletingPathExtension().lastPathComponent
        
        return name.isEmpty || name == "/" ? nil : name
    }
}

extension String {
    func versionCompare(_ otherVersion: String) -> ComparisonResult {
        let versionDelimiter = "."

        var versionComponents = self.components(separatedBy: versionDelimiter)
        var otherVersionComponents = otherVersion.components(separatedBy: versionDelimiter)

        let zeroDiff = versionComponents.count - otherVersionComponents.count

        if zeroDiff == 0 {
            // Same format, compare normally
            return self.compare(otherVersion, options: .numeric)
        } else {
            let zeros = Array(repeating: "0", count: abs(zeroDiff))
            if zeroDiff > 0 {
                otherVersionComponents.append(contentsOf: zeros)
            } else {
                versionComponents.append(contentsOf: zeros)
            }
            return versionComponents.joined(separator: versionDelimiter)
                .compare(otherVersionComponents.joined(separator: versionDelimiter), options: .numeric) // <6>
        }
    }
}
