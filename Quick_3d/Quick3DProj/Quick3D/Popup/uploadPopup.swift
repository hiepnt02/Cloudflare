//
//  JobSitePopup.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 26/04/2022.
//

import SwiftUI
import Alamofire

enum CoordinateOptions {
    case smartAlign
    case selectManual
    case notConvert
}

struct UploadPopup: View {
    var isEdit: Bool
    @State private var isPopupPresented: Bool = false
    
    var filteredSites: [JobSite.Site] {
        productData.jobSite?.sites
            .filter { $0.name.localizedCaseInsensitiveContains(searchText) } ?? []
    }
    
    @Binding var show: Bool
    @Binding var cat: Cat?
    @EnvironmentObject var productData: ProductData
    @EnvironmentObject var userManager: UserManager
    
    @Binding var projectName: String
    @Binding var searchText:String
    @Binding var siteSelected: JobSite.Site?
    
    @Binding var isInQueue: Bool
    
    var handler: (
        String, // Site selected id
        Bool, // is use AR marker
        Bool, // is on coordinate setting
        Bool, // is link dashboard
        Bool, // is should interpolate
        String, // vertical coordinate key
        String, // horiznotal coordinate key
        Cat? // cat
    ) -> Void
    
    @State var isShowJobSiteView: Bool = false
    @State private var disableButton: Bool = true
    @State private var useARMarker = false
    @State private var isKeyboardShow = false;
    @State private var coordinateSetting: Bool = false
    @State private var linkDashboard: Bool = false
    @State private var shouldInterpolate: Bool = true
    
    @State private var addvancedSettingIsExpanded = false
    @State private var coordinateSettingDisable: Bool = false
    
    @FocusState private var focusState: Bool
    @FocusState private var isFocusJobsite: Bool
    
    // JobSite variables
    @State private var jobsiteInputted: String = ""
    
    @State private var requestAF: DataRequest? = nil
    @State private var coordinateJobSite: CoodinateSystemJobsite? = nil
    @State private var isGettingCoordinateJobsite = false
    
    // Vertival coordinate key manual selected. Exp: "CZM: 5705"
    @State private var vCoordInputted: String = ""
    @State private var vCoordSelectedKey: String = ""
    // Horizontal coordinate key manual selected.
    @State private var hCoordInputted: String = ""
    @State private var hCoordSelectedKey: String = ""
    @State private var coordOptionSelected: CoordinateOptions = .smartAlign
    @State private var vCoordKeyFinal: String = ""
    @State private var hCoordKeyFinal: String = ""
    
    @State private var isPopupVcoordPresented: Bool = false
    @State private var isPopupHcoordPresented: Bool = false
    
    @FocusState private var isFocusVcoord: Bool
    @FocusState private var isFocusHcoord: Bool
    
    @State private var isDisableSmartAlign: Bool = false
    @State private var isPjNameValid = true
    
    private let contentPadding: CGFloat = UserSession.isIPhone ? 30 : 40
    private let subContentPadding: CGFloat = UserSession.isIPhone ? 55 : 65
    
    @StateObject private var popoverManager = PopoverManager()
    func hideDetails() {
        self.anyDetailIsShown = false;
        self.linkTipIsShown = false;
        self.uploadTipIsShown = false;
        self.interpolateTipIsShown = false;
        self.coordinateJobSiteInfoTipIsShown = false;
    }
    
