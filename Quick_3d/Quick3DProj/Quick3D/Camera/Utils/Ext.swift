//
//  Ext.swift
//  Quick3D
//
//  Created by HaNST on 5/6/25.
//

import Foundation
import SwiftUI

extension UIDevice {

    var identifier : String {
        return identifierRaw.replacingOccurrences(of: "," , with: ".")
    }
    
    var identifierRaw : String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

extension Int32 {
    var bytes: [UInt8] {
        var _value = self
        let bytePointer = withUnsafeBytes(of: &_value) { Array($0) }
        return bytePointer.reversed()
    }
}

extension Int {
    static func bytes(_ bytes: [UInt8]) -> Int {
        if bytes.count == 2 {
            var value: UInt16 = 0
            (Data(bytes) as NSData).getBytes(&value, length: 2)
            value = UInt16(bigEndian: value)
            return Int(value)
        }
        if bytes.count == 4 {
            var value: UInt32 = 0
            (Data(bytes) as NSData).getBytes(&value, length: 4)
            value = UInt32(bigEndian: value)
            return Int(value)
        }
        return 0
    }
}

extension [Float] {
    
    var bytes: [UInt8] {
        var array = [UInt8]()
        for f in self {
            array += f.bytes
        }
        return array
    }
    
}

extension Float {
    
    var bytes: [UInt8] {
        withUnsafeBytes(of: self, Array.init)
    }
    
    // Chuyển đổi Float sang Decimal một cách an toàn thông qua String
    // để tránh sai số dấu phẩy động (floating-point precision error).
    var toDecimal: Decimal {
        return Decimal(string: String(self)) ?? Decimal(Double(self))
    }
}


extension simd_float3x3 {
    var array: [Float] {
        return [columns.0[0], columns.1[0], columns.2[0],
                columns.0[1], columns.1[1], columns.2[1],
                columns.0[2], columns.1[2], columns.2[2]]
    }
    
    var raw: [[Float]] {
        return [
            [columns.0.x, columns.0.y, columns.0.z],
            [columns.1.x, columns.1.y, columns.1.z],
            [columns.2.x, columns.2.y, columns.2.z],
        ]
    }
}

extension simd_float4x4 {
    var array: [Float] {
        return [columns.0[0], columns.1[0], columns.2[0], columns.3[0],
                columns.0[1], columns.1[1], columns.2[1], columns.3[1],
                columns.0[2], columns.1[2], columns.2[2], columns.3[2],
                columns.0[3], columns.1[3], columns.2[3], columns.3[3]]
    }
    
    var raw: [[Float]] {
        return [
            [columns.0.x, columns.0.y, columns.0.z, columns.0.w],
            [columns.1.x, columns.1.y, columns.1.z, columns.1.w],
            [columns.2.x, columns.2.y, columns.2.z, columns.2.w],
            [columns.3.x, columns.3.y, columns.3.z, columns.3.w]
        ]
    }
}

extension simd_float3 {
    var raw: [Float] {
        return [x, y, z,]
    }
}


extension String {
    static func random(length: Int, letters: NSString) -> String {
        let len = UInt32(letters.length)
        var randomString = ""
        for _ in 0 ..< length {
            let rand = arc4random_uniform(len)
            var nextChar = letters.character(at: Int(rand))
            randomString += NSString(characters: &nextChar, length: 1) as String
        }
        return randomString
    }
    
    static func randomNumber(length: Int) -> String {
        return random(length: length, letters: "0123456789")
    }
    
    static func randomHexNumber(length: Int) -> String {
        return random(length: length, letters: "abcdef0123456789")
    }
}

func make_simd_float3(_ vector: simd_float4) -> simd_float3 {
    return [vector.x, vector.y, vector.z]
}

func make_simd_double3(_ vector: simd_float4) -> simd_double3 {
    return [Double(vector.x), Double(vector.y), Double(vector.z)]
}

func make_simd_float3x3(_ matrix: simd_float4x4) -> simd_float3x3 {
    return simd_float3x3(
        make_simd_float3(matrix.columns.0),
        make_simd_float3(matrix.columns.1),
        make_simd_float3(matrix.columns.2)
    )
}

extension View {
    // MARK: Building modifier for custom popups
    func popupNavigationView<Content: View>(
        show: Binding<Bool>,
        backgroundColor: Color,
        isFullScreen: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        let width = (isFullScreen  || UIDevice.current.isIphone) ? UIScreen.main.bounds.width : 700
        let height = (isFullScreen || UIDevice.current.isIphone) ? UIScreen.main.bounds.height : 500
        return self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .overlay {
                if show.wrappedValue {
                    // MARK: Reading container frame
                    GeometryReader { _ in
                        
                        Color.primary
                            .opacity(0.15)
                            .ignoresSafeArea()
                                                
                        NavigationView {
                            content()
                        }
                        .navigationViewStyle(.stack)
                        .background(backgroundColor)
                        //.border(.gray, width: 1)
                        .frame(width: width, height: height)
                        .cornerRadius(isFullScreen ? 0 : 15)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .ignoresSafeArea(isFullScreen ? .all : [])
                    }
                }
            }
    }
}

extension View {
    var phone: Bool {
        UIDevice.current.isIphone
    }
}

extension Decimal {
    var floatValue: Float {
        return NSDecimalNumber(decimal: self).floatValue
    }
    
    // Chuyển đổi Decimal sang Double.
    // Lưu ý: Double có độ chính xác thấp hơn (khoảng 15-17 chữ số thập phân),
    // nên có thể xảy ra sai số nhỏ nếu Decimal quá chi tiết.
    var toDouble: Double {
        return NSDecimalNumber(decimal: self).doubleValue
    }
}
