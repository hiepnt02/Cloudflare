//
//  ARListPopup.swift
//  Quick3D
//
//  Created by ryoma.terai on 2024/09/26.
//

import Foundation
import SwiftUI

struct ARListPopup: View{
    @Binding var show: Bool
    var cat: Cat?
    @State private var isIPhone = UIDevice.current.isIphone
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var productData: ProductData
    @State private var isLoding: Bool = false
    @State var isShowConfirmDelete: Bool = false
    @State private var outputType: String = ""

    var body: some View {
        ZStack {
            if show {
                Color(userManager.setting.colorTheme == .light ? .black : .white)
                    .opacity(show ? 0.3 : 0)
                    .edgesIgnoringSafeArea(.all)
                
                // PopUp background color
                Button(action: {}, label: {
                    Color(userManager.setting.colorTheme == .light ? .black : .white)
                        .colorInvert()
                        .opacity(0)
                        .edgesIgnoringSafeArea(.all)
                    
                })

                // PopUp Window
                VStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .center, spacing: 0) {
                        HStack() {
                            Text("DETAIL_INFO".localized(userManager.userLanguage))
                                .foregroundColor(userManager.setting.textColor)
                                .font(.title2.bold())
                            
                            Spacer()

                            Button(action: {
                                show = false
                            }, label: {
                                Image(systemName: "xmark")
                                    .foregroundColor(userManager.setting.textColor)
                            })
                        }
                        .padding(.top, isIPhone ? 20: 30)
                        .padding(.bottom, 10)
                        
                        Divider()
                            .frame(height: 2)
                            .background(userManager.setting.textColor)
                            .padding(.bottom, isIPhone ? 10 : 20)
                    }
                    .padding(.horizontal, isIPhone ? 20 : 30)
                    
                    GeometryReader { geometry in
                        ScrollView(.vertical) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("【"+("COORDINATE_SYSTEM".localized(userManager.userLanguage))+"】")
                                    .frame(maxWidth: .infinity, alignment: .leading) // 幅を最大にして左寄せ
                                    .frame(height: 30)
                                
                                HStack(spacing: 0) {
                                    Text("COORDINATE_SYSTEM".localized(userManager.userLanguage))
                                        .foregroundColor(userManager.setting.textColor)
                                        .frame(width: geometry.size.width * 0.2 - (isIPhone ? 20 : 30), alignment: .leading)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("：")
                                        .foregroundColor(userManager.setting.textColor)
                                        .frame(width: geometry.size.width * 0.1, alignment: .leading)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text(CoordinateManager.shared.getHCoordinateLabel(coordinateKey: cat?.horizontal) ?? "NONE".localized(userManager.userLanguage))
                                        .foregroundColor(userManager.setting.textColor)
                                        .frame(width: geometry.size.width * 0.7 - (isIPhone ? 20 : 30), alignment: .leading)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Spacer()
                                    .frame(height: 10)
                                
                                HStack(spacing: 0) {
                                    Text("VERTICAL_COORDINATE_SYSTEM".localized(userManager.userLanguage))
                                        .foregroundColor(userManager.setting.textColor)
                                        .frame(width: geometry.size.width * 0.2 - (isIPhone ? 20 : 30), alignment: .leading)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("：")
                                        .foregroundColor(userManager.setting.textColor)
                                        .frame(width: geometry.size.width * 0.1, alignment: .leading)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(CoordinateManager.shared.getVCoordinateLabel(coordinateKey: cat?.vertical) ?? "NONE".localized(userManager.userLanguage))
                                        .foregroundColor(userManager.setting.textColor)
                                        .frame(width: geometry.size.width * 0.7 - (isIPhone ? 20 : 30), alignment: .leading)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
      
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Spacer()
                                    .frame(height: 20)
                                
                                Text("【"+("AR_FILE_LIST".localized(userManager.userLanguage))+"】")
                                    .foregroundColor(userManager.setting.textColor)
                                    .frame(maxWidth: .infinity, alignment: .leading) // 幅を最大にして左寄せ
                                    .frame(height: 30)
                                
                                HStack(spacing: 0) {
                                    Text("POINT_DATA".localized(userManager.userLanguage))
                                        .foregroundColor(userManager.setting.textColor)
                                        .frame(width: geometry.size.width * 0.2, alignment: .leading)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("：")
                                        .foregroundColor(userManager.setting.textColor)
                                        .frame(width: geometry.size.width * 0.1, alignment: .leading)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(cat?.las_file?.removingPercentEncoding ?? "")
                                        .foregroundColor(userManager.setting.textColor)
                                        .frame(width: geometry.size.width * 0.5 - (isIPhone ? 20 : 30), alignment: .leading)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Button(action: {
                                        outputType = "point_cloud"
                                        isShowConfirmDelete = true
                                    }
                                           , label: {
                                        Text("REMOVE".localized(userManager.userLanguage))
                                            .font(isIPhone ? .headline.bold() : .title3.bold())
                                            .lineLimit(1)
                                            .foregroundColor(.white)
                                            .frame(minHeight: isIPhone ? 30 : 45, alignment: .center)
                                            .frame(minWidth: 0, maxWidth: .infinity)
                                            .contentShape(Rectangle())
                                    })
                                    .frame(width: 70)
                                    .background(userManager.setting.deleteButtonColor)
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(cat?.las_file == nil || isLoding || (cat?.statusList?.isARProcessing ?? false))
                                    .cornerRadius(10)
                                    .frame(width: geometry.size.width * 0.2 - (isIPhone ? 20 : 30), alignment: .trailing)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Spacer()
                                    .frame(height: 10)
                                
                                HStack(spacing: 0) {
                                    Text("DESIGN_DATA".localized(userManager.userLanguage))
                                        .foregroundColor(userManager.setting.textColor)
                                        .frame(width: geometry.size.width * 0.2, alignment: .leading)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("：")
                                        .foregroundColor(userManager.setting.textColor)
                                        .frame(width: geometry.size.width * 0.1, alignment: .leading)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(cat?.design_file?.removingPercentEncoding ?? "")
                                        .foregroundColor(userManager.setting.textColor)
                                        .frame(width: geometry.size.width * 0.5 - (isIPhone ? 20 : 30), alignment: .leading)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Button(action: {
                                        outputType = "ifc"
                                        isShowConfirmDelete = true
                                    }
                                           , label: {
                                        Text("REMOVE".localized(userManager.userLanguage))
                                            .font(isIPhone ? .headline.bold() : .title3.bold())
                                            .lineLimit(1)
                                            .foregroundColor(.white)
                                            .frame(height: isIPhone ? 30 : 45, alignment: .center)
                                            .frame(minWidth: 0, maxWidth: .infinity)
                                            .contentShape(Rectangle())
                                    })
                                    .frame(width: 70)
                                    .background(userManager.setting.deleteButtonColor)
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(cat?.design_file == nil || isLoding || (cat?.statusList?.isARProcessing ?? false))
                                    .cornerRadius(10)
                                    .frame(width: geometry.size.width * 0.2 - (isIPhone ? 20 : 30), height: 30, alignment: .trailing)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, isIPhone ? 20 : 30)
                            .padding(.bottom,  isIPhone ? 20 : 30)
                        }
                    }
                }
                .background(userManager.setting.themeColor)
                .frame(width: isIPhone ? 500 : 700, height: isIPhone ? 400 : 600)
                .border(.gray, width: 1)
                .ignoresSafeArea()
                
                if isShowConfirmDelete {
                    ConfirmDeletePopup(
                        show: $isShowConfirmDelete,
                        alertMessage: "MESSAGE_CONFIRM_DELETE_FILE".localized(userManager.userLanguage)
                    ) {
                        deleteAction(output_type: outputType)
                    }
                }
            }
        }
    }
}

extension ARListPopup {
    private func deleteAction(output_type:String){
        isLoding = true
        Task {
            do {
                let result = try? await productData.deleteARFile(projectId: cat?.projectId ?? "", output_type: output_type)
                
                if let success = result, success {
                    try await productData.fetchProjectList(status: productData.currentSelectStatus, searchStr: productData.currentSearchStr, fromDate: nil, toDate: nil,site:nil, isRemoved: false, rtkFilterMode: 2)
                } else {
                    print("ファイルの削除に失敗しました")
                }
            } catch {
                print("エラーが発生しました: \(error)")
            }
            withAnimation(.linear(duration: 0.3)) {
                show = false
                self.presentationMode.wrappedValue.dismiss()
            }
            isLoding = false
        }
    }
}

