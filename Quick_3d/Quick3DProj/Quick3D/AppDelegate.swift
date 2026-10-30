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
    
    static var orientationLock = UIInterfaceOrientationMask.landscapeRight {
        didSet {
            
            if #available(iOS 16.0, *) {
                UIApplication.shared.connectedScenes.forEach { scene in
                    if let windowScene = scene as? UIWindowScene {
                        windowScene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientationLock))
                    }
                }
            } else {
                if orientationLock == .landscape {
                    UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
                } else {
                    UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                }
            }
        }
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        IQKeyboardManager.shared.enable = true

        FirebaseJsonEnv.load()?.configure()

        setInitialUserProperties()

        resetDisclaimerOnFirstRun()
        
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
                if UserSession.shared.isEnableLog {
                    let relativeURL = URL(fileURLWithPath: element)
                    let isCameraPath = element == "Camera" || element.hasPrefix("Camera/")
                    if element == "Camera" ||
                        (isCameraPath && relativeURL.pathExtension.lowercased() == "zip") {
                        continue
                    }
                }
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
    
    /// On the very first launch after an install, make sure the disclaimer is shown
    /// again even though a previous install may have left `didDisclaimerKey` set.
    /// Used to live in a `MainScreen.InitialSet` object that was re-created on every
    /// render of the screen; launch is the only moment it actually has to run.
    private func resetDisclaimerOnFirstRun() {
        guard !UserDefaults.standard.bool(forKey: "firstRun") else { return }
        UserDefaults.standard.set(true, forKey: "firstRun")
        UserDefaults.standard.set(false, forKey: "didDisclaimerKey")
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
