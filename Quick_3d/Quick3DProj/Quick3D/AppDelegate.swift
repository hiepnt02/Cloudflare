//
//  AppDelegate.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 17/04/2022.
//

import Foundation
import UIKit
import IQKeyboardManagerSwift
import Alamofire
import FirebaseCore
import FirebaseAnalytics

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        IQKeyboardManager.shared.enable = true
        
        FirebaseApp.configure()
        
        setInitialUserProperties()
        
        if let sessionId = UserSession.shared.sessionId {
            let cookieProps = [
                HTTPCookiePropertyKey.domain: Constant.domainUrl,
                HTTPCookiePropertyKey.path: "/",
                HTTPCookiePropertyKey.name: "connect.sid",
                HTTPCookiePropertyKey.value: sessionId
            ]
            if let cookie = HTTPCookie(properties: cookieProps) {
                AF.session.configuration.httpCookieStorage?.setCookie(cookie)
            }
        }

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return true }
        var localProjects = UserSession.products
        if let enumerator = FileManager.default.enumerator(atPath: documentsDirectory.path) {
            while let element = enumerator.nextObject() as? String {
                if element.contains("Inbox/") {
                    try? FileManager.default.removeItem(at: documentsDirectory.appendingPathComponent(element))
                }
                var isRemove = true
                for project in localProjects {
                    if element.contains(project.folderName) {
                        isRemove = false
                        break
                    }
                }
                if isRemove {
                    try? FileManager.default.removeItem(at: documentsDirectory.appendingPathComponent(element))
                }
            }
        }
        
        return true
    }
    
    func setInitialUserProperties() {
        //ユーザーID
        if let userId = UserSession.shared.userInfo?.userId {
            Analytics.setUserProperty(userId, forName: "sc_user_id")
        }

        //企業ID
        if let corporationId = UserSession.shared.userInfo?.corporationId {
            Analytics.setUserProperty(corporationId, forName: "sc_corporation_id")
        }
    }

}
