//
//  ZipUploadPopup.swift
//  Quick3D
//
//  Created by ryoma.terai on 2024/09/12.
//

import SwiftUI
import UIKit
import MobileCoreServices
import UniformTypeIdentifiers
import ZIPFoundation

struct BaseUploadPopup: View {
    @State private var isPopupPresented: Bool = false
    
    @Binding var show: Bool
    @Binding var cat: Cat?
    @EnvironmentObject var productData: ProductData
    @EnvironmentObject var userManager: UserManager
    
    @Binding var projectName: String
    @Binding var jobsite: JobSite.Site?
    @Binding var isCurrentAR: Bool
    
    @Binding var isShowGroupware: Bool
    @Binding var groupwareSelected: GroupwareModel?
    @Binding var groupwareTypeSelected: GroupwareType
    @Binding var dataTypeSelected: UploadCase
    
    var handler: (String, Bool, Cat?, URL?, String, Bool, Bool, Bool, Bool,String?) -> Void
    var onUploadGroupware: (
        Cat,
        String, // JobsiteId
        GroupwareModel,
        String // AR Color
    ) -> Void
    
    @State var isShowJobSiteView: Bool = false
    @State private var isIPhone = UIDevice.current.isIphone
    @State private var useARMarker = false
    @State private var isKeyboardShow = false;
    @State private var coordinateSetting: Bool = false;
    @State private var linkDashboard: Bool = false;
    @State private var shouldInterpolate: Bool = true;
    
    @State private var addvancedSettingIsExpanded = false;
    
    @State private var linkTipIsShown = false;
    @State private var uploadTipIsShown = false;
    @State private var interpolateTipIsShown = false;
    
    @State private var anyDetailIsShown = false;
    
    @FocusState private var focusState: Bool
    
    @State private var isShowDocumentPicker = false
    @State private var selectedFileURL: URL?
    @State private var selectedFileName: String? = ""
    
    @State private var tifFileURL: URL?
    @State private var xmlFileURL: URL?
    @State private var jsonFileUrl: URL?
    
    @State private var isValidUploadTif: Bool = false
    @State private var isValidUploadGeo: Bool = false
    @State private var disableButtonUpload: Bool = true
    
    struct DataType: Hashable{
        let type: UploadCase
        let label: String
    }
    
    func hideDetails() {
        self.anyDetailIsShown = false;
        self.linkTipIsShown = false;
        self.uploadTipIsShown = false;
        self.interpolateTipIsShown = false;
    }
    
