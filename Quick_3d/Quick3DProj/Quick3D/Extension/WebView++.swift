//
//  WebView++.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 21/04/2022.
//

import Foundation
import WebKit

extension WKWebView {

    private var httpCookieStore: WKHTTPCookieStore  { return WKWebsiteDataStore.default().httpCookieStore }

    func getCookies(completion: @escaping ([String : Any])->())  {
        var cookieDict = [String : AnyObject]()
        httpCookieStore.getAllCookies { cookies in
            for cookie in cookies {
                cookieDict[cookie.name] = cookie.properties as AnyObject?
            }
            completion(cookieDict)
        }
    }
    
    func storeCookies() {
        var cookiesArr = [HTTPCookie]()
        httpCookieStore.getAllCookies { cookies in
            cookiesArr.append(contentsOf: cookies)
            UserSession.shared.cookies = cookiesArr
        }
    }
    
    func restoreCookies() {
        if let cookies = UserSession.shared.cookies {
            for cookie in cookies {
                httpCookieStore.setCookie(cookie)
            }
        }
    }
    
    func clearCookies() {
        httpCookieStore.getAllCookies { [weak self] cookies in
            cookies.forEach({ self?.httpCookieStore.delete($0) })
        }
    }
}
