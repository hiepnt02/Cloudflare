//
//  UserSession.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 21/04/2022.
//

import Foundation
import KeychainAccess
import UIKit
import VigramSDK

class UserSession {
    static let shared = UserSession()
    private let keychain = Keychain(service: "ltd.landlog.scquick3d")
    private var cacheThumbnail = [String: UIImage]()
    
    static var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    
    var sessionId: String? {
        set {
            guard let sessionId = newValue else {
                try? keychain.remove("sessionId")
                return
            }
            try? keychain.set(sessionId, key: "sessionId")
        }
        get {
            try? keychain.getString("sessionId")
        }
    }

    var cookies: [HTTPCookie]? {
        set {
            guard
                let cookies = newValue,
                let data = try? NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: false)
            else {
                try? keychain.remove("cookiesKey")
                return
            }
            try? keychain.set(data, key: "cookiesKey")
        }
        get {
            guard
                let data = try? keychain.getData("cookiesKey"),
                let cookies = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [HTTPCookie]
            else {
                return nil
            }
            return cookies
        }
    }
    
    func cacheThumbnail(for projectId: String) -> UIImage? {
        cacheThumbnail[projectId]
    }

    func saveCacheThumbnail(_ image: UIImage, for projectId: String) {
        cacheThumbnail[projectId] = image
    }

    static var userLanguage: String {
        set {
            UserDefaults.standard.set(newValue, forKey: "languageKey")
        }
        get {
//            guard let lang = UserDefaults.standard.string(forKey: "languageKey") else {
//                let currentLang = Locale.current.languageCode ?? "en"
//                let langMode = (LanguageMode(rawValue: currentLang) ?? .en).rawValue
//                self.userLanguage = langMode
//                return langMode
//            }

//            本体設定による言語決定
            for langRegion in NSLocale.preferredLanguages {
                guard let lang = langRegion.components(separatedBy: "-").first
                else { continue }
                
                guard let langMode = LanguageMode(rawValue: lang)
                else { continue }
                
                return langMode.rawValue
            }
            
            return "en"
        }
    }
    
    // MARK: - Camera
    var lastVidocConnected: UUID? {
        get { (try? keychain.getString("vidocConnected")).flatMap(UUID.init) }
        set {
            if let uuid = newValue { try? keychain.set(uuid.uuidString, key: "vidocConnected") }
            else { try? keychain.remove("vidocConnected") }
        }
    }
    
    @KeychainCodable(key: "userInfo") var userInfo: UserInfo?
    @KeychainCodable(key: "ntripInfo") var ntripInfo: NtripInfoModel?

    /// Danh sách profile kết nối RTK đã lưu. Ở Keychain vì có password NTRIP.
    @KeychainCodable(key: "rtkConnectionProfiles") var rtkConnectionProfiles: [RTKConnectionProfile]?
    @UserDefaultOptional(key: "selectedRTKProfileId") var selectedRTKProfileId: String?

    /// Cờ riêng thay vì suy ra từ `rtkConnectionProfiles == nil`: `@KeychainCodable` trả
    /// `nil` cả khi decode hỏng, nên dùng nil làm điều kiện migrate thì một lần đọc lỗi sẽ
    /// chạy lại migration và ghi đè mất sạch profile đã lưu.
    @UserDefault(key: "didMigrateRTKProfiles", defaultValue: false) var didMigrateRTKProfiles: Bool

    @UserDefaultCodable(key: "products", defaultValue: []) static var products: [Cat]
    @UserDefaultOptional(key: "mountPointNtrip") var mountPointNtrip: String?
    @UserDefault(key: "recentMountPointNtrips", defaultValue: []) var recentMountPointNtrips: [String]
    @UserDefaultCodableOptional(key: "coordinateSystemNtrip") var coordinateSystemNtrip: CoordinateSystemNtripModel?
    @UserDefaultCodableOptional(key: "ntripCoordinateSelectionCounts") var ntripCoordinateSelectionCounts: [String: Int]?
    
    @UserDefault(key: "overlapValue", defaultValue: 0.9) var overlapValue: Double
    @UserDefault(key: "ratioValue", defaultValue: 0.9) var ratioValue: Double
    @UserDefault(key: "smoothValue", defaultValue: 5) var smoothValue: Int
    
    @UserDefault(key: "isShowMovement", defaultValue: false) var isShowMovement: Bool
    @UserDefault(key: "isEnableAlertSound", defaultValue: true) var isEnableAlertSound: Bool
    @UserDefault(key: "isShowFeaturePoints", defaultValue: false) var isShowFeaturePoints: Bool
    @UserDefault(key: "isShowResolution", defaultValue: false) var isShowResolution: Bool
    @UserDefault(key: "isShowOverlap", defaultValue: false) var isShowOverlap: Bool
    @UserDefault(key: "isEnableMesh", defaultValue: true) var isEnableMesh: Bool
    @UserDefault(key: "isSaveMesh", defaultValue: false) var isSaveMesh: Bool
    @UserDefault(key: "isEnableLog", defaultValue: false) var isEnableLog: Bool
    @UserDefault(key: "positionHistoryMaxSize", defaultValue: 50) var posHisMaxSize: Int
    @UserDefault(key: "positionHistoryHorizontal", defaultValue: 0.015) var posHisHorizontal: Double
    @UserDefault(key: "positionHistoryDistance", defaultValue: 0.5) var posHisDistance: Double
    
    // UserDefaults Enums (RawRepresentable)
    @UserDefaultRaw(key: "imageResolution", defaultValue: .normal) var imageResolution: ImageResolutionEnum
    @UserDefaultRaw(key: "previewMode", defaultValue: .topView) var previewMode: PreviewEnum
    @UserDefaultRaw(key: "elevation", defaultValue: .ang15) var elevation: ElevationValue
    // Only viDoc is supported; ignore rover selections saved by older versions.
    // @UserDefaultRaw(key: "RTKRoverSelected", defaultValue: .viDoc) var rtkTypeSelected: RTKRoverEnum
    let rtkTypeSelected: RTKRoverEnum = .viDoc
    @UserDefaultRaw(key: "ntripServiceProvider", defaultValue: .other) var ntripServiceProvider: NtripServiceProviderEnum
    
    // Custom Logic Fields
    var cameraOffsetSegment: CameraOffsetEnum {
        get { CameraOffsetEnum(string: UserDefaults.standard.string(forKey: "cameraOffsetSegment")) }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "cameraOffsetSegment") }
    }
    
    var lasLevel: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: "lasLevel")
            return (1...4).contains(val) ? val : 1
        }
        set { UserDefaults.standard.set(newValue, forKey: "lasLevel") }
    }
    
    var gnsss: Set<GNSSEnum> {
        get {
            let array = UserDefaults.standard.stringArray(forKey: "gnss") ?? ["GPS", "GALILEO", "QZSS", "GLONASS", "BEIDOU"]
            return Set(array.compactMap(GNSSEnum.init))
        }
        set { UserDefaults.standard.set(newValue.map(\.rawValue), forKey: "gnss") }
    }
    
    // Vectors SIMD3 Data Mapping
    var position: SIMD3<Float> {
        get {
            SIMD3(
                UserDefaults.standard.float(forKey: "positionX"),
                UserDefaults.standard.float(forKey: "positionY"),
                UserDefaults.standard.float(forKey: "positionZ")
            )
        }
        set { setVector(newValue.x, newValue.y, newValue.z, keys: "positionX", "positionY", "positionZ") }
    }
    
    var eulerAngles: SIMD3<Float> {
        get {
            SIMD3(
                UserDefaults.standard.float(forKey: "eulerAnglesX"),
                UserDefaults.standard.float(forKey: "eulerAnglesY"),
                UserDefaults.standard.float(forKey: "eulerAnglesZ")
            )
        }
        set { setVector(newValue.x, newValue.y, newValue.z, keys: "eulerAnglesX", "eulerAnglesY", "eulerAnglesZ") }
    }
    
    var customOffsetVidoc: SIMD3<Double> {
        get {
            SIMD3(
                UserDefaults.standard.double(forKey: "offsetX"),
                UserDefaults.standard.double(forKey: "offsetY"),
                UserDefaults.standard.double(forKey: "offsetZ")
            )
        }
        set { setVector(newValue.x, newValue.y, newValue.z, keys: "offsetX", "offsetY", "offsetZ") }
    }
    
    // Private Helpers
    private func setVector<T>(_ x: T, _ y: T, _ z: T, keys: String...) {
        UserDefaults.standard.set(x, forKey: keys[0])
        UserDefaults.standard.set(y, forKey: keys[1])
        UserDefaults.standard.set(z, forKey: keys[2])
    }
}

