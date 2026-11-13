//
//  Constants.swift
//  Quick3D
//
//  Created by HungNT on 14/10/25.
//

import Foundation
import VigramSDK
import SwiftUI

// MARK: Name EventBus
let eventDownloadLas = "DownloadProjectEvent"
let eventCloseCammera = "CloseCameraEvent"

// MARK: SCNNode Names
let nameLasNode = "LAS Node"
let nameUSDZNode = "USDZ Node"

let defaultCoordinate: String = "EPSG:4326"

let pixelSize = 2.6 * 0.001

// MARK: RTK Offset Values
let offsetSPC: [String: SIMD3<Double>] = [
    "iPhone13,3": SIMD3<Double>(0.044, -0.016, 0.02), // Iphone 12 Pro
    "iPhone13,4": SIMD3<Double>(0.045, -0.026, 0.02), // Iphone 12 Pro Max
    "iPhone14,2": SIMD3<Double>(0.043, -0.036, 0.02), // Iphone 13 Pro
    "iPhone14,3": SIMD3<Double>(0.046, -0.03, 0.02), // Iphone 13 Pro Max
    "iPhone15,2": SIMD3<Double>(0.041, -0.037, 0.02), // Iphone 14 Pro
    "iPhone15,3": SIMD3<Double>(0.045, -0.032, 0.02), // Iphone 14 Pro Max
    "iPad8,9": SIMD3<Double>(-0.035, 0.081, 0.026), // Ipad Pro 11 inch (2nd)
    "iPad8,10": SIMD3<Double>(-0.035, 0.081, 0.026), // Ipad Pro 11 inch (2nd)
    "iPad13,4": SIMD3<Double>(-0.035, 0.081, 0.026), // Ipad Pro 11 inch (3rd)
    "iPad13,5": SIMD3<Double>(-0.035, 0.081, 0.026), // Ipad Pro 11 inch (3rd)
    "iPad13,6": SIMD3<Double>(-0.035, 0.081, 0.026), // Ipad Pro 11 inch (3rd)
    "iPad13,7": SIMD3<Double>(-0.035, 0.081, 0.026), // Ipad Pro 11 inch (3rd)
    "iPad14,3": SIMD3<Double>(-0.035, 0.081, 0.026), // Ipad Pro 11 inch (4th)
    "iPad14,4": SIMD3<Double>(-0.035, 0.081, 0.026), // Ipad Pro 11 inch (4th)
]

let offsetSPCPlus: [String: SIMD3<Double>] = [
    "iPhone13,3": SIMD3<Double>(0.056, -0.007, 0.019), // Iphone 12 Pro
    "iPhone13,4": SIMD3<Double>(0.058, -0.019, 0.018), // Iphone 12 Pro Max
    "iPhone14,2": SIMD3<Double>(0.054, -0.026, 0.017), // Iphone 13 Pro
    "iPhone14,3": SIMD3<Double>(0.058, -0.019, 0.017), // Iphone 13 Pro Max
    "iPhone15,2": SIMD3<Double>(0.053, -0.028, 0.017), // Iphone 14 Pro
    "iPhone15,3": SIMD3<Double>(0.057, -0.021, 0.017), // Iphone 14 Pro Max
    "iPhone16,1": SIMD3<Double>(0.053, -0.028, 0.017), // Iphone 15 Pro
    "iPhone16,2": SIMD3<Double>(0.056, -0.022, 0.017), // Iphone 15 Pro Max
    "iPhone17,1": SIMD3<Double>(0.054, -0.027, 0.018), // Iphone 16 Pro
    "iPhone17,2": SIMD3<Double>(0.057, -0.02, 0.018), // Iphone 16 Pro Max
]

