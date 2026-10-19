//
//  LoginWebView.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 21/04/2022.
//

import SwiftUI
import WebKit

struct LoginWebView: UIViewRepresentable {
    var loginSuccess: ((String) -> Void)? = nil

    func makeCoordinator() -> LoginWebView.Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.clearCookies()
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.navigationDelegate = context.coordinator

        uiView.load(URLRequest(url: URL(string:  Constant.baseUrl + "login")!))
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: LoginWebView

        init(_ parent: LoginWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            webView.getCookies() { [weak self] data in
                guard
                    let connectSid = data["connect.sid"] as? [String: Any],
                    let sessionId = connectSid["Value"] as? String
                else {
                    return
                }
                webView.storeCookies()
                self?.parent.loginSuccess?(sessionId)
            }
            decisionHandler(.allow)
        }
    }
}
