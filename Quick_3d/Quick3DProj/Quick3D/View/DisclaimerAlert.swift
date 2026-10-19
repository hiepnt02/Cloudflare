//
//  DisclaimerAlert.swift
// 　免責事項アラート
//  Quick3D
//
//  Created by 木皿直規 on 2022/04/25.
//

import SwiftUI

//-------------------------------------------------
// DisclaimerAlert 免責事項アラート
//-------------------------------------------------
struct DisclaimerAlert: View {
    @Binding var isShow: Bool
    @EnvironmentObject var userManager: UserManager

    @State var textString = ""
    private var buttonName: String{
        UserDefaults.standard.bool(forKey: "didDisclaimerKey") ? "CLOSE" : "AGREE"
    }
    @State private var isIPhone: Bool = (UIDevice.current.userInterfaceIdiom == .phone) ? true : false

    var body: some View {
        ZStack() {
            Rectangle()
//                .foregroundColor(.black)
                .foregroundColor(userManager.setting.themeColor)

            VStack () {
                ZStack () {
                    Text("TERMS_OF_SERVICE".localized(userManager.userLanguage))
                        .fontWeight(.bold)
                        .font(isIPhone ? .title2 : .largeTitle)
//                        .foregroundColor(.white)
                        .foregroundColor(userManager.setting.textColor)

                }
                
                ScrollView {
                    Text(textString)
                        .padding()
//                        .foregroundColor(.white)
                        .foregroundColor(userManager.setting.textColor)
                        .font(isIPhone ? .caption : .body)
                }
//                .border(.white, width: 1)
                .border(userManager.setting.textColor, width: 1)
//                .background(.black)
                .background(userManager.setting.themeColor)

               Spacer()

                HStack {
                    Spacer()

                    Button(action: {
                        UserDefaults.standard.set(true, forKey: "didDisclaimerKey")
                        self.isShow.toggle()
                    } ) {
                        Text(buttonName.localized(userManager.userLanguage))
                            .foregroundColor(Color.white)
                            .padding()
                    }
                        .frame(width: 125, height: 25)
//                        .background(Color.blue)
                        .background(userManager.setting.buttonColor)

                }
            }
                .padding()
        }
            .cornerRadius(20)
            .onAppear {
                loadDisclaimer(language: userManager.userLanguage)
            }
    }

    func loadDisclaimer(language: String)
    {
        print("--- TextFileLoad ---")

        guard let fileURL = Bundle.main.url(forResource: language == "ja" ? "disclaimer" : "term_of_use_en", withExtension: "txt"),
              let fileContents = try? String(contentsOf: fileURL, encoding: .utf8) else {
                  fatalError("読み込み出来ません")
              }

        textString = fileContents
    }
}
