//
//  UserManager.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 21/04/2022.
//

import Foundation
import Combine
import Alamofire
import SwiftUI

final class UserManager: ObservableObject {
    @Published var userInfo: UserInfo? = UserSession.shared.userInfo
    @Published var userLanguage: String = UserSession.userLanguage {
        didSet {
            UserSession.userLanguage = userLanguage
        }
    }
    
    @Published var showLicenseAlert: Bool = false
    @Published var showLicenseRegister: Bool = false
    
    @Published var setting = UserSetting(
        userId: UserSession.shared.userInfo?.userId,
        colorTheme: .light ,
        coordinateSetting: false,
        pointCloudBgcolor: "",
        pointCloudBgalpha: 1.0,
        linkDashboard: false,
        notifyByEmail: false,
        isTester: false
    )
    
    @Published var isAROcclusion: Bool = false
    
    var numOfLicenses: Double = 0.0
    var isARAvailable: Bool = false
    
    init() {
        Task {
            let isValid = await checkTokenValid()
            if isValid {
                print("Token is valid.")
            } else {
                print("Token is invalid.")
            }
        }
    }
    
    func getSetting(completion: (() -> Void)? = nil) {
        AF.request(URL(string: Constant.baseUrl + "api/v1/user/setting")!)
            .validate()
            .responseDecodable(of: UserSetting.self) { response in
                guard let setting = response.value else { return }
                self.setting = setting
                print(setting)
                print(self.setting)
                completion?()
            }
    }
    
    func updateSetting() {
        guard setting.userId != nil else { return }
        AF.request(URL(string: Constant.baseUrl + "api/v1/user/setting")!, method: .put, parameters: setting.toJson())
            .validate()
            .responseString { resp in
                print(resp.value)
                print(self.setting)
            }
    }
    
    func loginProcess(with sessionId: String, completion: @escaping (Bool) -> Void) {
        let cookieProps = [
            HTTPCookiePropertyKey.domain: Constant.domainUrl,
            HTTPCookiePropertyKey.path: "/",
            HTTPCookiePropertyKey.name: "connect.sid",
            HTTPCookiePropertyKey.value: sessionId
        ]
        if let cookie = HTTPCookie(properties: cookieProps) {
            AF.session.configuration.httpCookieStorage?.setCookie(cookie)
        }
        UserSession.shared.sessionId = sessionId
        
        completion(true)
    }
    
    func fetchLicense() async throws {
        let url = URL(string: Constant.baseUrl + "api/v1/user/licenses")!
        do {
            let data = try await AF.request(url)
                .validate()
                .serializingDecodable(LicenseStatus.self)
                .value
            
            guard let numOfLicenses = data.numOfLicenses else {
                throw NSError(domain: "InvalidData", code: 0, userInfo: [NSLocalizedDescriptionKey: "numOfLicenses is nil"])
            }
            guard let isARAvailable = data.isARAvailable else {
                throw NSError(domain: "InvalidData", code: 0, userInfo: [NSLocalizedDescriptionKey: "isARAvailable is nil"])
            }
            
            self.numOfLicenses = numOfLicenses
            self.isARAvailable = isARAvailable
            
            print(data)
        } catch {
            throw error
        }
    }
    
    func getUserInfo(completion: (() -> Void)? = nil) {
        AF.request(URL(string: Constant.baseUrl + "api/v1/user")!)
            .validate()
            .responseDecodable(of: UserInfo.self) { [weak self] response in
                self?.userInfo = response.value
                UserSession.shared.userInfo = response.value
                completion?()
            }
    }
    
//    func checkTokenValid() {
//        AF.request(URL(string: Constant.baseUrl + "login_check")!)
//            .validate()
//            .responseString { [weak self] response in
//                if response.response?.statusCode == 401 {
//                    self?.logout()
//                }
//            }
//    }
    
    func checkTokenValid() async -> Bool {
        do {
            let response = try await AF.request(URL(string: Constant.baseUrl + "login_check")!)
                .validate()
                .serializingData()
                .response

            if response.response?.statusCode == 200 {
                return true
            } else if response.response?.statusCode == 401 {
                logout()
                return false
            }
        } catch {
            print("Error: \(error)")
            return false
        }
        return false
    }
    
    func logout() {
        AF.request(URL(string: Constant.baseUrl + "logout")!)
            .validate()
            .responseString { [weak self] response in
                self?.userInfo = nil
                UserSession.shared.userInfo = nil
                UserSession.shared.sessionId = nil
                AF.session.configuration.httpCookieStorage?.removeCookies(since: Date(timeIntervalSince1970: 0))
            }
    }
}