    func customPopover(isShown: Binding<Bool>, content: String, frameValue: (width: CGFloat, height: CGFloat), offsetValue: (x: CGFloat, y: CGFloat)) -> some View{
        Button(
            action: {
                if isShown.wrappedValue {
                    hideDetails();
                }
                else{
                    hideDetails();
                    self.anyDetailIsShown = true;
                    isShown.wrappedValue = true;
                }
            },
            label: {
                let questionIcon = "";
                Text(questionIcon)
                    .foregroundColor(userManager.setting.textColor)
                    .font(.custom(CustomFonts.FAFreeSolid, size: 20))
                    .fixedSize(horizontal: false, vertical: true)
                    .dynamicTypeSize(DynamicTypeSize.medium)
                    .frame(width: 30, height: 30)
                    .padding(.trailing, 20)
            }
        )
        .overlay(
            isShown.wrappedValue ?
            Text(content)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: frameValue.width, height: frameValue.height)
                .padding(.all, 5)
                .background(userManager.setting.themeColor, in: Rectangle(), fillStyle: FillStyle(eoFill: true))
                .foregroundColor(userManager.setting.textColor)
                .border(Color.gray, width: 1)
                .font(.caption.bold())
                .dynamicTypeSize(DynamicTypeSize.medium)
                .offset(x: offsetValue.x, y: offsetValue.y)
                .onTapGesture {}
            :
                nil
        )
    }
    
    var body: some View {
        ZStack {
            if show {
                // PopUp background color
                Color(.black)
                    .colorInvert()
                    .opacity(show ? 0.3 : 0)
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView(showsIndicators: false) {
                    contentView.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) {_ in
                        // Bool変数を変更
                        isKeyboardShow = true
                    }.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) {_ in
                        // Bool変数を変更
                        isKeyboardShow = false
                    }
                }
                .frame(width: UIScreen.main.bounds.width * 0.70,
                       height: UIScreen.main.bounds.height * (isKeyboardShow ? 0.55 : 0.80))
            }
        }
        .onTapGesture {
            // Do nothing but help prevent action touch out of popup
        }
    }
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("UPLOAD_DATA_FOR_AR".localized(userManager.userLanguage))
                    .foregroundColor(userManager.setting.textColor)
                    .font(.title2.bold())
                
                Spacer()
                
                Button(action: {
                    show = false
                    projectName = ""
                    groupwareSelected = nil
                    productData.lishDashboard = []
                    productData.listDesign = []
                    isPopupPresented = false
                }, label: {
                    Image(systemName: "xmark")
                        .foregroundColor(userManager.setting.textColor)
                    
                })
            }
            .padding(.top, isIPhone ? 20: 30)
            .padding(.bottom, 10)
            
            Divider()
                .frame(height: 2)
                .background(userManager.setting.themeColor)
                .padding(.bottom, isIPhone ? 10 : 20)
            
            
            Text("DATA_TYPE".localized(userManager.userLanguage))
                .lineLimit(2)
                .foregroundColor(userManager.setting.textColor)
                .frame(minHeight: isIPhone ? 20 : 30, alignment: .leading)
                .font(.body)
                .padding(.bottom, 10)
            
            lazy var dataTypes: [DataType] = {
                return isCurrentAR ? [
                    DataType(
                        type: UploadCase.Ifc,
                        label: "DESIGN_DATA_IFC".localized(userManager.userLanguage)
                    ),
                    DataType(
                        type: UploadCase.Las,
                        label: "POINT_DATA_LAS".localized(userManager.userLanguage)
                    ),
                    DataType(
                        type: UploadCase.Tif,
                        label: "GEO_TIF".localized(userManager.userLanguage)
                    ),
                    DataType(
                        type: UploadCase.Json,
                        label: "GEO_JSON".localized(userManager.userLanguage)
                    )
                ] : [
                    DataType(
                        type: UploadCase.Ifc,
                        label: "DESIGN_DATA_IFC".localized(userManager.userLanguage)
                    ),
                    DataType(
                        type: UploadCase.Tif,
                        label: "GEO_TIF".localized(userManager.userLanguage)
                    ),
                    DataType(
                        type: UploadCase.Json,
                        label: "GEO_JSON".localized(userManager.userLanguage)
                    )
                ]
            }()

            
            HStack {
                Menu {
                    ForEach(dataTypes, id: \.self) { type in
                        Button(type.label) {
                            if dataTypeSelected != type.type {
                                dataTypeSelected = type.type
                                // Reset groupware data each time option changed
                                disableButtonUpload = true
                                isValidUploadGeo = false
                                isValidUploadTif = false
                                productData.lishDashboard = []
                                productData.listDesign = []
                                
                                groupwareSelected = nil
                                selectedFileURL = nil
                            }
                        }
                    }.padding(20)
                } label: {
                    Text("\(getLabel(forKey: dataTypeSelected.rawValue, dataTypes: dataTypes))")
                        .foregroundColor(userManager.setting.textColor)
                        .padding(.horizontal, 10.0)
                        .frame(width: 380, height: 42, alignment: .leading)
                        .border(.gray, width: 1)
                        .contentShape(Rectangle())
                }
                .overlay {
                    Image("arrowDown")
                            .renderingMode(.template)
                            .foregroundColor(userManager.setting.textColor)
                            .allowsHitTesting(false)
                            .position(x: 360, y: 20)
                }
            }
            .padding(.bottom, isIPhone ? 10 : 20)
            
            if dataTypeSelected == .Ifc {
                bodyPopup()
            }
            
            if dataTypeSelected == .Las {
                bodyPopup()
            }

            if dataTypeSelected == .Tif {
                bodyUploadGeoTif()
            }
            
            if dataTypeSelected == .Json {
                bodyUploadGeoJson()
            }
        }
        .padding(.all, isIPhone ? 20 : 30)
        .background(userManager.setting.themeColor)
        .frame(width: isIPhone ? 680 : 700)
        .border(.gray, width: 1)
        .onAppear(){
            hideDetails();
            shouldInterpolate = true;
            addvancedSettingIsExpanded = false;
            coordinateSetting = userManager.setting.coordinateSetting
            linkDashboard = userManager.setting.linkDashboard
            dataTypeSelected = .Ifc
        }
        .onChange(of: dataTypeSelected) { _ in
            // Should reset view each time selection has changed
            isValidUploadTif = tifFileURL != nil && xmlFileURL != nil
            isValidUploadGeo = jsonFileUrl != nil
        }
    }
    
    private func bodyPopup() -> some View {
        let color: String = cat?.ar_color ?? "#50E3C2"
        
        return ARUploadPopup(
            isShow:$show,
            cat: $cat,
            projectName:$projectName,
            jobsite:$jobsite,
            isShowGroupware: $isShowGroupware,
            groupwareSelected: $groupwareSelected,
            groupwareTypeSelected: $groupwareTypeSelected,
            selectedFileURL: $selectedFileURL,
            disableButtonUpload: $disableButtonUpload,
            ar_color: Color(hex:color),
            handler: { jobSite, useARMarker ,cat ,fileURL, fileName, ar_color in
                upload(
                    jobSiteId: jobSite,
                    useARMarker: useARMarker,
                    cat: cat,
                    selectedFileURL: fileURL,
                    selectedFileName: fileName,
                    isAR: true,
                    ar_color: ar_color
                )
            },
            onUploadGroupware: onUploadGroupware
        )
        .environmentObject(userManager)
        .environmentObject(productData)
    }
    
    private func bodyUploadGeoTif() -> some View {
        VStack(alignment: .leading) {
            btnLabel("PLEASE_SELECT_TIF_FILE".localized(userManager.userLanguage))
            
            ButtonSelectFile(
                buttonText: nil,
                fileTypes: [FileTypes[FileType.tif]!]
            ) { fileUrl, fileName in
                tifFileURL = fileUrl
            }
            .padding(.bottom, UserSession.isIPhone ? 10 : 20)
            
            btnLabel("PLEASE_SELECT_XML_FILE".localized(userManager.userLanguage))
            
            ButtonSelectFile(
                buttonText: nil,
                fileTypes: [FileTypes[FileType.xml]!]
            ) { fileUrl, fileName in
                xmlFileURL = fileUrl
            }
            .padding(.bottom, UserSession.isIPhone ? 10 : 20)
            
            bottomButtons(
                isValidUpload: $isValidUploadTif,
                onClickCancel: {
                    tifFileURL = nil
                    xmlFileURL = nil
                },
                onClickUpload: {
                    handleUploadHeatmap()
                }
            )
        }
        .onChange(of: tifFileURL) { _ in
            isValidUploadTif = tifFileURL != nil && xmlFileURL != nil
        }
        .onChange(of: xmlFileURL) { _ in
            isValidUploadTif = tifFileURL != nil && xmlFileURL != nil
        }
    }
    
    private func bodyUploadGeoJson() -> some View {
        VStack(alignment: .leading) {
            btnLabel("PLEASE_SELECT_FILE".localized(userManager.userLanguage))
            
            ButtonSelectFile(
                buttonText: nil,
                fileTypes: [FileTypes[FileType.json]!]
            ) { fileUrl, fileName in
                jsonFileUrl = fileUrl
            }
            .padding(.bottom, UserSession.isIPhone ? 10 : 20)
            
            bottomButtons(
                isValidUpload: $isValidUploadGeo,
                onClickCancel: {
                    jsonFileUrl = nil
                },
                onClickUpload: {
                    handleUploadGeoJson()
                }
            )
        }
        .onChange(of: jsonFileUrl) { _ in
            isValidUploadGeo = jsonFileUrl != nil
        }
    }
    
    private func btnLabel(_ label: String) -> some View {
        Text(label)
            .lineLimit(2)
            .foregroundColor(userManager.setting.textColor)
            .frame(minHeight: isIPhone ? 20 : 30, alignment: .leading)
            .font(.body)
    }
    
    private func bottomButtons(
        isValidUpload: Binding<Bool>,
        onClickCancel: @escaping () -> Void,
        onClickUpload: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 20) {
            Button(action: {
                withAnimation(.linear(duration: 0.3)) {
                    onClickCancel()
                    show = false
                }
            }, label: {
                Text("CANCEL".localized(userManager.userLanguage))
                    .font(isIPhone ? .headline.bold() : .title3.bold())
                    .foregroundColor(userManager.setting.textColor)
                    .frame(height: isIPhone ? 40 : 55, alignment: .center)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .contentShape(Rectangle())
            })
            .background(userManager.setting.themeColor)
            .buttonStyle(PlainButtonStyle())
            .border(userManager.setting.textColor, width: 1)
            
            Button(action: {
                onClickUpload()
            }, label: {
                Text("UPLOAD".localized(userManager.userLanguage))
                    .font(isIPhone ? .headline.bold() : .title3.bold())
                    .foregroundColor(.white)
                    .frame(height: isIPhone ? 40 : 55, alignment: .center)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .contentShape(Rectangle())
            })
            .background(.blue)
            .buttonStyle(PlainButtonStyle())
            .disabled(!isValidUpload.wrappedValue)
        }
        .padding(.top, 10)
        .padding(.bottom, isIPhone ? 10 : 20)
    }
    
    private func handleUploadHeatmap() {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error: Documents directory not found.")
            return
        }
        guard let tifUrl = tifFileURL, let xmlUrl = xmlFileURL else {
            return
        }
        
        let zipFileURL = documentsURL.appendingPathComponent("heatmap.zip")
        guard FileManager.default.fileExists(atPath: tifUrl.path),
              FileManager.default.fileExists(atPath: xmlUrl.path) else {
            print("Error: One or both source files do not exist.")
            return
        }

        do {
            let archive = try Archive(url: zipFileURL, accessMode: .create)
            try archive.addEntry(with: tifUrl.lastPathComponent, relativeTo: tifUrl.deletingLastPathComponent())
            try archive.addEntry(with: xmlUrl.lastPathComponent, relativeTo: xmlUrl.deletingLastPathComponent())
            
            upload(
                jobSiteId: jobsite?.id ?? "",
                useARMarker: useARMarker,
                cat: cat,
                selectedFileURL: zipFileURL,
                selectedFileName: zipFileURL.lastPathComponent,
                isAR: true,
                ar_color: cat?.ar_color ?? "#50E3C2"
            )
            
            show = false
        } catch {
            print("Error creating or adding to archive: \(error.localizedDescription)")
        }
    }
    
    private func handleUploadGeoJson() {
        guard let jsonUrl = jsonFileUrl else {
            return
        }
        
        upload(
            jobSiteId: jobsite?.id ?? "",
            useARMarker: useARMarker,
            cat: cat,
            selectedFileURL: jsonUrl,
            selectedFileName: jsonUrl.lastPathComponent,
            isAR: true,
            ar_color: cat?.ar_color ?? "#50E3C2"
        )
        
        show = false
    }
}

extension BaseUploadPopup {
    func getLabel(forKey key: Int, dataTypes:[DataType]) -> String {
        // keyに対応するOptionを検索
        if let option = dataTypes.first(where: { $0.type.rawValue == key }) {
            return option.label
        }
        return ""
    }
    
    func upload(
        jobSiteId: String,
        useARMarker: Bool,
        cat: Cat?,
        selectedFileURL: URL?,
        selectedFileName: String,
        isAR :Bool,
        ar_color: String
    ){
        let fileNameFormatted = selectedFileName.removingPercentEncoding ?? selectedFileName
        handler(
            jobSiteId,
            useARMarker,
            cat,
            selectedFileURL,
            fileNameFormatted,
            false,
            false,
            false,
            isAR,
            ar_color
        )
    }
    
    func uploadZip(jobSiteId: String, useARMarker: Bool, cat: Cat?, selectedFileURL: URL?, selectedFileName: String, coordinateSetting: Bool, linkDashboard: Bool, shouldInterpolate: Bool, isAR :Bool){
        handler(jobSiteId, useARMarker, cat, selectedFileURL, selectedFileName,coordinateSetting,linkDashboard,shouldInterpolate, isAR,nil)
    }
}
