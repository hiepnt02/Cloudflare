//
//  BaseUploadPopup.swift
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
    struct DataType: Hashable {
        let type: UploadCase
        let label: String
    }

    // MARK: - Inputs

    @Binding var show: Bool
    @Binding var cat: Cat?

    @Binding var projectName: String
    @Binding var jobsite: JobSite.Site?
    @Binding var isCurrentAR: Bool

    @Binding var isShowGroupware: Bool
    @Binding var groupwareSelected: GroupwareModel?
    @Binding var groupwareTypeSelected: GroupwareType
    @Binding var dataTypeSelected: UploadCase

    var handler: (String, Cat?, URL?, String, [String], String?) -> Void
    var onUploadGroupware: (
        Cat,
        String,         // JobsiteId
        GroupwareModel,
        String          // AR Color
    ) -> Void

    @EnvironmentObject var productData: ProductData
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var uploadQueue: UploadQueueManager

    // MARK: - State

    @State private var isKeyboardShow = false

    @State private var selectedFileURL: URL?
    @State private var model3DFileURL: URL?
    @State private var lasFileURL: URL?
    @State private var dxfFileURL: URL?
    @State private var tifFileURL: URL?
    @State private var xmlFileURL: URL?
    @State private var jsonFileURL: URL?
    @State private var plyFileUrl: URL?

    @State private var arColor = Color(hex: BaseUploadPopup.defaultARColor)
    @State private var selectedFileName: String = ""
    @State private var selectedFileSize: String = ""
    @State private var selectedHexColor: String?

    @State private var isValidUploadIfc = false
    @State private var isValidUploadModel3D = false
    @State private var isValidUploadLas = false
    @State private var isValidUploadTif = false
    @State private var isValidUploadGeo = false
    @State private var isValidUploadPly = false
    @State private var isUploading = false
    @StateObject private var popoverManager = PopoverManager()

    private let isIPhone = UIDevice.current.isIphone

    private static let defaultARColor = "#50E3C2"

    // MARK: - Layout

    private var labelMinHeight: CGFloat { isIPhone ? 20 : 30 }
    private var contentSpacing: CGFloat { isIPhone ? 10 : 20 }
    private var sectionSpacing: CGFloat { isIPhone ? 20 : 30 }
    private var iconSpacing: CGFloat { isIPhone ? 5 : 10 }
    private var actionButtonHeight: CGFloat { isIPhone ? 40 : 55 }
    private var groupwareIconSize: CGFloat { isIPhone ? 35 : 45 }
    private var actionButtonFont: Font { isIPhone ? .headline.bold() : .title3.bold() }

    private let pickerSize = CGSize(width: 380, height: 42)
    private let pickerArrowPosition = CGPoint(x: 360, y: 20)

    // MARK: - Derived values

    private var currentARColor: String {
        cat?.ar_color ?? Self.defaultARColor
    }

    private var isShowSelectColor: Bool {
        let localExt = selectedFileURL?.pathExtension.lowercased()
        let groupwareExt = groupwareSelected?.name.components(separatedBy: ".").last?.lowercased()
        return localExt == "xml" || groupwareExt == "xml"
    }

    private var isTifSelectionComplete: Bool {
        tifFileURL != nil && xmlFileURL != nil
    }

    private var dataTypes: [DataType] {
        let all: [DataType] = [
            DataType(type: .Ifc,  label: "DESIGN_DATA_IFC".localized(userManager.userLanguage)),
            DataType(type: .Model3D, label: "DESIGN_DATA_FBX".localized(userManager.userLanguage)),
            DataType(type: .Las,  label: "POINT_DATA_LAS".localized(userManager.userLanguage)),
            DataType(type: .Tif,  label: "GEO_TIF".localized(userManager.userLanguage)),
            DataType(type: .Json, label: "GEO_JSON".localized(userManager.userLanguage)),
            DataType(type: .Ply,  label: "GAUSSIAN_SPLATTING_PLY".localized(userManager.userLanguage))
        ]
        return isCurrentAR ? all : all.filter { $0.type != .Las }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            if show {
                Color(.black)
                    .colorInvert()
                    .opacity(0.3)
                    .edgesIgnoringSafeArea(.all)

                ScrollView(showsIndicators: false) {
                    contentView
                        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                            isKeyboardShow = true
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                            isKeyboardShow = false
                        }
                }
                .frame(
                    width: UIScreen.main.bounds.width * 0.70,
                    height: UIScreen.main.bounds.height * (isKeyboardShow ? 0.55 : 0.80)
                )
            }
        }
        .onTapGesture {
            popoverManager.hideAll()
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView

            sectionLabel("DATA_TYPE".localized(userManager.userLanguage))
                .padding(.bottom, 10)

            dataTypePicker
                .padding(.bottom, contentSpacing)

            switch dataTypeSelected {
            case .Ifc:  ifcSection
            case .Model3D: model3DSection
            case .Las:  lasSection
            case .Tif:  geoTifSection
            case .Json: geoJsonSection
            case .Ply:  plySection
            }
        }
        .padding(.all, sectionSpacing)
        .background(userManager.setting.themeColor)
        .frame(width: isIPhone ? 680 : 700)
        .border(.gray, width: 1)
        .onAppear {
            dataTypeSelected = .Ifc
            arColor = Color(hex: currentARColor)
        }
        .onChange(of: dataTypeSelected) { _ in
            refreshUploadValidity()
        }
    }

    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("UPLOAD_DATA_FOR_AR".localized(userManager.userLanguage))
                    .foregroundColor(userManager.setting.textColor)
                    .font(.title2.bold())

                Spacer()

                Button {
                    closePopup()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(userManager.setting.textColor)
                }
            }
            .padding(.top, sectionSpacing)
            .padding(.bottom, 10)

            Divider()
                .frame(height: 2)
                .background(userManager.setting.themeColor)
                .padding(.bottom, contentSpacing)
        }
    }

    private var dataTypePicker: some View {
        Menu {
            ForEach(dataTypes, id: \.self) { type in
                Button(type.label) {
                    guard dataTypeSelected != type.type else { return }
                    dataTypeSelected = type.type
                    resetDataTypeSelection()
                }
            }
            .padding(20)
        } label: {
            Text(dataTypes.first(where: { $0.type == dataTypeSelected })?.label ?? "")
                .foregroundColor(userManager.setting.textColor)
                .padding(.horizontal, 10.0)
                .frame(width: pickerSize.width, height: pickerSize.height, alignment: .leading)
                .contentShape(Rectangle())
        }
        .border(.gray, width: 1)
        .overlay {
            Image("arrowDown")
                .renderingMode(.template)
                .foregroundColor(userManager.setting.textColor)
                .allowsHitTesting(false)
                .position(x: pickerArrowPosition.x, y: pickerArrowPosition.y)
        }
    }
}