let offsetCasetifySPCPlus: [String: SIMD3<Double>] = [
    "iPad8,9": SIMD3<Double>(-0.019, 0.067, 0.021), // Ipad Pro 11inch (2nd)
    "iPad8,10": SIMD3<Double>(-0.019, 0.067, 0.021), // Ipad Pro 11inch (2nd)
    "iPad13,4": SIMD3<Double>(-0.019, 0.067, 0.021), // Ipad Pro 11inch (3rd)
    "iPad13,5": SIMD3<Double>(-0.019, 0.067, 0.021), // Ipad Pro 11inch (3rd)
    "iPad13,6": SIMD3<Double>(-0.019, 0.067, 0.021), // Ipad Pro 11inch (3rd)
    "iPad13,7": SIMD3<Double>(-0.019, 0.067, 0.021), // Ipad Pro 11inch (3rd)
    "iPad14,3": SIMD3<Double>(-0.019, 0.067, 0.021), // Ipad Pro 11inch (4th)
    "iPad14,4": SIMD3<Double>(-0.019, 0.067, 0.021), // Ipad Pro 11inch (4th)
    
    "iPad13,8": SIMD3<Double>(-0.019, 0.082, 0.021), // Ipad Pro 12inch (5th)
    "iPad13,9": SIMD3<Double>(-0.019, 0.082, 0.021), // Ipad Pro 12inch (5th)
    "iPad13,10": SIMD3<Double>(-0.019, 0.082, 0.021), // Ipad Pro 12inch (5th)
    "iPad13,11": SIMD3<Double>(-0.019, 0.082, 0.021), // Ipad Pro 12inch (5th)
    "iPad14,5": SIMD3<Double>(-0.019, 0.082, 0.021), // Ipad Pro 12inch (6th)
    "iPad14,6": SIMD3<Double>(-0.019, 0.082, 0.021), // Ipad Pro 12inch (6th)
    
    "iPad16,3": SIMD3<Double>(-0.019, 0.078, 0.021), // Ipad Pro 11inch M4
    "iPad16,4": SIMD3<Double>(-0.019, 0.078, 0.021), // Ipad Pro 11inch M4
    
    "iPad16,5": SIMD3<Double>(-0.019, 0.094, 0.021), // Ipad Pro 13inch M4
    "iPad16,6": SIMD3<Double>(-0.019, 0.094, 0.021), // Ipad Pro 13inch M4
    
    "iPad17,1": SIMD3<Double>(-0.019, 0.078, 0.021), // Ipad Pro 11inch M5
    "iPad17,2": SIMD3<Double>(-0.019, 0.078, 0.021), // Ipad Pro 11inch M5
    
    "iPad17,3": SIMD3<Double>(-0.019, 0.094, 0.021), // Ipad Pro 13inch M5
    "iPad17,4": SIMD3<Double>(-0.019, 0.094, 0.021), // Ipad Pro 13inch M5
]
    
let offsetVidoc24 = originalOffsetVidoc24.mapValues { $0 * SIMD3<Double>(-1, 1, 1) }
let originalOffsetVidoc24: [String: SIMD3<Double>] = [
    "iPhone13,3": VigramSDK.AntennaOffset.SPCPlus.iPhone12ProBottom, // Iphone 12 Pro
    "iPhone13,4": VigramSDK.AntennaOffset.SPCPlus.iPhone12ProMaxBottom, // Iphone 12 Pro Max
    "iPhone14,2": VigramSDK.AntennaOffset.SPCPlus.iPhone13ProBottom, // Iphone 13 Pro
    "iPhone14,3": VigramSDK.AntennaOffset.SPCPlus.iPhone13ProMaxBottom, // Iphone 13 Pro Max
    "iPhone15,2": VigramSDK.AntennaOffset.SPCPlus.iPhone14ProBottom, // Iphone 14 Pro
    "iPhone15,3": VigramSDK.AntennaOffset.SPCPlus.iPhone14ProMaxBottom, // Iphone 14 Pro Max
    "iPhone16,1": VigramSDK.AntennaOffset.SPCPlus.iPhone15ProBottom, // Iphone 15 Pro
    "iPhone16,2": VigramSDK.AntennaOffset.SPCPlus.iPhone15ProMaxBottom, // Iphone 15 Pro Max
    "iPhone17,1": VigramSDK.AntennaOffset.SPCPlus.iPhone16ProBottom, // Iphone 16 Pro
    "iPhone17,2": VigramSDK.AntennaOffset.SPCPlus.iPhone16ProMaxBottom, // Iphone 16 Pro Max
    "iPad8,9": VigramSDK.AntennaOffset.SPCPlus.iPadPro11Middle, // Ipad Pro 11 inch (2nd gen)
    "iPad8,10": VigramSDK.AntennaOffset.SPCPlus.iPadPro11Middle, // Ipad Pro 11 inch (2nd gen)
    "iPad13,4": VigramSDK.AntennaOffset.SPCPlus.iPadPro11Middle, // Ipad Pro 11 inch (3nd gen)
    "iPad13,5": VigramSDK.AntennaOffset.SPCPlus.iPadPro11Middle, // Ipad Pro 11 inch (3nd gen)
    "iPad13,6": VigramSDK.AntennaOffset.SPCPlus.iPadPro11Middle, // Ipad Pro 11 inch (3nd gen)
    "iPad13,7": VigramSDK.AntennaOffset.SPCPlus.iPadPro11Middle, // Ipad Pro 11 inch (3nd gen)
    "iPad14,3": VigramSDK.AntennaOffset.SPCPlus.iPadPro11Middle, // Ipad Pro 11 inch (M2)
    "iPad14,4": VigramSDK.AntennaOffset.SPCPlus.iPadPro11Middle, // Ipad Pro 11 inch (M2)
    "iPad16,3": VigramSDK.AntennaOffset.SPCPlus.iPadPro11Middle, // Ipad Pro 11 inch (M4)
    "iPad16,4": VigramSDK.AntennaOffset.SPCPlus.iPadPro11Middle, // Ipad Pro 11 inch (M4)
]