    func customPopover(isShown: Binding<Bool>, content: String, frameValue: (width: CGFloat, height: CGFloat), offsetValue: (x: CGFloat, y: CGFloat), icon : String = "") -> some View{
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
                Text(icon)
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
                .background(
                    userManager.setting.themeColor,
                    in: Rectangle(),
                    fillStyle: FillStyle(eoFill: true)
                )
                .foregroundColor(userManager.setting.textColor)
                .border(Color.gray, width: 1)
                .font(.caption.bold())
                .dynamicTypeSize(DynamicTypeSize.medium)
                .offset(x: offsetValue.x, y: offsetValue.y)
                .onTapGesture {
                }
            : nil
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
                    contentView
                        .onReceive(
                            NotificationCenter.default
                                .publisher(
                                    for: UIResponder.keyboardWillShowNotification
                                )
                        ) {_ in
                            // Bool変数を変更
                            isKeyboardShow = true
                        }.onReceive(
                            NotificationCenter.default
                                .publisher(
                                    for: UIResponder.keyboardWillHideNotification
                                )
                        ) {_ in
                            // Bool変数を変更
                            isKeyboardShow = false
                        }
                }
                .frame(
                    width: UIScreen.main.bounds.width * (UserSession.isIPhone ? 0.7 : 0.6),
                    height: UIScreen.main.bounds.height * (isKeyboardShow ? 0.55 : 0.80)
                )
                .background(userManager.setting.themeColor)
                .border(.gray, width: 1)
            }
        }
        .onTapGesture {
            popoverManager.hideAll()
            
            // Hide popup select coordinate when touched outside
            isFocusJobsite = false
            isPopupPresented = false
            
            isFocusVcoord = false
            isPopupVcoordPresented = false
            
            isFocusHcoord = false
            isPopupHcoordPresented = false
        }
    }
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView()
            
            Divider()
                .frame(height: 1)
                .background(userManager.setting.textColor)
                .padding(.bottom, UserSession.isIPhone ? 20 : 30)
            
            // MARK: Section Input Project Name
            titleSection("PROJECT_NAME_INPUT".localized(userManager.userLanguage))
            
            TextField(
                "PROJECT_NAME".localized(userManager.userLanguage),
                text: $projectName
            )
            .foregroundColor(userManager.setting.textColor)
            .disableAutocorrection(true)
            .padding(.horizontal, 10)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color(.lightGray), lineWidth: 1)
                    .overlay(alignment: .bottom) {
                        if focusState {
                            Rectangle().frame(height: 4).foregroundColor(.blue)
                        }
                    }
                    .frame(height: UserSession.isIPhone ? 40 : 55, alignment: .leading)
            )
            .modifier(ClearButton(text: $projectName))
            .font(.body)
            .padding(.leading, contentPadding)
            .focused($focusState)
            
            Text("PROJECT_NAME_IS_INVALID".localized(userManager.userLanguage))
                .font(.body)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, contentPadding)
                .padding(.top, 8)
                .padding(.bottom, UserSession.isIPhone ? 10 : 20)
                .opacity(isPjNameValid ? 0.0 : 1.0)
            
            // MARK: Section Select Jobsite
            titleSection("PLS_SELECT_JOBSITE".localized(userManager.userLanguage))
            
            JobsiteTextField(
                listData: productData.jobSite?.sites ?? [],
                isShowPopup: $isPopupPresented,
                inputText: $jobsiteInputted,
                jobSiteSelected: $siteSelected,
                isFocus: _isFocusJobsite
            ) { site in
                // Reset coordiate during update new
                self.coordinateJobSite = nil
                
                guard let site = site else {
                    self.isDisableSmartAlign = false
                    self.siteSelected = nil
                    requestAF?.cancel()
                    requestAF = nil
                    isGettingCoordinateJobsite = false
                    return
                }
                
                if self.siteSelected?.id != site.id {
                    self.siteSelected = site
                    // Get new coordiate data of site selected
                    self.getCoordinateSystemJobsite(
                        jobSiteId: site.id,
                        isInitEdit: false
                    )
                }
            }
            .padding(.leading, contentPadding)
            
            Button(action: {
                self.isShowJobSiteView.toggle()
            }) {
                Text("CREATE_NEW_SITE".localized(userManager.userLanguage))
                    .foregroundColor(.white)
                    .font(UserSession.isIPhone ? .body : .title3)
                    .frame(
                        width: 200,
                        height: UserSession.isIPhone ? 40 : 55,
                        alignment: .center
                    )
                    .contentShape(Rectangle())
            }
            .background(.gray)
            .padding(.leading, contentPadding)
            .padding(.bottom, UserSession.isIPhone ? 20 : 30)
            .fullScreenCover(isPresented: $isShowJobSiteView) {
                JobSiteWebView() {
                    productData.fetchJobSiteData()
                }
            }
            
            if productData.displayARSelection {
                selectProcessingView()
            }
            
            if let _ = siteSelected, let conditionFlag = coordinateJobSite?.conditionFlag {
                if conditionFlag {
                    coordinateSystemJobsiteView()
                } else {
                    coordinateInfoView()
                }
            } else {
                if (isGettingCoordinateJobsite) {
                    loadingCoordinateView()
                } else {
                    coordinateInfoView()
                }
            }
            
            // MARK: Section Select Options
            titleSection("DATA_COORDINATE_SYSTEM".localized(userManager.userLanguage))
            
            // MARK: Start select options mart align
            RadioButtonStroke(
                tag: CoordinateOptions.smartAlign,
                selection: $coordOptionSelected,
                label: "ALIGN_SMART_DASHBOARD"
                    .localized(userManager.userLanguage)
            )
            .disabled(isDisableSmartAlign)
            .padding(.leading, contentPadding)
            .padding(.bottom, 16)
            
            if coordOptionSelected == CoordinateOptions.smartAlign {
                uploadSystemSettingView()
                    .padding(.leading, subContentPadding)
                    .padding(.top, 8)
                
                andvanceButtonView()
                    .padding(.leading, subContentPadding)
                
                if addvancedSettingIsExpanded {
                    interpolateSettingC1View()
                        .padding(.leading, subContentPadding)
                        .padding(.bottom, 16)
                }
            }
            
            // MARK: Start select options select coordinate manual
            RadioButtonStroke(
                tag: CoordinateOptions.selectManual,
                selection: $coordOptionSelected,
                label: "CHOOSE_COORDINATE_SYSTEM"
                    .localized(userManager.userLanguage)
            )
            .padding(.leading, contentPadding)
            .padding(.bottom, 16)
            
            if coordOptionSelected == CoordinateOptions.selectManual {
                itemHCoord()
                itemVCoord()
            }
            
            // MARK: Start select options not convert coordinate
            RadioButtonStroke(
                tag: CoordinateOptions.notConvert,
                selection: $coordOptionSelected,
                label: "NOT_CONVERT_COORDINATE_SYSTEM"
                    .localized(userManager.userLanguage)
            )
            .padding(.leading, contentPadding)
            .padding(.bottom, 16)
            
            // MARK: Bottom Buttons View
            bottomButtons()
        }
        .padding(.all, UserSession.isIPhone ? 20 : 30)
        .onChange(of: projectName) { textInputted in
            isPjNameValid = textInputted.validateProjectName()
            validateUpload()
        }
        .onChange(of: coordOptionSelected){ option in
            self.coordinateSetting = option == CoordinateOptions.smartAlign
            validateUpload()
        }
        .onAppear(){
            popoverManager.hideAll()
            
            isPjNameValid = true
            isDisableSmartAlign = false
            shouldInterpolate = true
            addvancedSettingIsExpanded = false
            self.coordinateJobSite = nil
            self.vCoordInputted = ""
            self.hCoordInputted = ""
            self.vCoordSelectedKey = ""
            self.hCoordSelectedKey = ""
            
            // Should reset some data on UI in case upload new project
            if !isEdit {
                projectName = ""
                searchText = ""
                jobsiteInputted = ""
                siteSelected = nil
                
                // In case of creating a new project, get these values ​​in the settings.
                coordinateSetting = userManager.setting.coordinateSetting
                // If coordinateSetting = false tthen should set default coordOptionSelected is manual
                coordOptionSelected = coordinateSetting ? .smartAlign : .selectManual
                linkDashboard = userManager.setting.linkDashboard
                return
            }
            
            // Init data in case edit project
            if let cat = cat {
                coordinateSetting = cat.coordinateSetting
                linkDashboard = cat.linkDashboard
                if let siteSelected = siteSelected {
                    jobsiteInputted = siteSelected.name
                    self.getCoordinateSystemJobsite(
                        jobSiteId: siteSelected.id,
                        isInitEdit: true
                    )
                }
            }
        }
    }
    
    private func headerView() -> some View {
        HStack {
            Text("SFMProcessing".localized(userManager.userLanguage))
                .foregroundColor(userManager.setting.textColor)
                .font(.title2.bold())
            
            Spacer()
            
            // When clicking the "x" button,
            // check if it is in edit state and if the project was previously in the queue.
            // If the above two conditions are satisfied, when clicking the "x" button,
            // add it back to the queue.
            // If not, close the dialog as usual.
            Button(action: isEdit && isInQueue ? addAction : {
                show = false
                searchText = ""
                projectName = ""
                siteSelected = nil
                coordinateJobSite = nil
                requestAF?.cancel()
                requestAF = nil
                isGettingCoordinateJobsite = false
                isPopupPresented = false
            }, label: {
                Image(systemName: "xmark")
                    .foregroundColor(userManager.setting.textColor)
                
            })
        }
        .padding(.bottom, 10)
    }
    
    private func titleSection(_ title: String) -> some View {
        Text(title)
            .foregroundColor(userManager.setting.textColor)
            .font(UserSession.isIPhone ? .title3 : .title2)
            .padding(.bottom, UserSession.isIPhone ? 20 : 30)
    }
    
    private func selectProcessingView() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SELECT_PROCESSING_METHOD".localized(userManager.userLanguage))
            .foregroundColor(userManager.setting.textColor)
            .font(UserSession.isIPhone ? .body : .title2)
            .padding(.bottom, UserSession.isIPhone ? 10 : 20)
            
            RadioButtonGroup(
                items: [
                    "WITH_AR_MARKER".localized(userManager.userLanguage),
                    "NO_AR_MARKER".localized(userManager.userLanguage)
                ],
                direction: .horizon,
                selectedIndex: useARMarker ? 0 : 1
            ) { index in
                useARMarker = index == 0
            }
            .padding(.bottom, UserSession.isIPhone ? 20 : 30)
            .padding(.leading, 10)
        }
        .padding(.leading, contentPadding)
    }
    
    private func itemHCoord() -> some View {
        HStack {
            Text("COORDINATE_SYSTEM".localized(userManager.userLanguage))
                .foregroundColor(userManager.setting.textColor)
                .font(.body)
                .frame(width: 200, alignment: .leading)
            
            CoordinateTextField(
                listData: CoordinateManager.shared.getHCoordinates(),
                isShowPopup: $isPopupHcoordPresented,
                inputText: $hCoordInputted,
                isFocus: _isFocusHcoord
            ) { keyCoord in
                hCoordSelectedKey = keyCoord
                validateUpload()
            }
        }
        .padding(.bottom, 5)
        .padding(.leading, subContentPadding)
    }
    
    private func itemVCoord() -> some View {
        HStack {
            Text("VERTICAL_COORDINATE_SYSTEM".localized(userManager.userLanguage))
                .foregroundColor(userManager.setting.textColor)
                .font(.body)
                .frame(width: 200, alignment: .leading)
            
            CoordinateTextField(
                listData: CoordinateManager.shared.getVCoordinates(),
                isShowPopup: $isPopupVcoordPresented,
                inputText: $vCoordInputted,
                isFocus: _isFocusVcoord
            ) { keyCoord in
                vCoordSelectedKey = keyCoord
                validateUpload()
            }
        }
        .padding(.leading, subContentPadding)
        .padding(.bottom, 16)
    }
    
    func loadingCoordinateView() -> some View {
        return VStack {
            itemLoadingCoordinateView(
                label: "COORDINATE_SYSTEM".localized(userManager.userLanguage)
            )
            itemLoadingCoordinateView(
                label: "VERTICAL_COORDINATE_SYSTEM"
                    .localized(userManager.userLanguage)
            )
        }
        .padding(.leading, contentPadding)
    }
    
    func itemLoadingCoordinateView(label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Text(
                        "COORDINATE_SYSTEM".localized(userManager.userLanguage)
                    )
                    .foregroundColor(userManager.setting.textColor)
                    .font(.body)
                    .frame(
                        width: geometry.size.width * 0.4,
                        alignment: .leading
                    )
                        
                    Text("：")
                        .foregroundColor(userManager.setting.textColor)
                        .font(.body)
                        .frame(
                            width: geometry.size.width * 0.05,
                            alignment: .leading
                        )
                    
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(userManager.setting.textColor)
                        .scaleEffect(0.8)
                        .padding(-5)
                        .frame(width: 30, height: 30)
                }
            }
            .frame(minHeight: UserSession.isIPhone ? 40 : 50)
            .padding(.trailing, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    func coordinateInfoView() -> some View {
        return VStack {
            VStack(alignment: .leading, spacing: 0) {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        Text("COORDINATE_SYSTEM".localized(userManager.userLanguage))
                        .foregroundColor(userManager.setting.textColor)
                        .font(.body)
                        .frame(
                            width: geometry.size.width * 0.4,
                            alignment: .leading
                        )
                            
                        Text("：")
                            .foregroundColor(
                                userManager.setting.textColor
                            )
                            .font(.body)
                            .frame(
                                width: geometry.size.width * 0.05,
                                alignment: .leading
                            )
                        
                        Text(
                            CoordinateManager.shared
                                .getHCoordinateLabel(
                                    coordinateKey: self.coordinateJobSite?.horizontal
                                ) ?? "NONE"
                                .localized(userManager.userLanguage)
                        )
                        .foregroundColor(userManager.setting.textColor)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .frame(
                            width: geometry.size.width * 0.55,
                            alignment: .leading
                        )
                    }
                }
                .frame(minHeight: UserSession.isIPhone ? 40 : 50)
                .padding(.trailing, 18)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 0) {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        Text("VERTICAL_COORDINATE_SYSTEM".localized(userManager.userLanguage))
                        .foregroundColor(userManager.setting.textColor)
                        .font(.body)
                        .frame(
                            width: geometry.size.width * 0.4,
                            alignment: .leading
                        )
                            
                        Text("：").foregroundColor(userManager.setting.textColor)
                            .font(.body)
                            .frame(
                                width: geometry.size.width * 0.05,
                                alignment: .leading
                            )
                            
                        Text(
                            CoordinateManager.shared
                                .getVCoordinateLabel(
                                    coordinateKey: self.coordinateJobSite?.vertical
                                ) ?? "NONE"
                                .localized(userManager.userLanguage)
                        )
                        .foregroundColor(userManager.setting.textColor)
                        .multilineTextAlignment(.leading)
                        .font(.body)
                        .frame(
                            width: geometry.size.width * 0.55,
                            alignment: .leading
                        )
                    }
                }
                .frame(minHeight: UserSession.isIPhone ? 40 : 50)
                .padding(.trailing, 18)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, contentPadding)
        .padding(.bottom, UserSession.isIPhone ? 20 : 30)
    }
    
    func coordinateSystemJobsiteView() -> some View {
        return VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Text(
                        "\("COORDINATE_SYSTEM".localized(userManager.userLanguage))          :          \("COORDINATE_SYSTEM_JOBSITE".localized(userManager.userLanguage))(\(siteSelected?.name ?? ""))"
                    )
                    .foregroundColor(userManager.setting.textColor)
                    .font(.body)
                    .padding(.leading, 10)
                    .frame(alignment: .leading)
                    
                    HelpPopoverView(
                        manager: popoverManager,
                        id: "coordinate_jobsite",
                        content: """
                        Rotation          :  \((coordinateJobSite?.rotation ?? 0).string(maximumFractionDigits: 5))
                        
                        Origin easting    :  \((coordinateJobSite?.originEasting ?? 0).string(maximumFractionDigits: 5))
                        
                        Origin northing   :  \((coordinateJobSite?.originNorthing ?? 0).string(maximumFractionDigits: 5))
                        
                        Origin latitude   :  \((coordinateJobSite?.originLatitude ?? 0).string(maximumFractionDigits: 5))
                        
                        Origin longtitude :  \((coordinateJobSite?.originLongitude ?? 0).string(maximumFractionDigits: 5))
                        
                        Scale factor      :  \((coordinateJobSite?.scaleFactor ?? 0).string(maximumFractionDigits: 5))
                        
                        Vertical offset   :  \((coordinateJobSite?.verticalOffset ?? 0).string(maximumFractionDigits: 5))
                        
                        Incline X         :  \((coordinateJobSite?.inclineX ?? 0).string(maximumFractionDigits: 5))
                        
                        Incline Y         :  \((coordinateJobSite?.inclineY ?? 0).string(maximumFractionDigits: 5))
                        """,
                        frameWidth: 220,
                        frameHeight: 280,
                        offsetValue: CGSize(width: -140, height: -160),
                        icon: "",
                        onClicked: {}
                    )
                    .padding(.leading, 10)
                    .zIndex(3)
                        
                    Spacer()
                }
            }
            .frame(minHeight: 30,maxHeight: 45)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, contentPadding)
        .padding(.bottom, UserSession.isIPhone ? 10 : 20)
    }
    
    func uploadSystemSettingView() -> some View {
        HStack() {
            Text("UPLORD_SYSTEM_SETTING".localized(userManager.userLanguage))
                .foregroundColor(userManager.setting.textColor)
                .font(.body)
            
            Spacer()
            
            HelpPopoverView(
                manager: popoverManager,
                id: "upload_setting",
                content: "UPLORD_SETTING".localized(userManager.userLanguage)
                       + "\n" + "ONLY_FOLLOWING_CASES".localized(userManager.userLanguage)
                       + "\n" + "・" + "WHEN_ALIGN_TO_DASHBOARD_COORDINATE_SYSTEM".localized(userManager.userLanguage),
                frameWidth: 400,
                frameHeight: 80,
                offsetValue: CGSize(width: -235, height: -60),
                onClicked: {},
            )
            .zIndex(3)
            
            if coordinateJobSite == nil && siteSelected != nil && isGettingCoordinateJobsite == false {
                Toggle(isOn: $coordinateSettingDisable) {}
                    .frame(width: 30)
                    .padding(.trailing, 30)
                    .disabled(true)
            } else {
                Toggle(isOn: $linkDashboard){}
                    .onChange(of: linkDashboard){ checked in
                        // Dashboard連携がonなら座標系連携もon
                        if checked {coordinateSetting = true}
                    }
                    .frame(width: 30)
                    .padding(.trailing, 30)
                    .disabled(isGettingCoordinateJobsite)
            }
        }
        .padding(.bottom, UserSession.isIPhone ? 5 : 10)
    }
    
    private func andvanceButtonView() -> some View {
        Button(action: {
            withAnimation(.none) {
                addvancedSettingIsExpanded.toggle();
            }
        }, label: {
            HStack{
                Text("【" + "ADVANCED_SETTINGS".localized(userManager.userLanguage) + "】")
                    .foregroundColor(userManager.setting.textColor)
                    .font(.body)
                
                let chevronIcon = addvancedSettingIsExpanded ? "" : "";
                Text(chevronIcon)
                    .foregroundColor(userManager.setting.textColor)
                    .font(.custom(CustomFonts.FAFreeSolid, size: 20))
                    .fixedSize(horizontal: false, vertical: true)
                    .dynamicTypeSize(DynamicTypeSize.medium)
                    .frame(width: 30, height: 30)
                    .padding(.trailing, 20)
                
                Spacer()
            }
            .contentShape(Rectangle())
        })
        .buttonStyle(PlainButtonStyle())
        .padding(.bottom, UserSession.isIPhone ? 8 : 16)
    }
    
    func interpolateSettingC1View() -> some View {
        HStack() {
            Text("INTERPOLATE_SETTING_C1".localized(userManager.userLanguage))
                .font(.body)
                .foregroundColor(userManager.setting.textColor)
            
            Spacer()
            
            HelpPopoverView(
                manager: popoverManager,
                id: "interpolate_setting",
                content: "INTERPOLATE_SETTING_D1".localized(userManager.userLanguage)
                       + "\n" + "INTERPOLATE_SETTING_D2".localized(userManager.userLanguage),
                frameWidth: 400,
                frameHeight: 80,
                offsetValue: CGSize(width: -235, height: -60),
                onClicked: {}
            )
            .zIndex(3)
            
            Toggle(isOn: $shouldInterpolate){}
                .frame(width: 30)
                .padding(.trailing, 30)
                .disabled(!linkDashboard)
        }
        .padding(.bottom, UserSession.isIPhone ? 5 : 10)
        .isHidden(!addvancedSettingIsExpanded, remove: true)
        .zIndex(uploadTipIsShown ? 1 : 0)
    }
    
    func bottomButtons() -> some View {
        HStack(spacing: 20) {
            // Need to check condition like when clicking button "x"
            Button(
                action: isEdit && isInQueue ? addAction : {
                    withAnimation(.linear(duration: 0.3)) {
                        show = false
                        isPopupPresented = false
                        searchText = ""
                        projectName = ""
                    }
                },
                label: {
                    Text("CANCEL".localized(userManager.userLanguage))
                        .font(UserSession.isIPhone ? .headline.bold() : .title3.bold())
                        .foregroundColor(userManager.setting.textColor)
                        .frame(
                            height: UserSession.isIPhone ? 40 : 55,
                            alignment: .center
                        )
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .contentShape(Rectangle())
                })
            .buttonStyle(PlainButtonStyle())
            .border(.gray, width: 1)
            
            Button(action: addAction,
                label: {
                    Text("UPLOAD".localized(userManager.userLanguage))
                        .font(UserSession.isIPhone ? .headline.bold() : .title3.bold())
                        .foregroundColor(disableButton ? .gray : .white)
                        .frame(
                            height: UserSession.isIPhone ? 40 : 55,
                            alignment: .center
                        )
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .background(
                            disableButton
                            ? Color.gray.opacity(0.7)
                            : userManager.setting.buttonColor
                        )
                        .contentShape(Rectangle())
                })
            .buttonStyle(PlainButtonStyle())
            .disabled(disableButton)
        }
        .padding(.top, 10)
    }
    
    // Validate upload info to enable or disable button upload
    private func validateUpload() {
        if projectName.isEmpty {
            disableButton = true
            return
        }
        
        if !isPjNameValid {
            disableButton = true
            return
        }
        
        if self.siteSelected == nil {
            disableButton = true
            return
        }
        
        if self.coordOptionSelected == .selectManual
            && (self.hCoordSelectedKey.isEmpty
                || self.vCoordSelectedKey.isEmpty) {
            disableButton = true
            return
        }
        
        // If all case above is valid then should enalbe button upload
        disableButton = false
    }
}

