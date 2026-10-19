//
//  ProductWebView.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 23/04/2022.
//

import SwiftUI
import WebKit
import Reachability
import Alamofire

typealias updateFunc = (_ projectId: String, _ jobsiteId: String, _ for: Cat) -> Void
typealias backFunc = ( ) -> Void
typealias openSfMFunc = ( ) -> Void

struct ProductWebView: UIViewRepresentable {
    var url: URL?
    var pointCloudUrl: URL?
    var useIndexUrl: Bool {
        return url == nil && pointCloudUrl != nil
    }
    //    @Binding var action: ViewerAction
    var cat: Cat
    @EnvironmentObject var productData: ProductData
    @EnvironmentObject var userManager: UserManager
    //    @EnvironmentObject var productData: ProductData
    var updateProjectId: updateFunc
    var backToHome: backFunc
    var openSfM: openSfMFunc
    static var webView: WKWebView?
    static var initialZoomScale: CGFloat?
    private let observable = WebViewURLObservable()
    @Binding var isActiveContent: Bool;

    var observer: NSKeyValueObservation? {
        observable.instance
    }
    
    func makeCoordinator() -> ProductWebView.Coordinator {
        return Coordinator(useIndexUrl, pointCloudUrl: pointCloudUrl, lang: userManager.userLanguage, cat: cat, userManager: userManager, updateProjectId: updateProjectId, backToHome: backToHome, openSfM: openSfM)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "callback")
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        configuration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        configuration.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.restoreCookies()
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        ProductWebView.webView = webView
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.restoreCookies()
        uiView.navigationDelegate = context.coordinator
        context.coordinator.useIndexUrl = useIndexUrl
        context.coordinator.pointCloudUrl = pointCloudUrl
        
        observable.instance = uiView.observe(\WKWebView.url, options: .new) { view, change in
            if let observedURL = view.url {
                if let url = url {
                    print("Page URL: \(observedURL)")
                    if observedURL.host != url.host {
                        userManager.logout()
                        productData.removeRemoteProject()
                        productData.removeJobsiteData()
                        productData.resetTotalCount()
                        userManager.userInfo = nil
                        isActiveContent = false;
                    }
                }
            }
        }
        
        //        offline viewerかどうか
        if let url = url {
            if cat.jobsiteId != "" && !context.coordinator.isInit { return }
            if cat.jobsiteId == "" && !context.coordinator.isInitPly { return }
            Thread.sleep(forTimeInterval: 0.3)
            uiView.load(URLRequest(url: url))
            if cat.jobsiteId == "" {
                context.coordinator.isInitPly = false
            } else {
                context.coordinator.isInit = false
            }
        } else {
            if !context.coordinator.isInitLocal { return }
            guard
                var pointCloudUrl = pointCloudUrl,
                let indexUrl = Bundle.main.path(forResource: "index", ofType: "html"),
                let pathToMainJs = Bundle.main.path(forResource: "main", ofType: "js"),
                let pathToMainCss = Bundle.main.path(forResource: "main", ofType: "css")
            else { return }
            do {
                var strHTMLContent = try String(contentsOfFile: indexUrl)
                
                strHTMLContent = strHTMLContent.replacingOccurrences(of: "./main.js", with: pathToMainJs)
                strHTMLContent = strHTMLContent.replacingOccurrences(of: "./main.css", with: pathToMainCss)
                let baseUrl = URL(fileURLWithPath: indexUrl)
                uiView.loadFileURL(pointCloudUrl.deletingLastPathComponent(), allowingReadAccessTo: pointCloudUrl.deletingLastPathComponent())
                uiView.loadHTMLString(strHTMLContent, baseURL: baseUrl)
            } catch  {
                
            }
            context.coordinator.updateCat(cat: cat)
            context.coordinator.isInitLocal = false
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKDownloadDelegate, WKScriptMessageHandler {
        var useIndexUrl: Bool
        var pointCloudUrl: URL?
        var downloadUrl: URL?
        var lang: String
        var webView: WKWebView?
        var cat: Cat
        var updateProjectId: updateFunc
        var backToHome: backFunc
        var openSfM: openSfMFunc
        var isInit: Bool = true
        var isInitLocal: Bool = true
        var isInitPly: Bool = true
        var userManager: UserManager
        
        init(_ useIndexUrl: Bool, pointCloudUrl: URL?, lang: String, cat: Cat, userManager: UserManager, updateProjectId: @escaping updateFunc, backToHome: @escaping backFunc, openSfM: @escaping openSfMFunc) {
            self.useIndexUrl = useIndexUrl
            self.pointCloudUrl = pointCloudUrl
            self.lang = lang
            self.cat = cat
            self.updateProjectId = updateProjectId
            self.backToHome = backToHome
            self.openSfM = openSfM
            self.userManager = userManager
            
            //　最初に取得しないと矢印の色が変わらない時があるので
            userManager.getSetting()
            //Viewが呼び出された後に行う処理で都合が良かったのでこちらでログの出力
            print("現場詳細画面起動ログ")
            AnalyticsHelper.logScreenViewWithSiteID(screenName: "現場詳細画面起動", siteID: cat.jobsiteId!)
            
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            let data = message.body as AnyObject
            let type = data["type"]!! as! String
            let props = data["props"] as AnyObject
            
            switch type {
            case "download":
                download(props: props)
            case "openLLV":
                let siteId = props["siteId"] as! String
                let url = URL(string: Constant.llvURL + siteId)
                UIApplication.shared.open(url!)
            case "back":
                backToHome()
            case "clipboard":
                guard let base64String = props["image"] as? String, let range = base64String.range(of: "base64,")  else { return }
                
                let substring = base64String[range.upperBound...]
                
                guard let imageData = Data(base64Encoded: String(substring), options: []) else { return }
                UIPasteboard.general.image = UIImage(data: imageData)
            case "openSfM":
                openSfM()
            case "log":
                print(props)
            case "reload":
                userManager.getSetting()
            case "setTheme":
                if let stringValue = props as? String {
                    if stringValue == "light" || stringValue == "dark"{
                        userManager.setting.colorTheme = ColorThemeEnum.from(stringValue)
                    }
                    else{
                        print("theme value error")
                    }
                } else {
                    print("cast error")
                }
            default:
                break
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            self.webView = webView
            guard let pointCloudFile = pointCloudUrl?.absoluteString else { return }
            guard useIndexUrl else { return }
            print(pointCloudFile)
            webView.evaluateJavaScript("ptLoader('\(pointCloudFile)')")
            webView.evaluateJavaScript("changeLocal('\(lang)')")
            webView.evaluateJavaScript("changeProjectName('\(cat.title)')")
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
            if navigationAction.shouldPerformDownload {
                decisionHandler(.download, preferences)
            } else {
                decisionHandler(.allow, preferences)
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if navigationResponse.canShowMIMEType {
                decisionHandler(.allow)
            } else {
                decisionHandler(.download)
            }
        }
        
        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
        }
        
        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }
        
        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
            // verificationPointsを取得する際はこちらが走る: スクリーンショットの撮影をweb側に任せているため
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            let folderName = "\(cat.title)"
            var url = documentsDirectory!.appendingPathComponent(folderName)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            let ext = suggestedFilename.fileExtension
            let fileName = "\(suggestedFilename.replacingOccurrences(of: ".\(ext)", with: ""))"
            url = url.appendingPathComponent("\(fileName).\(ext)")
            downloadUrl = url
            completionHandler(url)
        }
        
        func downloadDidFinish(_ download: WKDownload) {
            guard let downloadUrl = downloadUrl else { return }
            let path = downloadUrl.absoluteString.replacingOccurrences(of: "file://", with: "shareddocuments:///private")
            guard let url = URL(string: path) else { return }
            UIApplication.shared.open(url, options: [:])
        }
        
        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            print("error ", error.localizedDescription)
        }
        