// MARK: - Data type sections

private extension BaseUploadPopup {
    var ifcSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("UPLOAD_FROM_LOCAL_OR_FROM_GROUPWARE".localized(userManager.userLanguage))
                .padding(.bottom, 10)

            fileSourceRow(
                fileTypes: [FileTypes[FileType.ifc]!, FileTypes[FileType.xml]!],
                fileURL: $selectedFileURL,
                isValidUpload: $isValidUploadIfc
            )
            .padding(.bottom, sectionSpacing)

            if isShowSelectColor {
                ColorPicker("AR_DATA_COLOR".localized(userManager.userLanguage), selection: $arColor)
                    .lineLimit(2)
                    .foregroundColor(userManager.setting.textColor)
                    .frame(minHeight: labelMinHeight, alignment: .leading)
                    .font(.body)
                    .padding(.bottom, contentSpacing)
                    .onChange(of: arColor) { newColor in
                        if let hex = newColor.toHexString() {
                            selectedHexColor = hex
                        }
                    }
            }

            bottomButtons(
                isValidUpload: $isValidUploadIfc,
                onClickCancel: resetIfcSelection,
                onClickUpload: handleUploadIfc
            )
        }
        .onChange(of: groupwareSelected) { newGroupware in
            applyGroupwareSelection(
                newGroupware,
                whenSelected: .Ifc,
                clearing: $selectedFileURL,
                isValidUpload: $isValidUploadIfc
            )
        }
    }

    var model3DSection: some View {
        VStack(alignment: .leading) {
            sectionLabel("PLEASE_SELECT_FILE".localized(userManager.userLanguage))

            ButtonSelectFile(
                buttonText: nil,
                fileTypes: [FileTypes[FileType.fbx]!, FileTypes[FileType.glb]!, FileTypes[FileType.dwg]!]
            ) { fileUrl, _ in
                model3DFileURL = fileUrl
            }
            .padding(.leading, contentSpacing)
            .padding(.bottom, contentSpacing)

            bottomButtons(
                isValidUpload: $isValidUploadModel3D,
                onClickCancel: resetModel3DSelection,
                onClickUpload: handleUploadModel3D
            )
        }
        .onChange(of: model3DFileURL) { _ in
            isValidUploadModel3D = model3DFileURL != nil
        }
    }

    var lasSection: some View {
        VStack(alignment: .leading) {
            sectionLabel("UPLOAD_FROM_LOCAL_OR_FROM_GROUPWARE".localized(userManager.userLanguage))

            fileSourceRow(
                fileTypes: [FileTypes[FileType.las]!],
                fileURL: $lasFileURL,
                isValidUpload: $isValidUploadLas
            )
            .padding(.bottom, contentSpacing)

            bottomButtons(
                isValidUpload: $isValidUploadLas,
                onClickCancel: resetLasSelection,
                onClickUpload: handleUploadLas
            )
        }
        .onChange(of: groupwareSelected) { newGroupware in
            applyGroupwareSelection(
                newGroupware,
                whenSelected: .Las,
                clearing: $lasFileURL,
                isValidUpload: $isValidUploadLas
            )
        }
    }

    var geoTifSection: some View {
        VStack(alignment: .leading) {
            sectionLabel("PLEASE_SELECT_TIF_FILE".localized(userManager.userLanguage))

            ButtonSelectFile(buttonText: nil, fileTypes: [FileTypes[FileType.tif]!]) { fileUrl, _ in
                tifFileURL = fileUrl
            }
            .padding(.leading, contentSpacing)
            .padding(.bottom, contentSpacing)

            sectionLabel("PLEASE_SELECT_XML_FILE".localized(userManager.userLanguage))

            ButtonSelectFile(
                buttonText: nil,
                fileTypes: [FileTypes[FileType.xml]!]
            ) { fileUrl, _ in
                xmlFileURL = fileUrl
            }
            .padding(.leading, contentSpacing)
            .padding(.bottom, contentSpacing)

            bottomButtons(
                isValidUpload: $isValidUploadTif,
                onClickCancel: {
                    tifFileURL = nil
                    xmlFileURL = nil
                },
                onClickUpload: handleUploadHeatmap
            )
        }
        .onChange(of: tifFileURL) { _ in
            isValidUploadTif = isTifSelectionComplete
        }
        .onChange(of: xmlFileURL) { _ in
            isValidUploadTif = isTifSelectionComplete
        }
    }

    var geoJsonSection: some View {
        VStack(alignment: .leading) {
            sectionLabel("PLEASE_SELECT_FILE".localized(userManager.userLanguage))

            ButtonSelectFile(
                buttonText: nil,
                fileTypes: [FileTypes[FileType.json]!]
            ) { fileUrl, _ in
                jsonFileURL = fileUrl
            }
            .padding(.bottom, contentSpacing)

            bottomButtons(
                isValidUpload: $isValidUploadGeo,
                onClickCancel: { jsonFileURL = nil },
                onClickUpload: handleUploadGeoJson
            )
        }
        .onChange(of: jsonFileURL) { _ in
            isValidUploadGeo = jsonFileURL != nil
        }
    }
    
    var plySection: some View {
        VStack(alignment: .leading) {
            sectionLabel("PLEASE_SELECT_FILE".localized(userManager.userLanguage))
            
            ButtonSelectFile(
                buttonText: nil,
                fileTypes: [FileTypes[FileType.ply]!]
            ) { fileUrl, fileName in
                plyFileUrl = fileUrl
            }
            
            bottomButtons(
                isValidUpload: $isValidUploadPly,
                onClickCancel: {
                    plyFileUrl = nil
                },
                onClickUpload: {
                    handleUploadPly()
                }
            )
        }
        .onChange(of: plyFileUrl) { _ in isValidUploadPly = plyFileUrl != nil }
    }
}

