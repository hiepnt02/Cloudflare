//
//  RTKSearchingView.swift
//  Quick3D
//
//  Created by HaNST on 29/12/25.
//

import SwiftUI
import CoreBluetooth

struct RTKDeviceOffsetView: View {
    @EnvironmentObject private var userManager: UserManager
    
    @EnvironmentObject private var rtk: RTKStateObject
    
    @State private var offsetTypes: [CameraOffsetEnum] = []
    @State private var rtkTypes: [RTKRoverEnum] = [.viDoc, .viDocLight, .viDoc24]
    
    @State private var offsetX: String = ""
    @State private var offsetY: String = ""
    @State private var offsetZ: String = ""
    
    @FocusState private var isFocusedX: Bool
    @FocusState private var isFocusedY: Bool
    @FocusState private var isFocusedZ: Bool
    
    @State private var isOffsetValid: Bool = false
    @State private var isVidocSelected: Bool = true
    @State private var isRTKRoverValid: Bool = false
    
    private let str2DoubleFormatter: NumberFormatter = {
        var numberFormat = NumberFormatter()
        numberFormat.numberStyle = .decimal
        numberFormat.decimalSeparator = "."
        return numberFormat
    }()
    
    private let offSetViewHorizontalPadding: CGFloat = UIDevice.current.isIphone ? 12 : 40
    
    var body: some View {
        VStack(spacing: 0) {
            Text("RTK_CAMERA_OFFSET".localized(userManager.userLanguage))
                .font(.system(size: 16))
                .foregroundColor(slateGrey)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            offsetTypeView()
            
            cameraOffsetImg()
                        
            if rtk.cameraOffsetSegment == .Custom {
                if UIDevice.current.isIphone {
                    customOffsetView()
                } else {
                    customOffsetIPadView()
                }
            } else {
                offsetView()
            }
        }
        .padding(contentPadding)
        .background(userManager.setting.itemBgColor)
        .cornerRadius(8)
        .onLoad {
            setOffsetOptions()
            getOffsetValue()
            validateOffset()
        }
        .onChange(of: rtk.rtkDeviceType) { newValue in
            setOffsetOptions()
            getOffsetValue()
            validateOffset()
        }
        .onChange(of: rtk.cameraOffsetSegment) { newValue in
            getOffsetValue()
            validateOffset()
        }
    }
    
    private func setOffsetOptions() {
        offsetTypes = []
        if rtk.rtkDeviceType != .viDoc {
            offsetTypes.append(.SPCPlus)
        } else {
            // Init offset options, only add to list when have offset data
            if offsetSPC[UIDevice.current.identifierRaw] != nil {
                offsetTypes.append(.SPC)
            }
            if offsetSPCPlus[UIDevice.current.identifierRaw] != nil {
                offsetTypes.append(.SPCPlus)
            }
            if offsetCasetifySPCPlus[UIDevice.current.identifierRaw] != nil {
                offsetTypes.append(.CasetifySPCPlus)
            }
        }
        offsetTypes.append(.Custom)
        
        // Validate offsetTypeSelected to make sure offsetTypeSelected is one option of offsetTypes
        if !offsetTypes.contains(rtk.cameraOffsetSegment) {
            rtk.cameraOffsetSegment = offsetTypes.first ?? .Custom
            UserSession.shared.cameraOffsetSegment = rtk.cameraOffsetSegment
        }
    }
    
    private func getOffsetValue() {
        let offset = RTKManager.shared.mapToAntennaOffset()

        if rtk.cameraOffsetSegment == .Custom {
            offsetX = str2DoubleFormatter.string(from: NSNumber(value: offset.x)) ?? "\(offset.x)"
            offsetY = str2DoubleFormatter.string(from: NSNumber(value: offset.y)) ?? "\(offset.y)"
            offsetZ = str2DoubleFormatter.string(from: NSNumber(value: offset.z)) ?? "\(offset.z)"
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 3
            formatter.minimumFractionDigits = 2
            formatter.roundingMode = .down
            formatter.locale = Locale(identifier: "en_US_POSIX")
            
            offsetX = formatter.string(from: NSNumber(value: offset.x)) ?? "\(offset.x)"
            offsetY = formatter.string(from: NSNumber(value: offset.y)) ?? "\(offset.y)"
            offsetZ = formatter.string(from: NSNumber(value: offset.z)) ?? "\(offset.z)"
            
        }
    }
    
