//
//  LoginView.swift
//  Tengun
//
//  Created by 木皿直規 on 2022/02/15.
//

import SwiftUI

//-------------------------------------------------
// LoginAlert ログイン画面
//-------------------------------------------------
struct LoginAlert: View {
    
    @Binding var isShow: Bool
    @Binding var idString: String
    @Binding var passWradString: String

    @FocusState private var fieldIsForcused: Bool   // フォーカス状態プロパティ

    var body: some View {
            ZStack() {
                    Rectangle()
                        .foregroundColor(.white)
                
                    VStack (spacing: 25) {
                        Text("ログイン")
                        TextField("ID",text: $idString)
                            .onAppear { fieldIsForcused = true}
                            .padding()
                            .focused($fieldIsForcused)
                            .overlay(
                                RoundedRectangle(cornerSize:CGSize(width:4.0, height:4.0))
                                    .stroke(Color.black, lineWidth:1.0)
                                    .padding(3.0)
                            )

                        TextField("パスワード", text: $passWradString)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerSize:CGSize(width:4.0, height:4.0))
                                    .stroke(Color.black, lineWidth:1.0)
                                    .padding(3.0)
                            )
                        
                        HStack {
                            Button("ログイン") {
                                self.isShow.toggle()
                            }
                                .frame(width: 100, height: 30, alignment: .center)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.black, lineWidth: 1)
                                )
                        }
                    }.padding()
            }
                .frame(width: 400, height: 250, alignment: .center)
                .cornerRadius(20)
                .shadow(radius: 20)
    }
}

/*
struct LoginAlert_Previews: PreviewProvider {
    let str = "abc@xyz.com"

    static var previews: some View {
        LoginAlert(isShow: .constant(0 != 0), idString: $str)
            .previewDevice("iPad Pro (11-inch)")
            .previewInterfaceOrientation(.landscapeRight)
    }
}
*/

