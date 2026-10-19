//
//  PointUploadPopup.swift
//  Quick3D
//
//  Created by ryoma.terai on 2024/09/12.
//

import SwiftUI
import UIKit
import MobileCoreServices

struct ARUploadPopup: View {
    @EnvironmentObject var productData: ProductData
    @EnvironmentObject var userManager: UserManager
    
    @Binding var isShow: Bool
    @Binding var cat: Cat?
    @Binding var projectName: String
    @Binding var jobsite: JobSite.Site?
    @Binding var isShowGroupware: Bool
    @Binding var groupwareSelected: GroupwareModel?
    @Binding var groupwareTypeSelected: GroupwareType
    @Binding var selectedFileURL: URL?
    @Binding var disableButtonUpload: Bool
    
    @State var ar_color: Color
    
    var handler: (String, Bool, Cat?, URL?, String, String) -> Void
    var onUploadGroupware: (
        Cat,
        String, // JobsiteId
        GroupwareModel,
        String // AR Color
    ) -> Void
    
    @State private var useARMarker = false
    @State private var isKeyboardShow = false
    
    @State private var isShowDocumentPicker = false
    
    @State private var selectedFileName: String = ""
    @State private var selectedFileSize: String = ""
    
    @State private var isShowSelectColor: Bool = false
    
    @State var updateColor: String? = nil
    
    private let iconSize: CGFloat = UserSession.isIPhone ? 35 : 45
    
    var body: some View {
        contentView.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) {_ in
            // Bool変数を変更
            isKeyboardShow = true
        }.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) {_ in
            // Bool変数を変更
            isKeyboardShow = false
        }
    }
    
    private var contentView: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("UPLOAD_FROM_LOCAL_OR_FROM_GROUPWARE".localized(userManager.userLanguage))
                    .lineLimit(2)
                    .foregroundColor(userManager.setting.textColor)
                    .frame(minHeight: UserSession.isIPhone ? 20 : 30, alignment: .leading)
                    .font(.body)
                    .padding(.bottom, 10)
                
                HStack {
                    ButtonSelectFile(
                        buttonText: nil,
                        fileTypes: cat!.statusList!.getIsAR ?
                        [
                            FileTypes[FileType.las]!,
                            FileTypes[FileType.ifc]!,
                            FileTypes[FileType.xml]!
                        ]
                        : [
                            FileTypes[FileType.ifc]!,
                            FileTypes[FileType.xml]!
                        ],
                        isHideFileName: true
                    ) { fileUrl, fileName in
                        selectedFileURL = fileUrl
                        selectedFileName = fileName ?? ""
                        selectedFileSize = (fileUrl?.fileSize ?? 0).bytesToHumanReadable()
                        groupwareSelected = nil
                        
                        checkShowSelectColor()
                    }
                    .padding(.leading, UserSession.isIPhone ? 10 : 20)
                    
                    Button {
                        groupwareTypeSelected = GroupwareType.dashboard
                        isShowGroupware = true
                    } label: {
                        Image("icDashboard")
                            .resizable()
                    }
                    .frame(
                        width: iconSize,
                        height: iconSize
                    )
                    .padding(.leading, UserSession.isIPhone ? 5 : 10)
                    
                    Button {
                        groupwareTypeSelected = GroupwareType.design
                        isShowGroupware = true
                    } label: {
                        Image("icDesign3D")
                            .resizable()
                    }
                    .frame(
                        width: iconSize,
                        height: iconSize
                    )
                    .padding(.leading, UserSession.isIPhone ? 5 : 10)
                    
                    if !selectedFileName.isEmpty {
                        FileInfoView(
                            fileName: $selectedFileName,
                            fileSize: $selectedFileSize
                        )
                        .environmentObject(userManager)
                    }
                }
                .padding(.bottom, UserSession.isIPhone ? 20 : 30)
                
                if isShowSelectColor {
                    selectColorView()
                }
                
                bottomButtonsView()
            }
            .onChange(of: groupwareSelected) { newGroupware in
                if groupwareSelected != nil {
                    selectedFileName = groupwareSelected?.name ?? ""
                    selectedFileSize = Int(groupwareSelected?.size ?? "0")?.bytesToHumanReadable() ?? ""
                    selectedFileURL = nil
                }
                checkShowSelectColor()
            }
        }
    }
    
    private func checkShowSelectColor() {
        let isXMLFile = selectedFileURL?.pathExtension == "xml"
        let isXMLGroupware = groupwareSelected?.name.split(separator: ".")[1] == "xml"
        isShowSelectColor = isXMLFile || isXMLGroupware
    }
    
    private func selectColorView() -> some View {
        HStack {
            ColorPicker("AR_DATA_COLOR".localized(userManager.userLanguage), selection: $ar_color)
                .lineLimit(2)
                .foregroundColor(userManager.setting.textColor)
                .frame(minHeight: UserSession.isIPhone ? 20 : 30, alignment: .leading)
                .font(.body)
                .padding(.bottom, UserSession.isIPhone ? 10 : 20)
                .onChange(of: ar_color)
                { newColor in
                    if let hexString = ar_color.toHexString() {
                        updateColor = hexString
                    }
                }
        }
        .padding(.bottom, UserSession.isIPhone ? 10 : 20)
    }
    
    private func bottomButtonsView() -> some View {
        HStack(spacing: 20) {
            Button(action: {
                withAnimation(.linear(duration: 0.3)) {
                    isShow = false
                    projectName = ""
                    groupwareSelected = nil
                    productData.lishDashboard = []
                    productData.listDesign = []
                }
            }, label: {
                Text("CANCEL".localized(userManager.userLanguage))
                    .font(UserSession.isIPhone ? .headline.bold() : .title3.bold())
                    .foregroundColor(userManager.setting.textColor)
                    .frame(height: UserSession.isIPhone ? 40 : 55, alignment: .center)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .contentShape(Rectangle())
            })
            .background(userManager.setting.themeColor)
            .buttonStyle(PlainButtonStyle())
            .border(userManager.setting.textColor, width: 1)
            
            Button(
                action: handleUpload,
                label: {
                Text("UPLOAD".localized(userManager.userLanguage))
                    .font(UserSession.isIPhone ? .headline.bold() : .title3.bold())
                    .foregroundColor(.white)
                    .frame(height: UserSession.isIPhone ? 40 : 55, alignment: .center)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
            )
            .background(.blue)
            .buttonStyle(PlainButtonStyle())
            .disabled(disableButtonUpload && selectedFileURL == nil && groupwareSelected == nil)
        }
        .padding(.top, 10)
        .padding(.bottom, UserSession.isIPhone ? 10 : 20)
    }
}