// MARK: - Shared subviews

private extension BaseUploadPopup {
    func sectionLabel(_ label: String) -> some View {
        Text(label)
            .lineLimit(2)
            .foregroundColor(userManager.setting.textColor)
            .frame(minHeight: labelMinHeight, alignment: .leading)
            .font(.body)
    }

    /// Local file picker plus the two groupware entry points, sharing one file name/size display.
    func fileSourceRow(
        fileTypes: [UTType],
        fileURL: Binding<URL?>,
        isValidUpload: Binding<Bool>
    ) -> some View {
        HStack {
            ButtonSelectFile(
                buttonText: nil,
                fileTypes: fileTypes,
                isHideFileName: true
            ) { fileUrl, fileName in
                fileURL.wrappedValue = fileUrl
                selectedFileName = fileName ?? ""
                selectedFileSize = (fileUrl?.fileSize ?? 0).bytesToHumanReadable()
                groupwareSelected = nil
                isValidUpload.wrappedValue = fileUrl != nil
            }
            .padding(.leading, contentSpacing)

            groupwareButton(type: .dashboard, imageName: "icDashboard")
            groupwareButton(type: .design, imageName: "icDesign3D")

            if !selectedFileName.isEmpty {
                FileInfoView(
                    fileName: $selectedFileName,
                    fileSize: $selectedFileSize
                )
                .environmentObject(userManager)
            }
        }
    }