    private func validateOffset() {
        let isValidCustomOffset: Bool = (
            str2DoubleFormatter.number(from: offsetX) != nil &&
            str2DoubleFormatter.number(from: offsetY) != nil &&
            str2DoubleFormatter.number(from: offsetZ) != nil
        )
        
        isOffsetValid = rtk.cameraOffsetSegment != .Custom || isValidCustomOffset
        isRTKRoverValid = isVidocSelected && isOffsetValid

        if isRTKRoverValid {
            saveCustomOffset()
        }
    }
    
    private func saveCustomOffset() {
        if rtk.cameraOffsetSegment == .Custom {
            let customOffset = SIMD3(
                str2DoubleFormatter.number(from: offsetX)?.doubleValue ?? 0.0,
                str2DoubleFormatter.number(from: offsetY)?.doubleValue ?? 0.0,
                str2DoubleFormatter.number(from: offsetZ)?.doubleValue ?? 0.0
            )
            rtk.customOffsetVidoc = customOffset
            UserSession.shared.customOffsetVidoc = customOffset
        }
    }
    
    private func radio<T>(
        id: T,
        lable: String,
        isChecked: Bool,
        onSelected: @escaping (T) -> Void
    ) -> some View {
        Button {
            onSelected(id)
        } label: {
            HStack (spacing: 8) {
                Image(systemName: isChecked ? "record.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isChecked ? skyBlue : grey)
                
                Text(lable)
                    .font(.system(size: 14))
                    .foregroundColor(userManager.setting.textColor)
            }
        }
    }
    
    private func offsetTypeView() -> some View {
        Group {
            mobileDeviceInfoView()
            
            HStack {
                Text("RTK_DEVICE_TYPE".localized(userManager.userLanguage))
                    .font(.system(size: 14))
                    .foregroundColor(userManager.setting.colorTheme == .light ? abbeyGray : bombayGray)
                
                Text(rtk.rtkDeviceType.rawValue)
                    .font(.system(size: 14))
                    .foregroundColor(userManager.setting.textColor)
                
                Spacer()
            }
            .padding(.top, 8)
            
            
//            HStack(spacing: 16) {
//                ForEach(rtkTypes, id: \.self) { value in
//                    radio(
//                        id: value,
//                        lable: mapRtkTypeToString(value),
//                        isChecked: rtk.rtkDeviceType == value,
//                        onSelected: { item in
//                            withAnimation {
//                                rtk.rtkDeviceType = item
//                                UserSession.shared.rtkTypeSelected = item
//                            }
//                        }
//                    )
//                }
//                
//                Spacer()
//            }
//            .padding(.top, 4)
//            .padding(.horizontal, offSetViewHorizontalPadding)
            
            Text("RTK_OFFSET_TYPE".localized(userManager.userLanguage))
                .font(.system(size: 14))
                .foregroundColor(userManager.setting.colorTheme == .light ? abbeyGray : bombayGray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            
            HStack(spacing: UIDevice.current.isIphone ? 8 : 12) {
                ForEach(offsetTypes, id: \.self) { value in
                    Button {
                        withAnimation {
                            rtk.cameraOffsetSegment = value
                            UserSession.shared.cameraOffsetSegment = value
                        }
                    } label: {
                        VStack(alignment: .center, spacing: UIDevice.current.isIphone ? 6 : 8) {
                            Image(systemName: rtk.cameraOffsetSegment == value ? "record.circle" : "circle")
                                .font(.system(size: 18))
                                .foregroundColor(rtk.cameraOffsetSegment == value ? skyBlue : grey)
                                .padding([.top, .trailing], UIDevice.current.isIphone ? 4 : 8)
                                .frame(maxWidth: .infinity, alignment: .trailing)

                            Spacer(minLength: 0)

                            Image(imageNameForOffsetType(value))
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, UIDevice.current.isIphone ? 6 : 10)

                            Spacer(minLength: 0)

                            Text(mapOffsetTypeToString(offsetType: value))
                                .font(.system(size: 14))
                                .foregroundColor(userManager.setting.textColor)
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(userManager.setting.itemBgColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(userManager.setting.textFieldBorderColor)
                                )
                        )
                    }
                }
                ForEach(0 ..< max(0, 3 - offsetTypes.count), id: \.self) { _ in
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
            .padding(.bottom, 24)
            .padding(.horizontal, offSetViewHorizontalPadding)
        }
    }
    
    private func cameraOffsetImg() -> some View {
        return Group {
            if rtk.cameraOffsetSegment == .Custom {
                if UIDevice.current.isIphone {
                    Image("img_custom")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                } else {
                    Image("img_custom_ipad")
                        .resizable()
                        .scaledToFit()
                }
            }
        }
        .padding(.horizontal, offSetViewHorizontalPadding)
    }
    
    private func mobileDeviceInfoView() -> some View {
        HStack {
            Text("DEVICE".localized(userManager.userLanguage))
                .font(.system(size: 14))
                .foregroundColor(userManager.setting.colorTheme == .light ? abbeyGray : bombayGray)
            
            Text("\(UIDevice.modelName)")
                .font(.system(size: 14))
                .foregroundColor(userManager.setting.textColor)
            
            Spacer()
        }
        .padding(.top, 12)
    }
    
    private func mapOffsetTypeToString(offsetType: CameraOffsetEnum) -> String {
        switch offsetType {
        case .SPC:
            return "SPC"
        case .SPCPlus:
            return "SPC+"
        case .CasetifySPCPlus:
            return "Casetify SPC+"
        case .Custom:
            return "RTK_CAMERA_OFFSET_CUSTOM".localized(userManager.userLanguage)
        }
    }
    
    private func imageNameForOffsetType(_ offsetType: CameraOffsetEnum) -> String {
        switch offsetType {
        case .SPC:
            return "img_spc"
        case .SPCPlus, .CasetifySPCPlus:
            return "img_spc+"
        case .Custom:
            return UIDevice.current.isIphone ? "img_custom" : "img_custom_ipad"
        }
    }

    private func mapRtkTypeToString(_ rtkType: RTKRoverEnum) -> String {
        switch rtkType {
        case .viDoc:
            return "viDoc"
        case .viDoc24:
            return "viDoc 24"
        case .viDocLight:
            return "viDoc Light"
        }
    }
    
    private func line(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        Divider()
            .frame(width: width, height: height)
            .background(userManager.setting.colorTheme == .light ? lightGray : .white)
    }
    
    private func offsetView() -> some View {
        Group {
            Text("RTK_CAMERA_OFFSET_COORDINATE".localized(userManager.userLanguage))
                .font(.system(size: 14))
                .foregroundColor(userManager.setting.colorTheme == .light ? abbeyGray : bombayGray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 16)
            
            HStack {
                offsetItemView(title: "X[m]", value: offsetX, offsetItemPosition: .X)
                
                line(width: 1, height: 16)
                
                offsetItemView(title: "Y[m]", value: offsetY, offsetItemPosition: .Y)
                
                line(width: 1, height: 16)
                
                offsetItemView(title: "Z[m]", value: offsetZ, offsetItemPosition: .Z)
            }
            .padding(.top, 8)
            .padding(.horizontal, offSetViewHorizontalPadding)
        }
    }
    
    private func customOffsetView() -> some View {
        VStack(spacing: 8) {
            itemOffsetField(title: "X[m]", inputValue: $offsetX, focused: $isFocusedX)
            
            line(height: 1)
            
            itemOffsetField(title: "Y[m]", inputValue: $offsetY, focused: $isFocusedY)
            
            line(height: 1)
            
            itemOffsetField(title: "Z[m]", inputValue: $offsetZ, focused: $isFocusedZ)
        }
        .padding(.top, 24)
        .padding(.leading, offSetViewHorizontalPadding)
    }
    
    private func customOffsetIPadView() -> some View {
        HStack(spacing: 8) {
            itemOffsetFieldIpad(title: "X[m]", inputValue: $offsetX, focused: $isFocusedX)
            
            line(width: 1, height: 34)
            
            itemOffsetFieldIpad(title: "Y[m]", inputValue: $offsetY, focused: $isFocusedY)
            
            line(width: 1, height: 34)
            
            itemOffsetFieldIpad(title: "Z[m]", inputValue: $offsetZ, focused: $isFocusedZ)
        }
        .padding(.top, 24)
        .padding(.leading, offSetViewHorizontalPadding)
    }
    
    private func itemOffsetField(
        title: String,
        inputValue: Binding<String>,
        focused: FocusState<Bool>.Binding
    ) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(userManager.setting.textColor)
            
            Spacer()
            
            TextField("0.00", text: inputValue)
                .keyboardType(.numbersAndPunctuation)
                .font(.system(size: 16))
                .foregroundColor(userManager.setting.colorTheme == .light ? Color.black : Color.white)
                .frame(height: 34)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 2).fill( userManager.setting.colorTheme == .light ? Color.white : abbeyGray)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 2).stroke(steelGray, lineWidth: 1)
                )
                .onChange(of: inputValue.wrappedValue) { newValue in
                    inputValue.wrappedValue = newValue.forcedFormatNumber()
                }
                .focused(focused)
                .onChange(of: focused.wrappedValue) { newValue in
                    if !newValue {
                        if inputValue.wrappedValue.isEmpty || str2DoubleFormatter.number(from: inputValue.wrappedValue) == 0 {
                            inputValue.wrappedValue = "0.00"
                        }
                        validateOffset()
                    } else {
                        rtk.customOffsetVidoc = .zero
                    }
                }
        }
    }
    
    private func itemOffsetFieldIpad(
        title: String,
        inputValue: Binding<String>,
        focused: FocusState<Bool>.Binding
    ) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(userManager.setting.textColor)
                .padding(.leading, 8)
                .padding(.trailing, 24)
            
            TextField("0.000", text: inputValue)
                .keyboardType(.numbersAndPunctuation)
                .font(.system(size: 16))
                .foregroundColor(userManager.setting.colorTheme == .light ? Color.black : Color.white)
                .frame(height: 34)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 2).fill( userManager.setting.colorTheme == .light ? Color.white : abbeyGray)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 2).stroke(steelGray, lineWidth: 1)
                )
                .onChange(of: inputValue.wrappedValue) { newValue in
                    inputValue.wrappedValue = newValue.forcedFormatNumber()
                }
                .focused(focused)
                .onChange(of: focused.wrappedValue) { newValue in
                    if !newValue {
                        if inputValue.wrappedValue.isEmpty || str2DoubleFormatter.number(from: inputValue.wrappedValue) == 0 {
                            inputValue.wrappedValue = "0.000"
                        }
                        validateOffset()
                    } else {
                        rtk.customOffsetVidoc = .zero
                    }
                }
        }
    }
    
    private func offsetItemView(title: String, value: String, offsetItemPosition: OffsetItemPosition) -> some View {
        Group {
            if offsetItemPosition != .X {
                Spacer()
            }
             
            
            HStack(spacing: 0) {
                Text("\(title) ")
                    .font(.system(size: 16))
                    .foregroundColor(userManager.setting.textColor)
                
                Text("\(Double(value) ?? 0, specifier: "%.3f")")
                    .lineLimit(1)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(userManager.setting.textColor)
            }
            
            if offsetItemPosition != .Z {
                Spacer()
            }
        }
    }
}

enum OffsetItemPosition {
    case X
    case Y
    case Z
}
