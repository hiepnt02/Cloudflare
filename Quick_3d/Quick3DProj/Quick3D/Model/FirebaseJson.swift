//
//  FirebaseJson.swift
//  Quick3D
//
//  Created by HaNST on 23/4/26.
//

import Foundation
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics
import Keys

struct FirebaseJson: Codable {
    let clientId: String?
    let reversedClientId: String?
    let apiKey: String
    let gcmSenderId: String
    let plistVersion: String
    let bundleId: String
    let projectId: String
    let storageBucket: String
    let googleAppId: String
    
    func getOptions() -> FirebaseOptions {
        let options = FirebaseOptions(googleAppID: googleAppId, gcmSenderID: gcmSenderId)
        options.apiKey = apiKey
        options.projectID = projectId
        options.storageBucket = storageBucket
        options.bundleID = bundleId
        options.storageBucket = storageBucket
        
        return options
    }
    
    func configure() {
        let options = getOptions()
        FirebaseApp.configure(options: options)
    }
}

struct FirebaseJsonEnv: Codable {
    let dev: FirebaseJson?
    let staging: FirebaseJson?
    let production: FirebaseJson?
    
    static func load() -> FirebaseJson? {
        let key = Quick3DKeys().firebaseKey
        
        if let data = Data(base64Encoded: key), let firebase = try? JSONDecoder().decode(FirebaseJsonEnv.self, from: data) {
            switch currentEnvironment {
            case .dev:
                return firebase.dev
            case .stg:
                return firebase.staging
            case .prod:
                return firebase.production
            }
        } else {
            print("Load firebase config failed")
        }
        
        return nil
    }
}
