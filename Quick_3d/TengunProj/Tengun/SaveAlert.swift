//
//  SaveAlert.swift
//  Tengun
//
//  Created by 木皿直規 on 2022/02/15.
//

import SwiftUI

//-------------------------------------------------
// SaveAlert ログイン画面
//-------------------------------------------------
struct SaveAlert: View {
    
    @Binding var isShow: Bool
    @Binding var fileNameString: String
    @Binding var photoStatus: Int
    @ObservedObject var myTimer: MyTimer
    
    @State private var isCompletionSave = false
    @FocusState private var fieldIsForcused: Bool   // フォーカス状態プロパティ

    var body: some View {
            ZStack() {
                    Rectangle()
                        .foregroundColor(.white)
                
                    VStack (spacing: 25) {
                        Text("保存")
                        
                        TextField("プロジェクト名",text: $fileNameString)
                            .onAppear { fieldIsForcused = true}
                            .focused($fieldIsForcused)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerSize:CGSize(width:4.0, height:4.0))
                                    .stroke(Color.black, lineWidth:1.0)
                                    .padding(3.0)
                            )
                        
                        HStack {
                            Button("キャンセル") {
                                self.isShow.toggle()
                                self.myTimer.stop()
                                photoStatus = 0
                            }
                                .frame(width: 100, height: 30, alignment: .center)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.black, lineWidth: 1)
                                )
                            
                            Button("保存") {
                                self.isShow.toggle()
                                self.isCompletionSave = true
                                photoStatus = 0
                                self.myTimer.stop()
                            }
                                .frame(width: 100, height: 30, alignment: .center)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.black, lineWidth: 1)
                                )
                                .alert(isPresented: $isCompletionSave) {
                                    Alert(title: Text("撮影完了・保存しました。"))
                                }
                          }
                    }.padding()
            }
                .frame(width: 400, height: 250, alignment: .center)
                .cornerRadius(20)
                .shadow(radius: 20)
    }
}

/*
struct SaveAlert_Previews: PreviewProvider {
    let str = "abc@xyz.com"

    static var previews: some View {
    SaveAlert(isShow: .constant(0 != 0), idString: $str)
            .previewDevice("iPad Pro (11-inch)")
            .previewInterfaceOrientation(.landscapeRight)
    }
}
*/

