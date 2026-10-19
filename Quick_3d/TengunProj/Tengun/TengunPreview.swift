//  TengunPreview.swift
//
//  Created by 木皿直規 on 2022/02/04.
//

import ARKit
import SwiftUI
import SceneKit

//-------------------------------------------------
// 点群プレプレビュー
//-------------------------------------------------
struct TengunPreview: View {
    let gWidth: CGFloat = CGFloat(Int(2388/6))       // 横Viewサイズ
    let gHeight: CGFloat = CGFloat(Int(1668/6))     // 横Viewサイズ
    
    @State private var isShow = true

    @Binding var veiwMode: Int
    @State var session: ARSession
    @State var scene: SCNScene
    @State var lineColor = Color.white

    init(veiwMode: Binding<Int>) {
        self._veiwMode = veiwMode
         
        let session = ARSession()
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        session.run(configuration)
        self.session = session

        self.scene = SCNScene()
        
        self.lineColor = Color.white
    }


    var body: some View {
        ZStack() {
            if(isShow == true) {
                /*
                ARSceneView(
                    session: self.$session,
                    scene: self.$scene,
                    lineColor: self.$lineColor
                )
                    .ignoresSafeArea()
                    .frame(width: gWidth, height: gHeight)     // フレームサイズの指定
                */
                
                Image(decorative: "tengun")
                     .resizable()    // 画像サイズをフレームサイズに合わせる
                     .frame(width: gWidth, height: gHeight)     // フレームサイズの指定
                 
                
                // 右下
                ZStack(alignment: .bottomTrailing) {
                    Text("")
                        .frame(width: gWidth, height: gHeight)
                    
                    Button(action: {    // 拡大表示
                        veiwMode = 4
                    }) {
                        Image("expansion")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80)
                    }
                }

                // 左下
                ZStack(alignment: .bottomLeading) {
                    Text("")
                        .frame(width: gWidth, height: gHeight)
                    
                    Button(action: {    // 消す
                        isShow = false
                    }) {
                        Image("erase")
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80)
                    }
                }
            } else {
                Button {
                    isShow = true
                } label: {
                    Text("表示")
                        .frame(width: 25, height: 25)
                        .foregroundColor(Color.red)
                        .background(Color.blue)
                }
            }
        }
    }
}

struct TengunPreview_Previews: PreviewProvider {
    static var previews: some View {
        TengunPreview(veiwMode: .constant(1))
            .previewDevice("iPad Pro (11-inch)")
            .previewInterfaceOrientation(.landscapeRight)
    }
}