    func groupwareButton(type: GroupwareType, imageName: String) -> some View {
        Button {
            groupwareTypeSelected = type
            isShowGroupware = true
        } label: {
            Image(imageName).resizable()
        }
        .frame(width: groupwareIconSize, height: groupwareIconSize)
        .padding(.leading, iconSpacing)
    }

    func bottomButtons(
        isValidUpload: Binding<Bool>,
        onClickCancel: @escaping () -> Void,
        onClickUpload: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 20) {
            Button {
                withAnimation(.linear(duration: 0.3)) {
                    onClickCancel()
                    show = false
                }
            } label: {
                Text("CANCEL".localized(userManager.userLanguage))
                    .font(actionButtonFont)
                    .foregroundColor(userManager.setting.textColor)
                    .frame(height: actionButtonHeight, alignment: .center)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .background(userManager.setting.themeColor)
            .buttonStyle(PlainButtonStyle())
            .border(userManager.setting.textColor, width: 1)

            Button {
                onClickUpload()
            } label: {
                Text("UPLOAD".localized(userManager.userLanguage))
                    .font(actionButtonFont)
                    .foregroundColor(.white)
                    .frame(height: actionButtonHeight, alignment: .center)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .background(.blue)
            .buttonStyle(PlainButtonStyle())
            .disabled(!isValidUpload.wrappedValue)
        }
        .padding(.top, 10)
        .padding(.bottom, contentSpacing)
    }
}

// MARK: - Upload actions

private extension BaseUploadPopup {
    func handleUploadIfc() {
        guard var cat = cat else { return }
        guard !projectName.isEmpty else { return }
        guard let jobsite = jobsite else { return }

        guard ProductUtil.validationCheck(projectName) else {
            APAlert.shared.showAlert(
                title: "",
                message: "PROHIBITED_CHARACTER_MESSAGE".localized(userManager.userLanguage),
                buttonTitle: "CLOSE".localized(userManager.userLanguage)
            )
            return
        }

        let newARColor = selectedHexColor ?? currentARColor
        if selectedHexColor != nil {
            cat.ar_color = selectedHexColor
        }

        if let groupwareSelected = groupwareSelected {
            onUploadGroupware(cat, jobsite.id, groupwareSelected, newARColor)
            projectName = ""
            resetIfcSelection()
            show = false
            return
        }

        cat.title = projectName
        cat.jobsiteId = jobsite.id

        guard let fileExtension = selectedFileURL?.pathExtension else { return }
        switch fileExtension {
        case "las":
            cat.las_file = selectedFileName
        case "xml", "ifc":
            cat.ifc_file = selectedFileName
        default:
            break
        }

        upload(
            cat: cat,
            fileURL: selectedFileURL,
            fileName: selectedFileName,
            arColor: newARColor
        )
    }

    func handleUploadLas() {
        guard let cat = cat, let jobsite = jobsite else { return }
        let arColor = currentARColor

        // A groupware LAS without a local DXF goes through the queued upload path.
        if let groupwareSelected = groupwareSelected, dxfFileURL == nil {
            onUploadGroupware(cat, jobsite.id, groupwareSelected, arColor)
            resetLasSelection()
            show = false
            return
        }

        let source: ARUploadSource
        if let groupwareSelected = groupwareSelected, let dxfURL = dxfFileURL {
            source = .groupwareWithLocalFile(groupwareSelected, file2URL: dxfURL)
        } else if let lasURL = lasFileURL {
            source = .local(file1URL: lasURL, file2URL: dxfFileURL)
        } else {
            return
        }

        uploadQueue.enqueue(
            UploadJob(
                cat: cat,
                jobsiteId: jobsite.id,
                kind: .arData(
                    UploadJob.ARDataParameters(
                        source: source,
                        arColor: arColor
                    )
                )
            )
        )
        resetLasSelection()
        show = false
    }

