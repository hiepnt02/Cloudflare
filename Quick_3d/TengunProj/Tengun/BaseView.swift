//  BaseView.swift
//
//  Created by 木皿直規 on 2022/02/04.
//

import SwiftUI
import AVFoundation

//-------------------------------------------------
// BaseView メインビュー
//-------------------------------------------------
struct BaseView: View {
    @Binding var veiwMode: Int
    @Binding var photoStatus: Int
    @ObservedObject var myTimer = MyTimer()

    @State private var isSaveAlert = false
    @State var fileNameString: String = ""
  
    @State private var isEditAlert = false
    @State var text: String = ""
    
    @State var isShowLoninAlert: Bool = false
    @State var idString: String = ""
    @State var passWradString: String = ""

    @State var recordingStatus: RecordingStatus = .ready

    var body: some View {
        let bounds = UIScreen.main.bounds
        let gWidth: CGFloat = CGFloat(Int(bounds.width))       // 画面横解像度 834
        let gHeight: CGFloat = CGFloat(Int(bounds.height))     // 画面縦解像度 1194

        ZStack() {
/*
            CameraView(recordingStatus: $recordingStatus) { url in
                recordingStatus = .ready
                print(url)
            }
                .frame(width: 1450, height: gHeight - 10)
                .offset(x: 0, y: 10)
*/
 /*
            Image(decorative: "camera")
                 .resizable()    // 画像サイズをフレームサイズに合わせる
                 .frame(width: gWidth, height: gHeight - 20)     // フレームサイズの指定
                 .offset(x: 0, y: 10)
 */
            // 上中央
            ZStack(alignment: .top){
                Text("")
                    .frame(width: gWidth, height: gHeight)

                Text(String(format:"%.0d", myTimer.num))
                    .offset(x: 0, y: 20)
                    .foregroundColor(Color.white)
                    .font(Font.system(size: 50).bold())
                    .position(x: gWidth/2 + 600, y: gHeight/2 - 100)
            }
            
            // 左上
            ZStack(alignment: .topLeading) {
                Text("")
                    .frame(width: gWidth, height: gHeight)
        
                TopLeadingView(veiwMode: $veiwMode)
            }
                .offset(x: 0, y: 20)
            
            // 右上
            ZStack(alignment: .topTrailing) {
                Text("")
                    .frame(width: gWidth, height: gHeight)

                TopTrailingView(veiwMode: $veiwMode, photoStatus: $photoStatus, isShowLoninAlert: $isShowLoninAlert, isSaveAlert: $isSaveAlert, myTimer: myTimer)
            }
                .offset(x: 0, y: 20)
             
            // 右下　設定
            ZStack(alignment: .bottomTrailing) {
                Text("")
                    .frame(width: gWidth, height: gHeight)
                
                BottomTrailingView(veiwMode: $veiwMode)
            }

            // 左下　点群プレビュー
            ZStack(alignment: .bottomLeading) {
                Text("")
                    .frame(width: gWidth, height: gHeight)
                
                BottomLeading(veiwMode: $veiwMode)
            }
                        
            if isShowLoninAlert {
                LoginAlert(isShow: $isShowLoninAlert, idString: $idString, passWradString: $passWradString)
            }
            
            if isSaveAlert {
                SaveAlert(isShow: $isSaveAlert, fileNameString: $fileNameString, photoStatus: $photoStatus, myTimer:myTimer)
            }
        }
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        BaseView(veiwMode: .constant(0) , photoStatus: .constant(0))
            .previewDevice("iPad Pro (11-inch)")
            .previewInterfaceOrientation(.landscapeRight)
    }
}

//-------------------------------------------------
// TopLeadingView // 左上 状態
//-------------------------------------------------
//
struct TopLeadingView: View {
    @Binding var veiwMode: Int

    var body: some View {
        HStack {
            Image("sensitivity")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 40)
            
            Image("remaining")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 120)
        }
    }
}

//-------------------------------------------------
// TopTrailingView // 右上　設定
//-------------------------------------------------
struct TopTrailingView: View {
    @Binding var veiwMode: Int
    @Binding var photoStatus: Int
    @Binding var isShowLoninAlert: Bool
    @Binding var isSaveAlert: Bool
    
    @ObservedObject var myTimer: MyTimer
    
    @State private var isAbortAlert = false

