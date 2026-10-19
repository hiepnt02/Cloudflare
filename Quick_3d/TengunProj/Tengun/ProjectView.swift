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
    
    let secondList = ["サンプルプロジェクト01", "サンプルプロジェクト02", "サンプルプロジェクト03", "サンプルプロジェクト04", "サンプルプロジェクト05", "サンプルプロジェクト06", "サンプルプロジェクト07", "サンプルプロジェクト08"]

    var body: some View {
        VStack() {
            if isWebViewShow == false {
                Button {
                    veiwMode = 0
                } label: {
                    Text("< カメラ画面")
                        .leftAligned()
                }
            }

            NavigationView{
                List{
                    ForEach(secondList, id: \.self) { item in
                        NavigationLink(destination: ChildDetail(isWebViewShow: $isWebViewShow)) {
                            Text(item)
                        }
                    }
                }
                    .navigationTitle("プロジェクト画面")
            }
                .navigationViewStyle(StackNavigationViewStyle())
        }
            .offset(x: 0, y: 5)
            .onAppear {
                print("ProjectViewを表示")
            }.onDisappear {
                print("ProjectViewを非表示")
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

struct ChildDetail: View {
    
    @Binding var isWebViewShow: Bool

    var body: some View {
        WebViewTest()
            .onAppear {
                print("WebViewTestを表示")
                isWebViewShow = true
            }.onDisappear {
                print("WebViewTestを非表示")
                isWebViewShow = false
            }

    }
}

struct WebViewTest: UIViewRepresentable {
    let url: String = UserDefaults.standard.string(forKey: "URLStr") ?? "https://fast.com/ja/"

    func makeUIView(context: Context) -> WKWebView{
        return WKWebView()
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        print("URLStr：" + (url))
        uiView.load(URLRequest(url: URL(string: url)!))
    }
}
 
struct WebViewTest_Previews: PreviewProvider {
    static var previews: some View {
        WebViewTest()
            .previewInterfaceOrientation(.landscapeRight)
    }
}


