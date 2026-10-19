//
//  ARSettingDetailView.swift
//  Quick3D
//
//  Created by HungNT on 8/1/26.
//

import SwiftUI
import UIKit

struct ARSettingDetailView: View {
    @EnvironmentObject private var userManager: UserManager
    var context: ViewARContext? = nil
    
    @ObservedObject var arPosition: ARPosition
    
    @Binding var isShow: Bool
    @Binding var isPointCloudVisible: Bool
    @Binding var isPointCloudRendered: Bool
    @Binding var pointCloudScale: Double
    var pointCloudOpacity: CGFloat = 1.0
    
    @State private var selectedTab = 0
    @State private var lasLevel: CGFloat = 1.0
    
    @State private var inputTextX: String = ""
    @State private var inputTextY: String = ""
    @State private var inputTextZ: String = ""
    @State private var inputTextYaw: String = ""
    @State private var inputTextScale: String = ""
    
    @State private var posHisMaxSize: String = ""
    @State private var posHisHorizontal: String = ""
    @State private var posHisDistance: String = ""
    
    @State private var posHisSize: String = ""
    
    @State private var posAccuracy: String = ""
    
    @Binding var isLightOn: Bool
    @Binding var isARPositionExpanded: Bool
    @Binding var isARStepExpanded: Bool
    @Binding var isUpdateAROn: Bool
    
    enum Field: Hashable {
        case posX, posY, posZ, posYaw, hoz, distance, posScale
    }

    @FocusState private var focusedField: Field?
    
    private let tabs = currentEnvironment == .dev ? ["POSITION_SETTING", "DISPLAY_SETTINGS", "CALCULATION_SETTING"] : ["POSITION_SETTING", "DISPLAY_SETTINGS"]
    private let characterLimit = 15
    
    private static let sharedFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .none // Sử dụng kiểu decimal để có dấu phẩy ngăn cách
        
        // Cấu hình phần thập phân
        formatter.maximumFractionDigits = 5
        formatter.minimumFractionDigits = 0 // Không hiển thị .00 nếu là số nguyên
        