let offsetVidocLight = originalOffsetVidocLight.mapValues { $0 * SIMD3<Double>(-1, 1, 1) }
let originalOffsetVidocLight: [String: SIMD3<Double>] = [
    "iPhone13,3": VigramSDK.AntennaOffset.SPCPlusLight.iPhone12ProBottom, // Iphone 12 Pro
    "iPhone13,4": VigramSDK.AntennaOffset.SPCPlusLight.iPhone12ProMaxBottom, // Iphone 12 Pro Max
    "iPhone14,2": VigramSDK.AntennaOffset.SPCPlusLight.iPhone13ProBottom, // Iphone 13 Pro
    "iPhone14,3": VigramSDK.AntennaOffset.SPCPlusLight.iPhone13ProMaxBottom, // Iphone 13 Pro Max
    "iPhone15,2": VigramSDK.AntennaOffset.SPCPlusLight.iPhone14ProBottom, // Iphone 14 Pro
    "iPhone15,3": VigramSDK.AntennaOffset.SPCPlusLight.iPhone14ProMaxBottom, // Iphone 14 Pro Max
    "iPhone16,1": VigramSDK.AntennaOffset.SPCPlusLight.iPhone15ProBottom, // Iphone 15 Pro
    "iPhone16,2": VigramSDK.AntennaOffset.SPCPlusLight.iPhone15ProMaxBottom, // Iphone 15 Pro Max
    "iPhone17,1": VigramSDK.AntennaOffset.SPCPlusLight.iPhone16ProBottom, // Iphone 16 Pro
    "iPhone17,2": VigramSDK.AntennaOffset.SPCPlusLight.iPhone16ProMaxBottom, // Iphone 16 Pro Max
    "iPad8,9": VigramSDK.AntennaOffset.SPCPlusLight.iPadPro11Middle, // Ipad Pro 11 inch (2nd gen)
    "iPad8,10": VigramSDK.AntennaOffset.SPCPlusLight.iPadPro11Middle, // Ipad Pro 11 inch (2nd gen)
    "iPad13,4": VigramSDK.AntennaOffset.SPCPlusLight.iPadPro11Middle, // Ipad Pro 11 inch (3nd gen)
    "iPad13,5": VigramSDK.AntennaOffset.SPCPlusLight.iPadPro11Middle, // Ipad Pro 11 inch (3nd gen)
    "iPad13,6": VigramSDK.AntennaOffset.SPCPlusLight.iPadPro11Middle, // Ipad Pro 11 inch (3nd gen)
    "iPad13,7": VigramSDK.AntennaOffset.SPCPlusLight.iPadPro11Middle, // Ipad Pro 11 inch (3nd gen)
    "iPad14,3": VigramSDK.AntennaOffset.SPCPlusLight.iPadPro11Middle, // Ipad Pro 11 inch (M2)
    "iPad14,4": VigramSDK.AntennaOffset.SPCPlusLight.iPadPro11Middle, // Ipad Pro 11 inch (M2)
    "iPad16,3": VigramSDK.AntennaOffset.SPCPlusLight.iPadPro11Middle, // Ipad Pro 11 inch (M4)
    "iPad16,4": VigramSDK.AntennaOffset.SPCPlusLight.iPadPro11Middle, // Ipad Pro 11 inch (M4)
]

// MARK: Constants value
let borderNormal: CGFloat = 4
let borderSoft: CGFloat = 8
let contentPadding: CGFloat = 16
let popupHPadding: CGFloat = UIDevice.current.isIphone ? 16 : 300