    var body: some View {
        VStack (spacing: 10){
            // 上から１つ目
            Button(action: {    // ログイン
                self.isShowLoninAlert.toggle()
            }) {
                Image("login")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80)
            }

            // 上から２つ目
            Button(action: {    // プロジェクト
                veiwMode = 2
            }) {
                Image("project")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80)
            }
            
            // 上から３つ目　（撮影中止ボタン）
            if(photoStatus != 0) {
                //　撮影準備中以外ならば
                Button(action: {    // 撮影中止
                    self.isAbortAlert = true
                    self.myTimer.pause()
                }) {
                    Image("cancel")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80)
                }
                    .alert("撮影の中断", isPresented: $isAbortAlert) {
                        Button("戻る") {      // Back
                             // 戻るボタンが押された時の処理
                            self.myTimer.restart(intervalTime: 1.0)
                        }
                        Button("中断") {     // Abort
                            // 中断ボタンが押された時の処理
                            photoStatus = 0
                            self.myTimer.stop()
                        }
                    } message: {
                        Text("中断するとデータは失われます。中断しますか？")
                    }
            } else {
                //撮影準備中ならば表示しない
                Text("")
                    .frame(width: 100, height: 80)
            }
            
            // 上から４つ目　（撮影開始ボタン」）
            if(photoStatus == 1){    // 撮影中
                // 撮影中ならば
                Button(action: {    // 一時停止
                    photoStatus = 2
                    self.myTimer.pause()
                }) {
                    Image("pause")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80)
                }
            } else if(photoStatus == 2){
                // 一時停止中ならば
                Button(action: {    // 撮影再開
                    photoStatus = 1
                    self.myTimer.restart(intervalTime: 1.0)
                }) {
                    Image("restart")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80)
                }
            } else { // if(photoStatus == 0)
                // 撮影準備中ならば
                Button(action: {    // 撮影開始
                    photoStatus = 1
                    self.myTimer.start(intervalTime: 1.0)
                }) {
                    Image("photo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80)
                }
            }

            // 上から５つ目　（完了・保存ボタン）
            if(photoStatus != 0) {      // 撮影中
                    Button(action: {    // 完了・保存
            //            self.myTimer.pause()
                        self.myTimer.stop()
                        self.isSaveAlert = true
                    }) {
                        Image("completion")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80)
                    }
            }
        }
    }
}
    
//-------------------------------------------------
// BottomTrailingView // 右下　設定
//-------------------------------------------------
struct BottomTrailingView: View {
    @Binding var veiwMode: Int

    var body: some View {
        Button(action: {    // 設定
            veiwMode = 3
        }) {
            Image("seting")
                .resizable()
                .scaledToFit()
                .frame(width: 80)
        }
    }
}

//-------------------------------------------------
// BottomLeading // 左下
//-------------------------------------------------
struct BottomLeading: View {
    @Binding var veiwMode: Int

    var body: some View {
        TengunPreview(veiwMode: $veiwMode)
    }
}

///--------------------------------------------------
/// MyTimer クラス
///---------------------------------------------------
class MyTimer:ObservableObject{
    
    enum stopWatchMode{
        case start
        case stop
        case pause
    }
    
    // 変化する変数には @Published をつける
    @Published var mode:stopWatchMode = .stop
    @Published var secondsElapsed = 0.00
    @Published var num: Int = 0

    var timer = Timer()
    
    func start(intervalTime: Float){
        print("--- Timer start ---")
        mode = .start
        self.secondsElapsed = 0.0
        self.num = 0
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalTime), repeats: true){ timer in
            self.secondsElapsed += Double(intervalTime)
            self.num = self.num + 1
            print("num : \(self.num)")
        }
    }
    
    func stop(){
        print("--- Timer stop ---")
        timer.invalidate()
        mode = .stop
    }
    
    func pause(){
        print("--- Timer pause ---")
        timer.invalidate()
        mode = .pause
    }
    
    func restart(intervalTime: Float){
        print("--- Timer restart ---")
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalTime), repeats: true){ timer in
            self.secondsElapsed += Double(intervalTime)
            self.num = self.num + 1
            print("num : \(self.num)")
        }
            self.mode = .start
    }

    
    func clear(){
        print("--- Timer clear ---")
        self.secondsElapsed = 0.0
        self.num = 0
    }
}

