//
//  ButtonSelectFile.swift
//  Quick3D
//
//  Created by HungNT on 6/8/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ButtonSelectFile: View {
    @EnvironmentObject var userManager: UserManager
    
    var buttonText: String?
    var fileTypes: [UTType]
    var isHideFileName: Bool = false
    var callback: (
        URL?,   // Url of file selected
        String? // Name of file selected with extension. Ex: "memo.zip"
    ) -> Void
    
    @State private var isShowDocumentPicker = false
    @State private var selectedFileName: String = ""
    @State private var selectedFileSize: String = ""
    
    private let btnWidth: CGFloat = 150
    private let btnHeight: CGFloat = UserSession.isIPhone ? 35 : 45
    private let textMinHeight: CGFloat = UserSession.isIPhone ? 20 : 30
    
    var body: some View {
        HStack {
            Button(action: {
                isShowDocumentPicker = true
            }) {
                Text(buttonText ?? "SELECT_FILE".localized(userManager.userLanguage))
                    .foregroundColor(.white)
                    .font(UserSession.isIPhone ? .body : .title3)
                    .frame(
                        width: btnWidth,
                        height: btnHeight,
                        alignment: .center
                    )
            }
            .background(.blue)
            .fullScreenCover(isPresented: $isShowDocumentPicker) {
                DocumentPicker(selectTypes: fileTypes) { fileUrl, fileName in
                    callback(fileUrl, fileName)
                    selectedFileName = fileName ?? ""
                    selectedFileSize = (fileUrl?.fileSize ?? 0).bytesToHumanReadable()
                }
            }
            
            if !isHideFileName && !selectedFileName.isEmpty {
                FileInfoView(
                    fileName: $selectedFileName,
                    fileSize: $selectedFileSize
                )
                .environmentObject(userManager)
            }
        }
    }
}