extension UploadPopup {
    private func addAction() {
        guard !projectName.isEmpty else { return }
        guard let siteSelected = siteSelected else { return }
        disableButton = true
        isPopupPresented = false
        
        guard ProductUtil.validationCheck(projectName) else {
            APAlert.shared
                .showAlert(
                    title: "",
                    message: "PROHIBITED_CHARACTER_MESSAGE"
                        .localized(userManager.userLanguage),
                    buttonTitle: "CLOSE".localized(userManager.userLanguage)
                )
            disableButton = false
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.linear(duration: 0.3)) {
                show = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.disableButton = false
                }
            }
            
            if cat != nil {
                cat?.title = projectName
                cat?.jobsiteId = siteSelected.id
            }
            
            // Get coordinate by coordinate setting selected
            switch coordOptionSelected {
            case .smartAlign:
                vCoordKeyFinal = self.coordinateJobSite?.vertical ?? ""
                hCoordKeyFinal = self.coordinateJobSite?.horizontal ?? ""
            case .selectManual:
                vCoordKeyFinal = vCoordSelectedKey
                hCoordKeyFinal = hCoordSelectedKey
            default:
                vCoordKeyFinal = ""
                hCoordKeyFinal = ""
            }
            
            handler(
                siteSelected.id,
                useARMarker,
                coordinateJobSite == nil ? false : coordinateSetting,
                coordinateJobSite == nil ? false : linkDashboard,
                shouldInterpolate,
                vCoordKeyFinal,
                hCoordKeyFinal,
                cat
            )
            
