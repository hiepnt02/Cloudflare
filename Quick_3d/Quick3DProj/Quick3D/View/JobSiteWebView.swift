//
//  JobSiteWebView.swift
//  Quick3D
//
//  Created by 木皿直規 on 2022/05/10.
//

import SwiftUI
import WebKit

//-------------------------------------------------
// JobSiteWebView  新規現場先画面
//-------------------------------------------------
struct JobSiteWebView: View {
    @State private var isWebViewShow = false
    @Environment(\.presentationMode) var presentation
    @EnvironmentObject var userManager: UserManager
    var didClose: () -> Void

    var body: some View {
        VStack() {
            Button(action: {
                self.presentation.wrappedValue.dismiss()
                didClose()
            }, label: {
                Text("CLOSE".localized(userManager.userLanguage)) // 閉じる
                    .leftAligned()
            })

            JobSiteWebViewTest()
                .onAppear {
                    print("JobSiteWebViewを表示")
                    isWebViewShow = true
                }.onDisappear {
                    print("JobSiteWebViewを非表示")
                    isWebViewShow = false
                }
        }
    }
}
                
struct JobSiteWebView_Previews: PreviewProvider {
    static var previews: some View {
        JobSiteWebView() {}
            .previewDevice("iPad Pro (11-inch)")
            .previewInterfaceOrientation(.landscapeRight)
    }
}

//---------------------------
// MARK: - JobSiteWebViewTest
//---------------------------
struct JobSiteWebViewTest: UIViewRepresentable {
    let projectURLPath: String = Constant.addSiteUrl
    let currentProjectIDStr: String = UserDefaults.standard.object(forKey: "currentProjectID") as? String ?? "fe2df626-296b-42ec-963a-a45db5ea794f"

    func makeUIView(context: Context) -> WKWebView{
        return WKWebView()
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        print("currentProjectIDStr：" + currentProjectIDStr)
        uiView.load(URLRequest(url: URL(string: projectURLPath)!))
    }
}
 
struct JobSiteWebViewTest_Previews: PreviewProvider {
    static var previews: some View {
        JobSiteWebViewTest()
            .previewInterfaceOrientation(.landscapeRight)
    }
}
