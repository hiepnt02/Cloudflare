//
//  JpegMetadataCache.swift
//  Quick3D
//
//  Created by HungNT on 3/3/26.
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI
import ImageIO
import MachO

// Helper để cache DateFormatter (Tránh khởi tạo lại nhiều lần)
private let jpgDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
    return df
}()

struct JpegMetadataCache {
    let fileURL: URL
    var metadata: CGMutableImageMetadata? = nil
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    private var isRTK: Bool = false
    
    init(
        fileURL: URL,
        imgId: String,
    ) {
        self.fileURL = fileURL
        
        // Init metadata
        metadata = CGImageMetadataCreateMutable()
        // Register Namespaces
        registerNamespace(metadata!)
        
        setTag(XMP_MODEL, "Pix4Dcatch.\(UIDevice.current.identifier)")
        setTag(XMP_MAKE, "Apple")
        setTag(XMP_CAMERA_CAPTURE_UUID, imgId)
    }
    
    private func registerNamespace(_ metadata: CGMutableImageMetadata) {
        // Giả sử CAMERA_NAMESPACE và XMP_CAMERA_PREFIX là các hằng số global đã định nghĩa ở đâu đó
        CGImageMetadataRegisterNamespaceForPrefix(metadata, CAMERA_NAMESPACE, XMP_CAMERA_PREFIX, nil)
        
        // Các namespace chuẩn của hệ thống
        CGImageMetadataRegisterNamespaceForPrefix(metadata, kCGImageMetadataNamespacePhotoshop, kCGImageMetadataPrefixPhotoshop, nil)
        CGImageMetadataRegisterNamespaceForPrefix(metadata, kCGImageMetadataNamespaceExif, kCGImageMetadataPrefixExif, nil)
        CGImageMetadataRegisterNamespaceForPrefix(metadata, kCGImageMetadataNamespaceExifEX, kCGImageMetadataPrefixExifEX, nil)
        CGImageMetadataRegisterNamespaceForPrefix(metadata, kCGImageMetadataNamespaceTIFF, kCGImageMetadataPrefixTIFF, nil)
    }
    
    // Helper để set value ngắn gọn hơn
    func setTag(_ path: String, _ value: String) {
        guard let _metadata = metadata else {
            return
        }
        CGImageMetadataSetValueWithPath(_metadata, nil, path as CFString, value as CFString)
    }
    
    func setSubsecTimeOriginal(_ time: String?) {
        if let t = time {
            setTag(XMP_SUBSEC_TIME_ORIGINAL, t)
        }
    }
    
    func setCoordinate(_ coordinate: String?) {
        if let coordinate = coordinate {
            setTag(XMP_CAMERA_HORIZ_CS, coordinate)
            setTag(XMP_CAMERA_VERT_CS, "ellipsoidal")
        }
    }
    
    mutating func setRTKLocation(
        _ location: LocationModel,
        rtkId: String? = nil,
        rtkSerialNumber: String? = nil
    ) {
        setTag(XMP_CAMERA_RTK_ALTITUDE, "\(location.altitude)")
        setTag(XMP_CAMERA_RTK_LONGITUDE, "\(location.longitude)")
        setTag(XMP_CAMERA_RTK_LATITUDE, "\(location.latitude)")
        setTag(XMP_CAMERA_RTK_XY_ACCURACY, "\(location.horizontal)")
        setTag(XMP_CAMERA_RTK_Z_ACCURACY, "\(location.vertical)")
        
        setTag(XMP_CAMERA_RTK_YAW, "0.0")
        setTag(XMP_CAMERA_RTK_ROLL, "0.0")
        setTag(XMP_CAMERA_RTK_PITCH, "0.0")
        setTag(XMP_CAMERA_RTK_MODEL, "newVidoc")
        
        if let id = rtkId {
            setTag(XMP_CAMERA_RTK_ID, id)
        }
        if let serialNumber = rtkSerialNumber {
            setTag(XMP_CAMERA_RTK_SERIAL_NUMBER, serialNumber)
        }
        
        self.isRTK = true
    }
    
    mutating func setGPSLocation(_ location: LocationModel) {
        let altitude = abs(location.altitude).fractionString
        let altitudeRef = location.altitude >= 0 ? "0": "1"
        self.longitude = abs(location.longitude)
        let longitudeRef = location.longitude > 0 ? "E" : "W"
        self.latitude = abs(location.latitude)
        let latitudeRef = location.latitude > 0 ? "N" : "S"
        
        setTag(XMP_CAMERA_GPS_ALTITUDE, altitude)
        setTag(XMP_CAMERA_GPS_ALTITUDE_REF, altitudeRef)
        setTag(XMP_CAMERA_GPS_LONGITUDE, "\(longitude)")
        setTag(XMP_CAMERA_GPS_LONGITUDE_REF, longitudeRef)
        setTag(XMP_CAMERA_GPS_LATITUDE, "\(latitude)")
        setTag(XMP_CAMERA_GPS_LATITUDE_REF, latitudeRef)
        
        setTag(XMP_CAMERA_GPS_XY_ACCURACY, "\(location.horizontal)")
        setTag(XMP_CAMERA_GPS_Z_ACCURACY, "\(location.vertical)")
    }
    
    func setFocalLengthPixel(
        _ focalLength: Double,
        _ principalPointX: Double,
        _ principalPointY: Double
    ) {
        let f = (focalLength * pixelSize).rounding(places: 4)
        let x = (principalPointX * pixelSize).rounding(places: 4)
        let y = (principalPointY * pixelSize).rounding(places: 4)
        setTag(XMP_CAMERA_FOCAL_LENGTH, f.fractionString)
        setTag(XMP_CAMERA_PERSPECTIVE_FOCAL_LENGTH, "\(f)")
        setTag(XMP_CAMERA_PRINCIPAL_POINT, "\(x),\(y)")
        setTag(XMP_CAMERA_MODEL_TYPE, "perspective")
        setTag(XMP_CAMERA_PERSPECTIVE_DISTORTION, "0.000001,0.0,0.0,0.0,0.0")
        setTag(XMP_CAMERA_FOCAL_PLANE_RESOLUTION_UNIT, "4")
        setTag(XMP_CAMERA_FOCAL_PLANE_X_RESOLUTION, "3998077/10395")
        setTag(XMP_CAMERA_FOCAL_PLANE_Y_RESOLUTION, "3998077/10395")
    }
    
    func setEulerAngles(eulerAngles: EulerAngles) {
        setTag(XMP_CAMERA_YAW, "\(eulerAngles.yaw.degrees)")
        setTag(XMP_CAMERA_ROLL, "\(eulerAngles.roll.degrees)")
        setTag(XMP_CAMERA_PITCH, "\(eulerAngles.pitch.degrees)")
    }
    
    func setTimeExport(date: Date) {
        let dateStr = jpgDateFormatter.string(from: date)
        setTag(XMP_PHOTOSHOP_CREATED_DATE, dateStr)
        setTag(XMP_PHOTOSHOP_CREATED_DATE_TIME, dateStr)
        
        setTag(XMP_LENS_MODEL, "iOS")
        setTag(XMP_IMAGE_ID, String.randomNumber(length: 20))
        setTag(XMP_ORIENTATION, (AppDelegate.orientationLock.rawValue == 2) ? "6" : "1")
    }
}