            searchText = ""
            projectName = ""
        }
    }
    
    private func getCoordinateSystemJobsite(
        jobSiteId: String,
        isInitEdit: Bool
    ) {
        requestAF?.cancel()
        DispatchQueue.main.async {
            isGettingCoordinateJobsite = true
            disableButton = true
        }
        
        _ = AF.request(URL(string: Constant.baseUrl + "api/v1/sites/\(jobSiteId)")!)
            .validate()
            .responseDecodable(of: CoodinateSystemJobsite.self) { response in
                DispatchQueue.main.async {
                    self.coordinateJobSite = response.value
                    
                    // Disable radio button smartAlign if coordinate of JobSite is nil
                    isDisableSmartAlign = response.value == nil
                    
                    // Reset some data in case cannot get Site
                    if response.value == nil {
                        coordinateSetting = false
                        linkDashboard = false
                        
                        // Set default coodinate option to manual in case current option is smartAlign
                        if coordOptionSelected == CoordinateOptions.smartAlign {
                            coordOptionSelected = CoordinateOptions.selectManual
                        }
                    }
                    
                    // Init data for coordinate option in case edit project
                    if isInitEdit {
                        initCoordinateForEdit(coordJobSite: response.value)
                    }
                    
                    isGettingCoordinateJobsite = false
                    validateUpload()
                }
            }
    }
    
    private func initCoordinateForEdit(coordJobSite: CoodinateSystemJobsite?) {
        if let vCoord = cat?.vertical, !vCoord.isEmpty,
           let hCoord = cat?.horizontal, !hCoord.isEmpty {
            if coordJobSite != nil
                && vCoord == coordJobSite!.vertical
                && hCoord == coordJobSite!.horizontal {
                self.coordOptionSelected = .smartAlign
            } else {
                self.coordOptionSelected = .selectManual
                vCoordSelectedKey = vCoord
                hCoordSelectedKey = hCoord
                vCoordInputted = CoordinateManager.shared
                    .getVCoordinateLabel(coordinateKey: vCoord) ?? ""
                hCoordInputted = CoordinateManager.shared
                    .getHCoordinateLabel(coordinateKey: hCoord) ?? ""
            }
        } else {
            self.coordOptionSelected = .notConvert
        }
    }
}
