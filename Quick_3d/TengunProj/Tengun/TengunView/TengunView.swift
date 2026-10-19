//  TeggunView.swift
//
//  Created by 木皿直規 on 2022/02/04.
// 参考ページ：
// https://tech-blog.optim.co.jp/entry/2021/05/06/100000

import ARKit
import SwiftUI
import SceneKit

//-------------------------------------------------
// TeggunView 点群画面
//-------------------------------------------------

struct TeggunView: View {
    @Binding var veiwMode: Int

    @State var tengunViewPosMode: Int
    @State var tengunViewMode: Int
    @State var phontoViewMode: Int
    
    @State private var isViewAlert: Bool

    @State var session: ARSession
    @State var scene: SCNScene
    @State var lineColor = Color.white

    init(veiwMode: Binding<Int>) {
        self._veiwMode = veiwMode
        self.tengunViewPosMode = 0
        self.tengunViewMode = 0
        self.phontoViewMode = 0
        self.isViewAlert = false
        
        let session = ARSession()
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        session.run(configuration)
        self.session = session

        self.scene = SCNScene()
        
        self.lineColor = Color.white
    }

    var body: some View {
        
        VStack() {
            let bounds = UIScreen.main.bounds
            let gWidth: CGFloat = CGFloat(Int(bounds.width))       // 画面横解像度
            let gHeight: CGFloat = CGFloat(Int(bounds.height))     // 画面縦解像度

            ZStack() {
                ARViewContainer()

/*
                ARSceneView(
                    session: self.$session,
                    scene: self.$scene,
                    lineColor: self.$lineColor
                )
                    .ignoresSafeArea()

                ColorPicker("Line Color", selection: self.$lineColor)
                    .padding()
*/
                /*
                Image(decorative: "tengun")
                     .resizable()    // 画像サイズをフレームサイズに合わせる
                     .frame(width: gWidth, height: gHeight - 20)     // フレームサイズの指定
                     .offset(x: 0, y: 10)
                */
                
                // 左上
                ZStack(alignment: .topLeading) {
                    Text("")
                        .frame(width: gWidth, height: gHeight)
                    
                    if(tengunViewPosMode == 0) {
                        Button(action: {    // 全体表示
                            tengunViewPosMode = 1
                        }) {
                            Image("globalview")
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80)
                        }
                    } else {
                        Button(action: {    // 現在の撮影位置から表示
                            tengunViewPosMode = 0
                        }) {
                            Image("humanview")
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80)
                        }
                    }
                }
                    .offset(x: 0, y: 20)
                
                // 右上
                ZStack(alignment: .topTrailing) {
                    Text("")
                        .frame(width: gWidth, height: gHeight)
                    
                    VStack {
                        if(tengunViewMode == 0) {
                            Button(action: {    // 点群　表示
                                tengunViewMode = 1
                            }) {
                                Image("tengunOn")
                                    .renderingMode(.original)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80)
                            }
                        } else {
                            Button(action: {    // 点群　表示
                                tengunViewMode = 0
                            }) {
                                Image("tengunOff")
                                    .renderingMode(.original)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80)
                            }
                        }
                        
                        if(phontoViewMode == 0) {
                            Button(action: {    // 撮影軌跡　表示
                                phontoViewMode = 1
                            }) {
                                Image("locusOn")
                                    .renderingMode(.original)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80)
                            }
                        } else {
                            Button(action: {    // 撮影軌跡　非表示
                                phontoViewMode = 0
                            }) {
                                Image("locusOff")
                                    .renderingMode(.original)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80)
                            }
                        }
                    }
                }
                    .offset(x: 0, y: 20)
                
                // 右下　設定
                ZStack(alignment: .bottomTrailing) {
                    Text("")
                        .frame(width: gWidth, height: gHeight)
                    
                    Button(action: {    // 拡大表示
                        self.isViewAlert = true
                    }) {
                        Image("expansion")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80)
                    }
                        .alert("わかりません！", isPresented: $isViewAlert) {
                            Button("OK") {
                            }
                        } message: {
                            Text("「標準の表示」ってなあに。")
                        }

/*
                    Button("標準の表示に戻る") {
                        self.isViewAlert = true
                    }
                        .frame(width: 150, height: 100)
                        .font(.title)
                        .foregroundColor(Color.red)
                        .background(Color.blue)
                        .alert("わかりません！", isPresented: $isViewAlert) {
                            Button("OK") {
                            }
                        } message: {
                            Text("「標準の表示」ってなあに。")
                        }
*/

                }
                
                // 左下
                ZStack(alignment: .bottomLeading) {
                    Text("")
                        .frame(width: gWidth, height: gHeight)
                    
                    Button(action: {    // 縮小表示
                        veiwMode = 0
                    }) {
                        Image("shrink")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80)
                    }
                }
            }
        }
    }
}

/*
struct TeggunView_Previews: PreviewProvider {
    static var previews: some View {
        TeggunView(veiwMode: .constant(4))
            .previewDevice("iPad Pro (11-inch)")
            .previewInterfaceOrientation(.landscapeRight)
    }
}
*/

// UIViewControllerの場合
struct ARViewContainer: UIViewControllerRepresentable {
    typealias UIViewControllerType = ViewController
    
    func makeUIViewController(context: Context) -> ViewController {
        return ViewController()
    }
    
    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
    }
}
