//
//  RTKLogger.swift
//  Quick3D
//
//  Created by HaNST on 16/10/25.
//

import Foundation
import VigramSDK

class RTKLogger {
    
    public let gps: CSVLogger
    public let nmea: CSVLogger
    
    var onError: ((Error) -> Void)? {
        set(value) {
            gps.onError = value
            nmea.onError = value
        }
        get {
            gps.onError
        }
    }
    
    init(_ session: CaptureSession) {
        
        gps = CSVLogger(["Timestamp",
                        "GPSLatitude",
                        "GPSLongitude",
                        "GPSAltitude",
                        "ReferenceAltitude",
                        "GeoidSeparation",
                        "HAccuracy",
                        "VAccuracy",
                        "qualityIndicator",
                        "hdop",
                        "vdop",
                        "pdop",
                        "NorthVelocity",
                        "EastVelocity",
                        "DownVelocity"], fileUrl: session.url.appendingPathComponent("rtkGPS.csv"))
        
        nmea = CSVLogger(["Timestamp",
                         "latitude",
                         "longitude",
                         "quality",
                         "satelliteCount",
                         "hdop",
                         "vdop",
                         "pdop",
                         "referenceAltitude",
                         "geoidSeparation",
                          "HAccuracy",
                          "VAccuracy",
                          "pitch",
                          "roll",
                          "yaw",
                         "correctionAge",
                         "correctionStationID",
                         "rms",
                         "semiMajor1SigmaError",
                         "semiMinor1SigmaError",
                         "errorEllipseOrientation",
                         "latitudeError",
                         "longitudeError",
                         "altitudeError",
                         "hour",
                         "minute",
                         "second",
                         "NorthVelocity",
                         "EastVelocity",
                         "DownVelocity",
                          "deviceTimeStamp.timeIntervalSince1970",
                         "raw"], fileUrl: session.url.appendingPathComponent("rtkNMEA.csv"))
    }
    
    func logGPS(data: EnvironmentData, quality: RTKQuality?, pvt: VigramSDK.SatelliteMessage.Pvt?, dop: VigramSDK.SatelliteMessage.Dop?) {
        let deviceTimeStamp = data.date
        let time = String(format: "%.4f", deviceTimeStamp.timeIntervalSince1970)
        
        let latitude = data.correctedCoordinate.latitude
        let longitude = data.correctedCoordinate.longitude
        let altitude = data.correctedCoordinate.altitude
        let referenceAltitude = data.correctedCoordinate.referenceAltitude
        let geoidSeparation = data.correctedCoordinate.geoidSeparation
        let hAccuracy = data.horizontalAccuracy
        let vAccuracy = data.verticalAccuracy
        
        var qualityString = ""
        if let q = quality {
            switch q {
            case .fixed:
                qualityString = "rtkFixed"
                break
            case .float:
                qualityString = "rtkFloat"
                break
            case .dgnss:
                qualityString = "DGNSS"
                break
            case .gnss:
                qualityString = "GNSS"
                break
            case .invalid:
                qualityString = "No Fix"
                break
            }
        }
        
        let hdop = dop?.horizontalDop ?? 0.0
        let vdop = dop?.verticalDop ?? 0.0
        let pdop = dop?.positionDop ?? 0.0
        let NorthVelocity = pvt?.northVelocity ?? 0.0
        let EastVelocity = pvt?.eastVelocity ?? 0.0
        let DownVelocity = pvt?.downVelocity ?? 0.0
        
        gps.log([
            time,
            "\(latitude)",
            "\(longitude)",
            "\(altitude)",
            "\(referenceAltitude)",
            "\(geoidSeparation)",
            "\(hAccuracy)",
            "\(vAccuracy)",
            qualityString,
            "\(hdop)",
            "\(vdop)",
            "\(pdop)",
            "\(NorthVelocity)",
            "\(EastVelocity)",
            "\(DownVelocity)"
        ], 0.09)
    }
    