        // Cấu hình phần phân cách hàng ngàn (Quan trọng)
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        
        formatter.minimumIntegerDigits = 1
        formatter.zeroSymbol = "0"
        formatter.roundingMode = .halfUp
        
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: Tab Header
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(0..<tabs.count, id: \.self) { index in
                            Button(action: {
                                withAnimation(.spring()) { selectedTab = index }
                            }) {
                                VStack(spacing: 4) {
                                    Text(tabs[index].localized(userManager.userLanguage))
                                        .font(.system(size: 16))
                                        .fontWeight(selectedTab == index ? .bold : .regular)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                    
                                    Rectangle()
                                        .fill(selectedTab == index ? .white : Color.clear)
                                        .frame(height: 2)
                                }
                            }
                        }
                    }
                    .fixedSize()
                }
                
                Spacer()
                
                Button(action: { isShow = false }) {
                    Image("closeIcon")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.bottom, 8)

            // MARK: Main Content
            ZStack {
                switch selectedTab {
                case 0: positionSettingView()
                case 1: pointCloudSettingView()
                case 2: calculationSettingView()
                default: EmptyView()
                }
            }
        }
        .padding(EdgeInsets(top: 8, leading: 16, bottom: 6, trailing: 16))
        .glassBackground()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            syncDataToUI()
        }
        // Chỉ sync khi tab Position (0) đang mở và giá trị thực tế thay đổi
        .onChange(of: arPosition.positionXMm) { _ in
            if selectedTab == 0 { syncDataToUI() }
        }
        .onChange(of: arPosition.positionYMm) { _ in
            if selectedTab == 0 { syncDataToUI() }
        }
        .onChange(of: arPosition.positionZMm) { _ in
            if selectedTab == 0 { syncDataToUI() }
        }
        .onChange(of: arPosition.eulerAnglesYDecimal) { _ in
            if selectedTab == 0 { syncDataToUI() }
        }
        .onChange(of: arPosition.scaleDecimal) { _ in
            if selectedTab == 0 { syncDataToUI() }
        }
        // Quan trọng: Khi người dùng chuyển tab về Position, phải sync ngay lập tức
        .onChange(of: selectedTab) { newValue in
            if newValue == 0 {
                syncDataToUI()
            }
        }
        .onChange(of: context?.calculateAccuracy) { _ in
            if selectedTab == 2 { syncDataToUI() }
        }

    }
    
    // MARK: - View Sections
    private func positionSettingView() -> some View {
        VStack(alignment: .leading) {
            HStack(spacing: 8) {
                Text("CHANGE_AMOUNT".localized(userManager.userLanguage))
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                changeAmountMenuView()
            }
            
            itemOffsetDivider
            
            itemOffsetView(label: "X[mm]", for: $arPosition.positionXMm, textState: $inputTextX, focus: .posX, labelColor: .red)
            itemOffsetDivider
            
            itemOffsetView(label: "Y[mm]", for: $arPosition.positionZMm, textState: $inputTextY, focus: .posY, labelColor: .blue)
            itemOffsetDivider
            
            itemOffsetView(label: "Z[mm]", for: $arPosition.positionYMm, textState: $inputTextZ, focus: .posZ, labelColor: .green)
            itemOffsetDivider
            
            itemOffsetView(label: "Yaw[°]", for: $arPosition.eulerAnglesYDecimal, textState: $inputTextYaw, focus: .posYaw, isDegree: true)
            itemOffsetDivider
            
            itemOffsetView(label: "SCALE".localized(userManager.userLanguage) + "[%]", for: $arPosition.scaleDecimal, textState: $inputTextScale, focus: .posScale, isScale: true)
        }
    }
    
    private var itemOffsetDivider: some View {
        Divider().frame(height: 1).background(.white.opacity(0.3))
    }
    
    private func settingToggle(label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.white)
            Spacer()
            CustomToggle(isOn: isOn)
                .padding(.leading, 8)
        }
    }

    
    private func pointCloudSettingView() -> some View {
        VStack(alignment: .leading) {
            if isARPositionExpanded {
                settingToggle(
                    label: "AR_UPDATED".localized(userManager.userLanguage),
                    isOn: Binding(
                            get: { isUpdateAROn },
                            set: { newValue in
                                isUpdateAROn = newValue
                                context?.perform(ViewARAllowCalculateEvent(newValue))
                            }
                        )
                )
                .padding(.vertical, 4)
                
                Rectangle().fill(Color.white.opacity(0.3)).frame(height: 1)
            }
            
            settingToggle(
                label: "OCCLUSION".localized(userManager.userLanguage),
                isOn: Binding(
                    get: { userManager.isAROcclusion },
                    set: { newValue in
                        context?.perform(ViewAROcclusionEvent(newValue))
                        userManager.isAROcclusion = newValue
                    }
                )
            )
            .padding(.vertical, 4)
            
            Rectangle().fill(Color.white.opacity(0.3)).frame(height: 1)
            
            settingToggle(
                label: "PLANE_GRID".localized(userManager.userLanguage),
                isOn: Binding(
                    get: { userManager.isARPlaneGrid },
                    set: { newValue in
                        context?.perform(ViewARPlaneGridEvent(newValue))
                        userManager.isARPlaneGrid = newValue
                    }
                )
            )
            .padding(.vertical, 4)
            
            Rectangle().fill(Color.white.opacity(0.3)).frame(height: 1)
            
            if isARPositionExpanded {
                settingToggle(
                    label: "SHADOW".localized(userManager.userLanguage),
                    isOn: Binding(
                            get: { isLightOn },
                            set: { newValue in
                                isLightOn = newValue
                            }
                        )
                )
                .padding(.vertical, 4)
                
                Rectangle().fill(Color.white.opacity(0.3)).frame(height: 1)
            }
            
            ARVisibleScaleView(
                title: "POINTCLOUD_SIZE".localized(userManager.userLanguage),
                isVisible: isPointCloudVisible,
                scale: Binding(get: { CGFloat(pointCloudScale) }, set: { pointCloudScale = Double($0) }),
                onVisibilityChanged: { visible in
                    isPointCloudVisible = visible
                    context?.perform(ViewARPointcloudVisibleEvent(visible))
                },
                onScaleChanged: { scale in
                    pointCloudScale = Double(scale)
                    context?.perform(ViewARChangePointCloudSizeEvent(Double(scale)))
                },
                isVisibilityLocked: ViewARVisibilityLock.isLocked(isPointCloudVisible, pointCloudOpacity)
            )
            
            if currentEnvironment == .dev && isPointCloudRendered {
                lasLevelSettingView()
            }
        }
    }
    
    private func lasLevelSettingView() -> some View {
        HStack(alignment: .top) {
            Text("LAS_LEVEL".localized(userManager.userLanguage))
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(.bottom, 8)
            
            VStack {
                CameraSlider(
                    value: $lasLevel,
                    range: 1...4,
                    trackHeight: 8,
                    bgTrackColor: lightGray,
                    activeTrackColor: lavender,
                    strokeDotColor: lavender,
                    dotSize: 24
                )
                .onChange(of: lasLevel) { newValue in
                    UserSession.shared.lasLevel = Int(newValue)
                }

                HStack {
                    Text("1"); Spacer(); Text("2"); Spacer(); Text("3"); Spacer(); Text("4")
                }
                .font(.system(size: 12))
                .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
        }
        .onAppear {
            lasLevel = CGFloat(UserSession.shared.lasLevel)
        }
    }
    
    private func calculationSettingView() -> some View {
        VStack(alignment: .leading) {
            HStack(spacing: 8) {
                Text("SIZE".localized(userManager.userLanguage))
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                Spacer()
                
                TextField("", text: $posHisMaxSize)
                    .foregroundColor(slateGrey)
                    .keyboardType(.numberPad)
                    .modifier(TextFieldBackgroundModifier(abbeyGray: abbeyGray.opacity(0.6)))
                    .onChange(of: posHisMaxSize) { newValue in
                        let filtered = newValue.filter { "0123456789".contains($0) }
                        posHisMaxSize = String(filtered.prefix(characterLimit))
                        UserSession.shared.posHisMaxSize = Int(posHisMaxSize) ?? 0
                        updateCalculationSetting()
                    }
            }
            .frame(maxWidth: .infinity)
            
            itemCalculationView(label: "HORIZONTAL".localized(userManager.userLanguage), input: $posHisHorizontal, focus: .hoz) { val in
                UserSession.shared.posHisHorizontal = val.toDouble
                updateCalculationSetting()
            }
            
            itemCalculationView(label: "DISTANCE".localized(userManager.userLanguage), input: $posHisDistance, focus: .distance) { val in
                UserSession.shared.posHisDistance = val.toDouble
                updateCalculationSetting()
            }
            HStack(spacing: 8) {
                Text("SIZE".localized(userManager.userLanguage))
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                Spacer()
                
                Text(posHisSize)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            HStack(spacing: 8) {
                Text("ACCURACY".localized(userManager.userLanguage))
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                Spacer()
                
                Text(posAccuracy)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            posHisMaxSize = "\(UserSession.shared.posHisMaxSize)"
            posHisHorizontal = "\(UserSession.shared.posHisHorizontal)"
            posHisDistance = "\(UserSession.shared.posHisDistance)"
            posAccuracy = String(format: "%.4f", context?.calculateAccuracy ?? 0.0) + " m"
            posHisSize =  String(format: "%d", context?.positionHistories.filter{ $0.offset != nil }.count ?? 0)
            
        }
    }

    // MARK: - Reusable Components
    private func changeAmountMenuView() -> some View {
        Button {
            hideKeyboard()
            withAnimation(.easeInOut(duration: 0.15)) {
                isARStepExpanded.toggle()
            }
        } label: {
            ZStack {
                Text(arPosition.currentStep.getText(userManager.userLanguage))
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                HStack {
                    Spacer()
                    Image("arrowDown")
                        .renderingMode(.template)
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isARStepExpanded ? 180 : 0))
                }
            }
            .padding(.horizontal, 8)
            .frame(width: UIDevice.current.isIphone ? 120 : 210, height: 25)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(abbeyGray.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .anchorPreference(key: ARStepPulldownAnchorKey.self, value: .bounds) { anchor in
            anchor
        }
        .padding(.trailing, 28)
    }
    
    private func itemOffsetView(
        label: String,
        for input: Binding<Decimal>,
        textState: Binding<String>,
        focus: Field,
        isDegree: Bool = false,
        isScale: Bool = false,
        labelColor: Color = .white
    ) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 16)).foregroundColor(labelColor)
            Spacer()
            Button(action: {
                let step = isDegree ? arPosition.currentStep.getDegree() : arPosition.currentStep.getStepValue()
                if isScale {
                    if (input.wrappedValue - step) < 1 {
                        input.wrappedValue = 1
                    } else {
                        input.wrappedValue -= step
                    }
                } else {
                    input.wrappedValue -= step
                }
                textState.wrappedValue = formatDecimal(input.wrappedValue)
                triggerPositionUpdate()
            }) {
                Image(systemName: "minus.circle").foregroundColor(lightGray)
            }
            
            textFieldDecimal(input: textState, focus: focus, isScale: isScale) { newValue in
                if input.wrappedValue != newValue {
                    input.wrappedValue = newValue
                    triggerPositionUpdate()
                }
            }
            
            Button(action: {
                input.wrappedValue += isDegree ? arPosition.currentStep.getDegree() : arPosition.currentStep.getStepValue()
                textState.wrappedValue = formatDecimal(input.wrappedValue)
                triggerPositionUpdate()
            }) {
                Image(systemName: "plus.circle").foregroundColor(lightGray)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func textFieldDecimal(
        input: Binding<String>,
        focus: Field,
        isScale: Bool = false,
        onInputted: @escaping (Decimal) -> Void
    ) -> some View {
        TextField("", text: input)
            .focused($focusedField, equals: focus)
            .foregroundColor(slateGrey)
            .keyboardType(.numbersAndPunctuation)
            .modifier(TextFieldBackgroundModifier(abbeyGray: abbeyGray.opacity(0.6)))
            .onChange(of: input.wrappedValue) { newValue in
                // 1. Chỉ cho phép các ký tự số, dấu chấm và dấu trừ (cho số âm, nếu là scale thì không cho phép dấu trừ "-")
                let allowedChars = isScale ? "0123456789." : "0123456789.-"
                let filtered = newValue.filter { allowedChars.contains($0) }
                
                // 2. Chặn việc nhập quá giới hạn ký tự
                if filtered.count <= characterLimit {
                    // 3. Convert thẳng sang Decimal để đồng bộ với logic bên ngoài
                    if let decimalValue = Decimal(string: filtered) {
                        if isScale && decimalValue < 1{
                            onInputted(1)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                if input.wrappedValue != formatDecimal(1) {
                                    input.wrappedValue = formatDecimal(1)
                                }
                            }
                        } else {
                            onInputted(decimalValue)
                        }
                    }
                }
            }
    }
    
    private func itemCalculationView(
        label: String,
        input: Binding<String>,
        focus: Field,
        onTextInputted: @escaping (Decimal) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 16)).foregroundColor(.white)
            Spacer()
            textFieldDecimal(input: input, focus: focus, onInputted: onTextInputted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers
    private func syncDataToUI() {
        let newX = formatDecimal(arPosition.positionXMm)
        let newY = formatDecimal(arPosition.positionZMm)
        let newZ = formatDecimal(arPosition.positionYMm)
        let newYaw = formatDecimal(arPosition.eulerAnglesYDecimal)
        let newAccuracy = String(format: "%.4f", context?.calculateAccuracy ?? 0.0) + " m"
        let newSize = String(format: "%d", context?.positionHistories.filter{ $0.offset != nil }.count ?? 0)
        
        // Chỉ cập nhật String nếu giá trị số học thay đổi
        // (giúp giữ nguyên trạng thái TextField khi người dùng đang gõ)
        if Decimal(string: inputTextX) != arPosition.positionXMm {
            inputTextX = newX
        }
        if Decimal(string: inputTextY) != arPosition.positionZMm {
            inputTextY = newY
        }
        if Decimal(string: inputTextZ) != arPosition.positionYMm {
            inputTextZ = newZ
        }
        if Decimal(string: inputTextYaw) != arPosition.eulerAnglesYDecimal {
            inputTextYaw = newYaw
        }
        if newAccuracy != posAccuracy {
            posAccuracy = newAccuracy
            posHisSize = newSize
        }

        let actualScale = max(1, arPosition.scaleDecimal)
        let newScaleStr = formatDecimal(actualScale)
        
        if inputTextScale != newScaleStr {
            inputTextScale = newScaleStr
        }
    }
    
    private func formatDecimal(_ value: Decimal) -> String {
        // Ép kiểu Decimal sang NSDecimalNumber trước khi đưa vào formatter
        return Self.sharedFormatter.string(from: value as NSDecimalNumber) ?? ""
    }
    
    private func triggerPositionUpdate() {
        arPosition.updateUserSessionAndEvent { pos, eulerAngles, scale in
            context?.perform(ViewARUpdatePositionEvent(pos, eulerAngles, scale))
        }
    }
    
    private func updateCalculationSetting() {
        context?.perform(ViewARCalculationSettingEvent(
            positionHistoryMaxSize: UserSession.shared.posHisMaxSize,
            positionHistoryHorizontal: UserSession.shared.posHisHorizontal,
            positionHistoryDistance: UserSession.shared.posHisDistance
        ))
    }
}

// MARK: - Blur View
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// MARK: - Glass Background
extension View {
    func glassBackground(radius: CGFloat = 16) -> some View {
        self
            .background(
                ZStack {
                    BlurView(style: .systemUltraThinMaterialDark)
                        .opacity(0.7)
                    LinearGradient(
                        colors: [imperialBlue.opacity(0.42), steelBlue.opacity(0.42)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: radius))
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

// MARK: - UI Modifier
struct TextFieldBackgroundModifier: ViewModifier {
    let abbeyGray: Color // Truyền màu vào để tránh lỗi scope
    
    func body(content: Content) -> some View {
        content
            .frame(width: UIDevice.current.isIphone ? 110 : 200)
            .padding(.horizontal, 5)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(abbeyGray)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}
