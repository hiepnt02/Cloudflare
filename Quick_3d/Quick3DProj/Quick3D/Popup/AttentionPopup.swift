

//
//  Quick3D
//
//  Created by Pham Thanh Xuan on 11/09/2022.
//

import SwiftUI
import Alamofire

struct AttentionPopup: View {
    
    @EnvironmentObject var userManager: UserManager
    
    private var isIPhone: Bool {
        UIDevice.current.isIphone
    }
    
    @Binding var show: Bool
    @Binding var isCrate: Bool
    
    var body: some View {
        ZStack {
            if show {
                Color(userManager.setting.colorTheme ==
                    .light ? .black : .white)
                .opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                
                ScrollView(showsIndicators: false) {
                    contentView.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) {_ in
                    }.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) {_ in
                    }
                }
                .frame(maxHeight: UIScreen.main.bounds.height)
                .frame(height: isIPhone ? 350 : 500)
            }
        }
    }
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack{
                HStack {
                    Spacer()
                    Button(action: {
                        show = false
                    }, label: {
                        Image(systemName: "xmark")
                            .foregroundColor(userManager.setting.textColor)
                    })
                    .tag(1)
                }
                .padding(EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0))
                
                
                HStack {
                    Image("attention")
                        .renderingMode(.template)
                        .resizable()
                        .foregroundColor(.yellow)
                        .frame(width: 60, height: 60)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 10))
                    VStack {
                        Text("UPLOADING_WATING_ALERT_1".localized(userManager.userLanguage))
                            .foregroundColor(userManager.setting.textColor)
                            .font(.title2)
                            .padding(EdgeInsets(top: 5, leading: 20, bottom: 10, trailing: 0))
                        if isCrate {
                            Text("UPLOADING_WATING_ALERT_2".localized(userManager.userLanguage))
                                .foregroundColor(userManager.setting.textColor)
                                .font(.title2)
                                .padding(EdgeInsets(top: 5, leading: 20, bottom: 0, trailing: 0))
                        }
                    }
                }
            }
            .frame(width: isIPhone ? 500 : 600)
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
            .background(userManager.setting.themeColor)
            .border(.gray, width: 1)
        }
    }
    
}

