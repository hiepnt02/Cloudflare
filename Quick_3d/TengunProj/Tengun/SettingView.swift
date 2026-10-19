//  SettingView.swift
//
//  Created by 木皿直規 on 2022/02/04.
//

import SwiftUI

//-------------------------------------------------
// SettingView 設定画面
//-------------------------------------------------
struct SettingView: View {
    @Binding var veiwMode: Int
    
    @State private var overlapValue: Double = 50
    @State private var colorRedValue: Double = 127
    @State private var colorGreenValue: Double = 127
    @State private var colorBuleValue: Double = 127
    @State private var opachityValue: Double = 0.5
    
    @State var isShowOverlap: Bool = true
    @State var isShowCameraPos: Bool = true
    @State var isShowMovementPaht: Bool = true
    @State var isLowQualitySkip: Bool = true
    @State var isNoGPSLowPhoto: Bool = true
    
    @State var URLStr:String = ""
    
    @State private var isDoInitialAlert = false

    var body: some View {
        
        VStack() {
            HStack() {
                Button(" < 終了") {
                    veiwMode = 0
                }
                Spacer()
                Text("設定画面")
                    .foregroundColor(Color.red)
                    .font(.custom("Times-Roman", size: 25))
                Spacer()
                
                Button("リセット") {
                    print("タップされました")
                    self.isDoInitialAlert = true
                }
                .foregroundColor(Color.red)
                .background(Color.blue)
                .alert(isPresented: $isDoInitialAlert) {
                    Alert(title: Text("リセットボタンがタップされました。設定の全ての値を初期値に戻します。"))
                }
            }
            
            Form {
                Section(header: Text("画像トリガ設定")) {
                    HStack() {
                        Text("オーバーラップ率：")
                        Slider(value: $overlapValue, in: 0...100)
                        Text(String(format: "%.1f", overlapValue))
                    }
                        .padding()
                }
                
                Section(header: Text("アドバンス設定")) {
                    HStack() {
                        Toggle(isOn: $isShowOverlap) {
                            Text("オーバーラップ率の表示・非表示：")
                        }
                        Text(isShowOverlap ? "ON" : "OFF")
                     }
                        .padding()

                    HStack() {
                        Toggle(isOn: $isShowCameraPos) {
                            Text("メッシュの切り替え　撮影位置の表示切替：")
                        }
                            .padding()
                        Text(isShowCameraPos ? "ON" : "OFF")
                    }
                    
                    HStack() {
                        Toggle(isOn: $isShowMovementPaht) {
                            Text("　　　　　　　　　　撮影軌跡の表示切替：")
                        }
                            .padding()
                        Text(isShowMovementPaht ? "ON" : "OFF")
                    }

                    Group() {
                        HStack() {
                            Text("メッシュ色変更　　赤：")
                            Slider(value: $colorRedValue, in: 0...255)
                            Text(String(format: "%.0f", colorRedValue))
                        }
                            .padding()
                        HStack() {
                            Text("　　　　　　　　　緑：")
                            Slider(value: $colorGreenValue, in: 0...255)
                            Text(String(format: "%.0f", colorGreenValue))
                        }
                            .padding()
                        HStack() {
                            Text("　　　　　　　　　青：")
                            Slider(value: $colorBuleValue, in: 0...255)
                            Text(String(format: "%.0f", colorBuleValue))
                        }
                            .padding()
                        HStack() {
                            Text("　　　　　　　透明度：")
                            Slider(value: $opachityValue, in: 0...1)
                            Text(String(format: "%.1f", opachityValue))
                        }
                            .padding()
                    }
                    
                    HStack() {
                        Toggle(isOn: $isLowQualitySkip) {
                            Text("画質の低い画像のスキップ：")
                        }
                        Text(isLowQualitySkip ? "ON" : "OFF")
                    }

                    HStack() {
                        Toggle(isOn: $isNoGPSLowPhoto) {
                            Text("GPS低下時は撮影を行わない：")
                        }
                        Text(isNoGPSLowPhoto ? "ON" : "OFF")
                    }
                }
                
                Section(header: Text("ソフト開発時の設定")) {
                    HStack() {
                        Text("URL：")
                        TextField("https://www.cct-inc.co.jp/", text: $URLStr) {
                            // 文字入力が終わると呼ばれる
                            UserDefaults.standard.set(self.URLStr, forKey: "URLStr")
                        }
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerSize:CGSize(width:4.0, height:4.0))
                                    .stroke(Color.black, lineWidth:1.0)
                                    .padding(3.0)
                            )
                    }
                        .padding()
                        .onAppear{
                            //　表示前に呼ばれる
                            // UserDefaultsから読み読み出す
                            guard let userdefaultText = UserDefaults.standard.string(forKey: "URLStr") else { return }
                            self.URLStr = userdefaultText
                        }
                }
            }
        }
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView(veiwMode: .constant(3))
            .previewDevice("iPad Pro (11-inch)")
            .previewInterfaceOrientation(.portraitUpsideDown)
    }
}

