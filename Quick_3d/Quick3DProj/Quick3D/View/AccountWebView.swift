//
//  AccountWebView.swift
//  Quick3D
//
//  Created by 横内浩志 on 2022/09/13.
//

import SwiftUI
import WebKit

struct AccountWebView: View {
    @State private var isWebViewShow = false
    @Environment(\.presentationMode) var presentation
    @EnvironmentObject var userManager: UserManager

    var body: some View {
        VStack() {
            Button(action: {
                self.presentation.wrappedValue.dismiss()
            }, label: {
                Text("CLOSE".localized(userManager.userLanguage)) // 閉じる
                    .leftAligned()
            })

            AccountWebViewTest()
                .onAppear {
                    print("AccountWebViewを表示")
                    isWebViewShow = true
                }.onDisappear {
                    print("AccountWebViewを非表示")
                    isWebViewShow = false
                }
        }
    }
}
                
struct AccountWebView_Previews: PreviewProvider {
    static var previews: some View {
        JobSiteWebView() {}
            .previewDevice("iPad Pro (11-inch)")
            .previewInterfaceOrientation(.landscapeRight)
    }
}

struct AccountWebViewTest: UIViewRepresentable {
    let projectURLPath: String = Constant.accountManagerUrl
    let currentProjectIDStr: String = UserDefaults.standard.object(forKey: "currentProjectID") as? String ?? "fe2df626-296b-42ec-963a-a45db5ea794f"

    func makeUIView(context: Context) -> WKWebView{
        return WKWebView()
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        print("currentProjectIDStr：" + currentProjectIDStr)
        uiView.load(URLRequest(url: URL(string: projectURLPath)!))
        print("--------------------------")
    }
}
 
struct AccountWebViewTest_Previews: PreviewProvider {
    static var previews: some View {
        JobSiteWebViewTest()
            .previewInterfaceOrientation(.landscapeRight)
    }
}
