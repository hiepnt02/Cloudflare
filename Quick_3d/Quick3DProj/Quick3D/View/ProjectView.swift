//  ProjectView.swift
//
//  Created by 木皿直規 on 2022/02/04.
// https://tamappe.com/2020/07/27/2020-07-27-200000/

import SwiftUI
import WebKit

//-------------------------------------------------
// ProjectView プロジェクト画面
//-------------------------------------------------
struct ProjectView: View {
    @Binding var veiwMode: Int
    @State private var isWebViewShow = false
    @Environment(\.presentationMode) var presentation

    var body: some View {
        VStack() {
            Button(action: {
                self.presentation.wrappedValue.dismiss()
            }, label: {
                Text("CLOSE") // 閉じる
                    .leftAligned()
            })

            WebViewTest()
                .onAppear {
                    print("ProjectViewを表示")
                    isWebViewShow = true
                }.onDisappear {
                    print("ProjectViewを非表示")
                    isWebViewShow = false
                }
        }
    }
}
                
struct ProjectView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectView(veiwMode: .constant(2))
            .previewDevice("iPad Pro (11-inch)")
            .previewInterfaceOrientation(.landscapeRight)
    }
}

//---------------------------
// MARK: - WebViewTest
//---------------------------
struct WebViewTest: UIViewRepresentable {
    let projectURLPath: String = Constant.baseUrl + "1/"

    let currentProjectIDStr: String = UserDefaults.standard.object(forKey: "currentProjectID") as? String ?? "fe2df626-296b-42ec-963a-a45db5ea794f"

    func makeUIView(context: Context) -> WKWebView{
        return WKWebView()
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        print("currentProjectIDStr：" + currentProjectIDStr)
        uiView.load(URLRequest(url: URL(string: projectURLPath + currentProjectIDStr)!))
    }
}
 
struct WebViewTest_Previews: PreviewProvider {
    static var previews: some View {
        WebViewTest()
            .previewInterfaceOrientation(.landscapeRight)
    }
}