        func updateCat(cat: Cat) {
            self.cat = cat
        }
        
//        func uploadPLYFile(pointCloudFile: String) {
//            uploadPLY.upload(with: cat, fileUrl: URL(string: pointCloudFile), userManager: self.userManager)
//            uploadPLY.uploadProgress = { progress in
//            }
//            uploadPLY.responseHandler = { resp in
//                DispatchQueue.main.async {
//                    guard let projectId = resp?.projectId else {
//                        return
//                    }
//                    self.webView?.evaluateJavaScript("uploadPLY()")
//                    self.updateProjectId(projectId, "", self.cat)
//                }
//            }
//        }
        
        func download(props: AnyObject) {
            guard let projectId = cat.projectId else { return }
            AF.download(URL(string: String(format: Constant.baseUrl + "api/v1/project/%@/download", projectId))!,
                        method: .post,
                        parameters: ["LiDAR": props["LiDAR"]!!,
                                     "sfm": props["sfm"]!!,
                                     "helmert": props["helmert"]!!,
                                     "referencePoints": props["referencePoints"]!!,
                                     "verificationPoints": props["verificationPoints"]!!,
                                     "images": props["images"]!!,
                                     "qualityReport": props["qualityReport"]!!,
                                     "fileType": props["fileType"]!!
                                    ],
                        encoding: JSONEncoding.default,
                        requestModifier: { $0.timeoutInterval = 180.0 },
                        to: { _, response in
                if let suggestedFilename = response.suggestedFilename {
                    if let decodedString = suggestedFilename.removingPercentEncoding {
                        // 想定通り
                        print(decodedString)
                        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let folderName = "\(self.cat.title)"
                        let fileName = documentsDirectory.appendingPathComponent(folderName).appendingPathComponent(decodedString)
                        
                        return (fileName, [.removePreviousFile, .createIntermediateDirectories])
                    } else {
                        // ファイル名がdecodeできない場合
                        print("Failed to decode the string.")
                        let defaultFilename = "noname"
                        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let folderName = "\(self.cat.title)"
                        let fileName = documentsDirectory.appendingPathComponent(folderName).appendingPathComponent(defaultFilename)
                        return (fileName, [.removePreviousFile, .createIntermediateDirectories])
                    }
                } else {
                    // ファイル名が正常でない場合
                    let defaultFilename = "noname"
                    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let folderName = "\(self.cat.title)"
                    let fileName = documentsDirectory.appendingPathComponent(folderName).appendingPathComponent(defaultFilename)
                    return (fileName, [.removePreviousFile, .createIntermediateDirectories])
                }
            })
            .response { [self] resp in
                switch resp.result {
                case .success(let url):
                    guard let url = url else { return }
                    self.webView?.evaluateJavaScript("successDownload()")
                    let path = url.absoluteString.replacingOccurrences(of: "file://", with: "shareddocuments:///private")
                    guard let url = URL(string: path) else { return }
                    UIApplication.shared.open(url, options: [:])
                    break
                case .failure(_):
                    self.webView?.evaluateJavaScript("errorDownload()")
                    break
                }
            }
        }
    }
}

private class WebViewURLObservable: ObservableObject {
    @Published var instance: NSKeyValueObservation?
}