    func handleUploadModel3D() {
        guard let model3DUrl = model3DFileURL else { return }

        upload(
            cat: cat,
            fileURL: model3DUrl,
            fileName: model3DUrl.lastPathComponent,
            arColor: currentARColor
        )
    }

    func handleUploadHeatmap() {
        guard
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            let tifUrl = tifFileURL,
            let xmlUrl = xmlFileURL,
            FileManager.default.fileExists(atPath: tifUrl.path),
            FileManager.default.fileExists(atPath: xmlUrl.path)
        else { return }

        let zipFileURL = documentsURL.appendingPathComponent("heatmap.zip")

        do {
            if FileManager.default.fileExists(atPath: zipFileURL.path) {
                try FileManager.default.removeItem(at: zipFileURL)
            }
            let archive = try Archive(url: zipFileURL, accessMode: .create)
            try archive.addEntry(with: tifUrl.lastPathComponent, relativeTo: tifUrl.deletingLastPathComponent())
            try archive.addEntry(with: xmlUrl.lastPathComponent, relativeTo: xmlUrl.deletingLastPathComponent())

            upload(
                cat: cat,
                fileURL: zipFileURL,
                fileName: zipFileURL.lastPathComponent,
                arColor: currentARColor,
                sourceFileNames: [tifUrl.lastPathComponent, xmlUrl.lastPathComponent]
            )
        } catch {
            print("Error creating or adding to archive: \(error.localizedDescription)")
        }
    }

    func handleUploadGeoJson() {
        guard let jsonUrl = jsonFileURL else { return }

        upload(
            cat: cat,
            fileURL: jsonUrl,
            fileName: jsonUrl.lastPathComponent,
            arColor: currentARColor
        )
    }

    func upload(
        cat: Cat?,
        fileURL: URL?,
        fileName: String,
        arColor: String,
        sourceFileNames: [String] = []
    ) {
        let fileNameFormatted = fileName.removingPercentEncoding ?? fileName
        defer {
            resetDataTypeSelection()
            show = false
        }
        handler(
            jobsite?.id ?? "",
            cat,
            fileURL,
            fileNameFormatted,
            sourceFileNames,
            arColor
        )
    }
    
    func handleUploadPly() {
        guard let plyUrl = plyFileUrl else {
            return
        }
        
        upload(
            cat: cat,
            fileURL: plyUrl,
            fileName: plyUrl.lastPathComponent,
            arColor: currentARColor
        )
        
        show = false
    }
    
}

// MARK: - Selection state

private extension BaseUploadPopup {
    /// Re-derives the upload buttons from the files still held per data type,
    /// so switching back to a type keeps its previous selection usable.
    func refreshUploadValidity() {
        isValidUploadTif = isTifSelectionComplete
        isValidUploadGeo = jsonFileURL != nil
        isValidUploadLas = lasFileURL != nil
        isValidUploadModel3D = model3DFileURL != nil
    }

    func applyGroupwareSelection(
        _ groupware: GroupwareModel?,
        whenSelected dataType: UploadCase,
        clearing localFileURL: Binding<URL?>,
        isValidUpload: Binding<Bool>
    ) {
        guard dataTypeSelected == dataType, let groupware = groupware else { return }
        selectedFileName = groupware.name
        selectedFileSize = Int(groupware.size)?.bytesToHumanReadable() ?? ""
        localFileURL.wrappedValue = nil
        isValidUpload.wrappedValue = true
    }

    /// State shared by every data type: the picked file's display info and the groupware lists.
    func clearSharedSelection() {
        selectedFileName = ""
        selectedFileSize = ""
        selectedHexColor = nil
        groupwareSelected = nil
        productData.lishDashboard = []
        productData.listDesign = []
    }

    func resetIfcSelection() {
        clearSharedSelection()
        selectedFileURL = nil
        isValidUploadIfc = false
    }

    func resetModel3DSelection() {
        model3DFileURL = nil
        isValidUploadModel3D = false
    }

    func resetLasSelection() {
        clearSharedSelection()
        lasFileURL = nil
        dxfFileURL = nil
        isValidUploadLas = false
    }

    func resetDataTypeSelection() {
        clearSharedSelection()
        selectedFileURL = nil
        model3DFileURL = nil
        isValidUploadIfc = false
        isValidUploadModel3D = false
        isValidUploadLas = false
        isValidUploadTif = false
        isValidUploadGeo = false
        popoverManager.hideAll()
    }

    func closePopup() {
        projectName = ""
        resetIfcSelection()
        show = false
    }
}