    func logNMEA(message: NMEAData) {
        let calendar = Calendar(identifier:.gregorian)
        var vigramTimeStamp = nil as Date?
        if message.gga?.time != nil {
            var components = calendar.dateComponents(in: TimeZone(secondsFromGMT: 0)! , from: Date())
            components.hour = message.gga?.time?.hour
            components.minute = message.gga?.time?.minute
            let originalSec = message.gga!.time!.second
            components.second = Int(floor(originalSec))
            components.nanosecond = Int((originalSec - floor(originalSec)) * 1_000_000_000)
            vigramTimeStamp = calendar.date(from: components)!
        }
        
        let deviceTimeStamp = vigramTimeStamp ?? (message.gga?.timeStampUnix as Date?) ?? Date()
        let time = String(format: "%.4f", deviceTimeStamp.timeIntervalSince1970)
        let ggaMessage = message.gga
        let gstMessage = message.gst
        let latitude = ggaMessage?.coordinate?.latitude
        let longitude = ggaMessage?.coordinate?.longitude
        
        var quality = ""
        switch message.quality {
        case .fixed:
            quality = "rtkFixed"
        case .float:
            quality = "rtkFloat"
        case .dgnss:
            quality = "differential"
        case .gnss:
            quality = "autonomous"
        default:
            quality = "unavailable"
        }
        
        let satelliteCount = message.pvt?.satelliteCount ?? 0
        let hdop = message.dop?.horizontalDop ?? 0.0
        let vdop = message.dop?.verticalDop ?? 0.0
        let pdop = message.dop?.positionDop ?? 0.0
        let referenceAltitude = ggaMessage?.referenceAltitude
        let geoidSeparation = ggaMessage?.geoidSeparation
        let correctionAge = ggaMessage?.correctionAge
        let correctionStationID = ggaMessage?.correctionStationID
        let rms = gstMessage?.rms ?? 0.0
        let semiMajor1SigmaError = gstMessage?.semiMajor1SigmaError ?? 0.0
        let semiMinor1SigmaError = gstMessage?.semiMinor1SigmaError ?? 0.0
        let errorEllipseOrientation = gstMessage?.errorEllipseOrientation ?? 0.0
        let latitudeError = gstMessage?.latitudeError ?? 0.0
        let longitudeError = gstMessage?.longitudeError ?? 0.0
        let altitudeError = gstMessage?.altitudeError ?? 0.0
        let hour = ggaMessage?.time?.hour ?? 0
        let minute = ggaMessage?.time?.minute ?? 0
        let second = ggaMessage?.time?.second ?? 0
        let NorthVelocity = message.pvt?.northVelocity ?? 0.0
        let EastVelocity = message.pvt?.eastVelocity ?? 0.0
        let DownVelocity = message.pvt?.downVelocity ?? 0.0
        
        let haccuracy = gstMessage?.accuracy?.horizontal ?? 100.0
        let vaccuracy = gstMessage?.accuracy?.vertical ?? 100.0
        
        let pitch = MotionObject.shared.data.attitude.pitch
        let roll = MotionObject.shared.data.attitude.roll
        let yaw = MotionObject.shared.data.attitude.yaw
        let raw = message.raw ?? ""
        
        nmea.log([
            time,
            "\(latitude.map { String($0) } ?? "")",
            "\(longitude.map { String($0) } ?? "")",
            quality,
            "\(satelliteCount)",
            "\(hdop)",
            "\(vdop)",
            "\(pdop)",
            "\(referenceAltitude.map { String($0) } ?? "")",
            "\(geoidSeparation.map { String($0) } ?? "")",
            "\(haccuracy)",
            "\(vaccuracy)",
            "\(pitch)",
            "\(roll)",
            "\(yaw)",
            "\(correctionAge.map { String($0) } ?? "")",
            "\(correctionStationID.map { String($0) } ?? "")",
            "\(rms)",
            "\(semiMajor1SigmaError)",
            "\(semiMinor1SigmaError)",
            "\(errorEllipseOrientation)",
            "\(latitudeError)",
            "\(longitudeError)",
            "\(altitudeError)",
            "\(hour)",
            "\(minute)",
            "\(second)",
            "\(NorthVelocity)",
            "\(EastVelocity)",
            "\(DownVelocity)",
            "\(deviceTimeStamp.timeIntervalSince1970)",
            raw
        ], 0.09)
    }
    
    func write() {
        gps.write()
        nmea.write()
    }
    
}