// MARK: - Camera
@propertyWrapper
struct UserDefault<Value> {
    let key: String
    let defaultValue: Value
    var wrappedValue: Value {
        get { UserDefaults.standard.object(forKey: key) as? Value ?? defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

@propertyWrapper
struct UserDefaultCodable<Value: Codable> {
    let key: String
    let defaultValue: Value
    var wrappedValue: Value {
        get {
            guard let data = UserDefaults.standard.string(forKey: key)?.data(using: .utf8) else { return defaultValue }
            return (try? JSONDecoder().decode(Value.self, from: data)) ?? defaultValue
        }
        set {
            if let data = try? JSONEncoder().encode(newValue), let str = String(data: data, encoding: .utf8) {
                UserDefaults.standard.set(str, forKey: key)
            }
        }
    }
}

@propertyWrapper
struct UserDefaultOptional<Value> {
    let key: String
    var wrappedValue: Value? {
        get { UserDefaults.standard.object(forKey: key) as? Value }
        set {
            if let value = newValue { UserDefaults.standard.set(value, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
    }
}

@propertyWrapper
struct UserDefaultCodableOptional<Value: Codable> {
    let key: String
    var wrappedValue: Value? {
        get {
            guard let data = UserDefaults.standard.string(forKey: key)?.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(Value.self, from: data)
        }
        set {
            guard let value = newValue,
                  let data = try? JSONEncoder().encode(value),
                  let str = String(data: data, encoding: .utf8) else {
                UserDefaults.standard.removeObject(forKey: key)
                return
            }
            UserDefaults.standard.set(str, forKey: key)
        }
    }
}

@propertyWrapper
struct UserDefaultRaw<Value: RawRepresentable> {
    let key: String
    let defaultValue: Value
    var wrappedValue: Value {
        get {
            guard let raw = UserDefaults.standard.object(forKey: key) as? Value.RawValue else { return defaultValue }
            return Value(rawValue: raw) ?? defaultValue
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}

@propertyWrapper
struct KeychainCodable<Value: Codable> {
    let key: String
    private let keychain = Keychain(service: "ltd.landlog.scquick3d")
    var wrappedValue: Value? {
        get {
            guard let jsonStr = try? keychain.getString(key), let data = jsonStr.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(Value.self, from: data)
        }
        set {
            if let value = newValue, let data = try? JSONEncoder().encode(value), let str = String(data: data, encoding: .utf8) {
                try? keychain.set(str, key: key)
            } else {
                try? keychain.remove(key)
            }
        }
    }
}
