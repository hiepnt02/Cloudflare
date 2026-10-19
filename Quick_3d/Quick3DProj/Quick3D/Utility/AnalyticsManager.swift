//
//  AnalyticsManager.swift
//  Quick3D
//
//  Created by yoshiaki.kakinuma on 2023/12/07.
//

import FirebaseAnalytics

struct AnalyticsHelper {
    static func logScreenView(screenName: String) {
        //イベント名 screen_view
        //パラメータ それぞれの画面の名前

        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,

        ])
    }
    
    static func logScreenViewWithSiteID(screenName: String, siteID: String) {
        // イベント名: screen_view
        // パラメータ: それぞれの画面の名前とサイトID

        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            "sc_site_id": siteID
        ])
        
        Analytics.setUserProperty(siteID, forName: "sc_site_id")
    }

}
