//
//  ContentView.swift
//  Tengun
//
//  Created by 木皿直規 on 2022/02/08.
//

import SwiftUI

struct ContentView: View {
    
    var initialSet = InitialSet()
    
    @State var mVeiwMode: Int = 0   // 0:カメラ 1:ログイン 2:プロジェクト 3:設定 4:点群
    @State var mPhotoStatus: Int = 0    // 0:準備（停止）中 1:撮影中　2:一時停止中
    @State var recordingStatus: RecordingStatus = .ready

    var body: some View {
        
            switch mVeiwMode {
            case 2:
                // プロジェクト画面
                ProjectView(veiwMode: $mVeiwMode)
            case 3:
                // 設定画面
                SettingView(veiwMode: $mVeiwMode)
            case 4:
                // 点群画面
                TeggunView(veiwMode: $mVeiwMode)
            default:    // mVeiwMode == 0
                // カメラ画面
                BaseView(veiwMode: $mVeiwMode, photoStatus: $mPhotoStatus)
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPad Pro (11-inch)")
            .previewInterfaceOrientation(.landscapeRight)
    }
}

///--------------------------------------------------
/// InitialSet クラス UserDefaultsの初期値設定
///---------------------------------------------------
class InitialSet:NSObject, ObservableObject{
    //--------------------------------------------------------
    // init　初期化
    //--------------------------------------------------------
    override init()
    {
        super.init()
        
        print("--- InitialSet ---")
        
        //　全データを一括削除
//        let appDomain = Bundle.main.bundleIdentifier
//        UserDefaults.standard.removePersistentDomain(forName: appDomain!)
        // １つのものだけ削除
//        UserDefaults.standard.removeObject(forKey: "キー")
        
        let firstRun: Bool? = UserDefaults.standard.bool(forKey: "firstRun")
        let isFirstRun = firstRun ?? false
//        print(isFirstRun)
        if(isFirstRun == false) {
            UserDefaults.standard.set(true, forKey: "firstRun")
            
            UserDefaults.standard.set("https://fast.com/ja/", forKey: "URLStr")
        }

        // 現在のUserDefaultsの表示
        let URLStr: String? = UserDefaults.standard.string(forKey: "URLStr")
        print("URLStr：" + (URLStr ?? "nil"))
    }
}