extension ARUploadPopup {
    private func handleUpload() {
        // Validate data
        guard var cat = cat else { return }
        guard !projectName.isEmpty else { return }
        guard let jobsite = jobsite else { return }
        disableButtonUpload = true
        
        // Validate project name
        guard ProductUtil.validationCheck(projectName) else {
            APAlert.shared.showAlert(
                title: "",
                message: "PROHIBITED_CHARACTER_MESSAGE".localized(userManager.userLanguage),
                buttonTitle: "CLOSE".localized(userManager.userLanguage)
            )
            disableButtonUpload = false
            return
        }
        
        // Get new AR Color
        let newARColor = updateColor ?? cat.ar_color ?? "#50E3C2"
        if(updateColor != nil){
            cat.ar_color = updateColor
        }
        
        // Upload file in case user selected from Groupware
        if let groupwareSelected = groupwareSelected {
            onUploadGroupware(cat, jobsite.id, groupwareSelected, newARColor)
            resetDataAndClosePopup()
        } else {
            // Upload file in case use selected from local storage
            cat.title = projectName
            cat.jobsiteId = jobsite.id
            
            guard let fileExtension = selectedFileURL?.pathExtension else {
                return
            }
            if(fileExtension == "las"){
                cat.las_file = selectedFileName
            }
            else if(fileExtension == "xml" || fileExtension == "ifc"){
                cat.ifc_file = selectedFileName
            }
            handler(jobsite.id, useARMarker, cat, selectedFileURL, selectedFileName, newARColor)
            resetDataAndClosePopup()
        }
    }
    
    private func resetDataAndClosePopup() {
        projectName = ""
        selectedFileURL = nil
        selectedFileName = ""
        selectedFileSize = ""
        
        groupwareSelected = nil
        productData.lishDashboard = []
        productData.listDesign = []
        
        disableButtonUpload = false
        isShow = false
    }
}
