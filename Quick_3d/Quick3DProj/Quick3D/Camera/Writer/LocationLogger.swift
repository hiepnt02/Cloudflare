//
//  GPSLogger.swift
//  Quick3D
//
//  Created by HaNST on 16/10/25.
//

import Foundation

class LocationLogger {
    
    private let lock = NSLock()
    
    private let _all_locations: CSVLogger
    private let _imageMeasurementsPositions: CSVLogger
    private let _locations_ar: CSVLogger
    private let _locations_ar_fitted: CSVLogger
    private let _locations_geofusion: CSVLogger
    private let _locations_gps_raw_sampled: CSVLogger
    private let _mapper_locations_geofusion: CSVLogger
    private let _mapper_locations_gps_offset_sampled: CSVLogger
    private let _matic_locations_ar: CSVLogger
    private let _matic_locations_geofusion: CSVLogger
    private let _matic_locations_gps_offset_sampled: CSVLogger
    
    private var imageTimes: [String: TimeInterval] = [:]
    
    private let session: CaptureSession
    
    init(_ session: CaptureSession) {
        
        self.session = session
        
        let _gps = session.getGPSFolderURL()
        let _all_locations_url = _gps.appendingPathComponent("_all_locations.csv")
        let _imageMeasurementsPositions_url = _gps.appendingPathComponent("_imageMeasurementsPositions.csv")
        let _locations_ar_url = _gps.appendingPathComponent("_locations_ar.csv")
        let _locations_ar_fitted_url = _gps.appendingPathComponent("_locations_ar_fitted.csv")
        let _locations_geofusion_url = _gps.appendingPathComponent("_locations_geofusion.csv")
        let _locations_gps_raw_sampled_url = _gps.appendingPathComponent(session.isRTK ? "_locations_rtk_raw_sampled.csv" : "_locations_gps_raw_sampled.csv")
        let _mapper_locations_geofusion_url = _gps.appendingPathComponent("_mapper_locations_geofusion.csv")
        let _mapper_locations_gps_offset_sampled_url = _gps.appendingPathComponent(session.isRTK ? "_mapper_locations_rtk_offset_sampled.csv" : "_mapper_locations_gps_offset_sampled.csv")
        let _matic_locations_ar_url = _gps.appendingPathComponent("_matic_locations_ar.csv")
        let _matic_locations_geofusion_url = _gps.appendingPathComponent("_matic_locations_geofusion.csv")
        let _matic_locations_gps_offset_sampled_url = _gps.appendingPathComponent(session.isRTK ? "_matic_locations_rtk_offset_sampled.csv" : "_matic_locations_gps_offset_sampled.csv")
        
        _all_locations = CSVLogger(["time", "image", "latitude", "longitude", "altitude", "yaw", "pitch", "roll", "xyAccuracy", "zAccuracy"], fileUrl: _all_locations_url)
        _imageMeasurementsPositions = CSVLogger([], fileUrl: _imageMeasurementsPositions_url)
        _locations_ar = CSVLogger(["time", "image", "latitude", "longitude", "altitude", "yaw", "pitch", "roll", "xyAccuracy", "zAccuracy"], fileUrl: _locations_ar_url)
        _locations_ar_fitted = CSVLogger(["time", "image", "latitude", "longitude", "altitude", "yaw", "pitch", "roll", "xyAccuracy", "zAccuracy"], fileUrl: _locations_ar_fitted_url)
        _locations_geofusion = CSVLogger(["time", "image", "latitude", "longitude", "altitude", "yaw", "pitch", "roll", "xyAccuracy", "zAccuracy"], fileUrl: _locations_geofusion_url)
        _locations_gps_raw_sampled = CSVLogger(["time", "image", "latitude", "longitude", "altitude", "yaw", "pitch", "roll", "xyAccuracy", "zAccuracy"], fileUrl: _locations_gps_raw_sampled_url)
        _mapper_locations_geofusion = CSVLogger([], fileUrl: _mapper_locations_geofusion_url)
        _mapper_locations_gps_offset_sampled = CSVLogger([], fileUrl: _mapper_locations_gps_offset_sampled_url)
        _matic_locations_ar = CSVLogger([], fileUrl: _matic_locations_ar_url)
        _matic_locations_geofusion = CSVLogger([], fileUrl: _matic_locations_geofusion_url)
        _matic_locations_gps_offset_sampled = CSVLogger([], fileUrl: _matic_locations_gps_offset_sampled_url)
        
        let geofitLogs = session.isRTK ?
        """
        fixOutliers
        
        computedTimeOffset,-0.000000
        computedTimeOffset-duration,0.010325
        
        GeoFusion-duration,0.00712
        GeoFit
        CameraOffset,0,0,0
        
        isRtk,true
        accuracyThreshold,0.02
        enableGeoFusion,true
        enableGeoFit,true
        timeOffset,0
        enableComputeTimeOffset,true
         
        GeoFit-duration,0.001226
        """
        :
        """
        fixOutliers
        GeoFusion-duration,0.009729
        GeoFit
        CameraOffset,0,0,0
        
        isRtk,false
        accuracyThreshold,0.02
        enableGeoFusion,true
        enableGeoFit,true
        timeOffset,0
        enableComputeTimeOffset,true
         
        GeoFit-duration,0.000377
        """
        
        let geofit_logs_url = _gps.appendingPathComponent("geofit_logs.txt")
        try? StorageManager.shared.write(geofit_logs_url, text: geofitLogs)
        
    }
    
    func setImageTime(image: String, time: TimeInterval) {
        lock.lock()
        defer {
            lock.unlock()
        }
        imageTimes[image] = time
    }
    
    func getImageTime(image: String) -> TimeInterval? {
        lock.lock()
        defer {
            lock.unlock()
        }
        return imageTimes[image]
    }
    
    func appendAR(image: String, location: LocationModel, eulerAngles: EulerAngles) {
        appendAR(image: image,
                 latitude: location.latitude,
                 longitude: location.longitude,
                 altitude: location.altitude,
                 yaw: eulerAngles.yaw.degrees,
                 pitch: eulerAngles.pitch.degrees,
                 roll: eulerAngles.roll.degrees)
    }
    
    private func appendAR(image: String, latitude: Double, longitude: Double, altitude: Double, yaw: Double, pitch: Double, roll: Double) {
        if let currentTime = getImageTime(image: image) {
            let data = [
                String(format: "%.6f", currentTime),
                image,
                String(format: "%.9f", latitude),
                String(format: "%.9f", longitude),
                String(format: "%.4f", altitude),
                String(format: "%.4f", yaw),
                String(format: "%.4f", pitch),
                String(format: "%.4f", roll),
                "0.0100",
                "0.0100",
            ]
            _locations_ar.log(data, -1)
        }
        
    }
    
    func appendARFitted(image: String, location: LocationModel, eulerAngles: EulerAngles) {
        appendARFitted(image: image,
                 latitude: location.latitude,
                 longitude: location.longitude,
                 altitude: location.altitude,
                 yaw: eulerAngles.yaw.degrees,
                 pitch: eulerAngles.pitch.degrees,
                 roll: eulerAngles.roll.degrees)
    }
    
    private func appendARFitted(image: String, latitude: Double, longitude: Double, altitude: Double, yaw: Double, pitch: Double, roll: Double) {
        if let currentTime = getImageTime(image: image) {
            let data = [
                String(format: "%.6f", currentTime),
                image,
                String(format: "%.9f", latitude),
                String(format: "%.9f", longitude),
                String(format: "%.4f", altitude),
                String(format: "%.4f", yaw),
                String(format: "%.4f", pitch),
                String(format: "%.4f", roll),
                "0.0100",
                "0.0100",
            ]
            _locations_ar_fitted.log(data, -1)
        }
        
    }
    
    func appendRTKOffsetSampled(image: String, location: LocationModel, eulerAngles: EulerAngles) {
        appendRTKOffsetSampled(image: image,
                 latitude: location.latitude,
                 longitude: location.longitude,
                 altitude: location.altitude,
                 yaw: eulerAngles.yaw.degrees,
                 pitch: eulerAngles.pitch.degrees,
                 roll: eulerAngles.roll.degrees)
    }
    
    private func appendRTKOffsetSampled(image: String, latitude: Double, longitude: Double, altitude: Double, yaw: Double, pitch: Double, roll: Double) {
        if let currentTime = getImageTime(image: image) {
            let data = [
                String(format: "%.6f", currentTime),
                image,
                String(format: "%.9f", latitude),
                String(format: "%.9f", longitude),
                String(format: "%.4f", altitude),
                String(format: "%.4f", yaw),
                String(format: "%.4f", pitch),
                String(format: "%.4f", roll),
                "0.0100",
                "0.0100",
            ]
            _mapper_locations_gps_offset_sampled.log(data, -1)
            _matic_locations_gps_offset_sampled.log(data, -1)
        }
        
    }
    
    func appendGeofusion(image: String, location: LocationModel, eulerAngles: EulerAngles) {
        appendGeofusion(image: image,
                        latitude: location.latitude,
                        longitude: location.longitude,
                        altitude: location.altitude,
                        yaw: eulerAngles.yaw.degrees,
                        pitch: eulerAngles.pitch.degrees,
                        roll: eulerAngles.roll.degrees,
                        xyAccuracy: location.horizontal,
                        zAccuracy: location.vertical
        )
    }
    
    private func appendGeofusion(image: String, latitude: Double, longitude: Double, altitude: Double, yaw: Double, pitch: Double, roll: Double, xyAccuracy: Double, zAccuracy: Double) {
        if let currentTime = getImageTime(image: image) {
            let data = [
                String(format: "%.6f", currentTime),
                image,
                String(format: "%.9f", latitude),
                String(format: "%.9f", longitude),
                String(format: "%.4f", altitude),
                String(format: "%.4f", yaw),
                String(format: "%.4f", pitch),
                String(format: "%.4f", roll),
                String(format: "%.4f", xyAccuracy),
                String(format: "%.4f", zAccuracy)
            ]
            
            _locations_geofusion.log(data, -1)
            _mapper_locations_geofusion.log(data, -1)
            _matic_locations_geofusion.log(data, -1)
            _matic_locations_ar.log(data, -1)
        }
    }
    
    private func appendRaw(image: String, latitude: Double, longitude: Double, altitude: Double, xyAccuracy: Double, zAccuracy: Double) {
        let currentTime = Double(Date().timeIntervalSince1970)
        
        setImageTime(image: image, time: currentTime)
        
        let data = [
            String(format: "%.6f", currentTime),
            image,
            String(format: "%.9f", latitude),
            String(format: "%.9f", longitude),
            String(format: "%.4f", altitude),
            "0.0000",
            "0.0000",
            "0.0000",
            String(format: "%.4f", xyAccuracy),
            String(format: "%.4f", zAccuracy)
        ]
        
        _locations_gps_raw_sampled.log(data, -1)
    }
    
    func appendRaw(image: String, location: LocationModel) {
        appendRaw(image: image, latitude: location.latitude, longitude: location.longitude, altitude: location.altitude, xyAccuracy: location.horizontal, zAccuracy: location.vertical)
    }
    
    func write(location: LocationModel) {
        write(latitude: location.latitude, longitude: location.longitude, altitude: location.altitude)
    }
    
    private func write(latitude: Double, longitude: Double, altitude: Double) {
        _imageMeasurementsPositions.write()
        _locations_ar.write()
        _locations_ar_fitted.write()
        _locations_geofusion.write()
        _locations_gps_raw_sampled.write()
        _mapper_locations_geofusion.write()
        _mapper_locations_gps_offset_sampled.write()
        _matic_locations_ar.write()
        _matic_locations_geofusion.write()
        _matic_locations_gps_offset_sampled.write()
        
        StorageManager.waitUntilCompleted()
        
        _all_locations.clear()
        
        _all_locations.log(["/// Origin"], -1)
        _all_locations.log([
            "0.000000",
            "Origin",
            String(format: "%.9f", latitude),
            String(format: "%.9f", longitude),
            String(format: "%.4f", altitude),
        ], -1)
        
        _all_locations.log(["/// AR"], -1)
        if let ar = _locations_ar.read(removeHeader: true) {
            _all_locations.log([ar], -1)
        }
        
        _all_locations.log(["/// AR_fitted"], -1)
        if let ar = _locations_ar_fitted.read(removeHeader: true) {
            _all_locations.log([ar], -1)
        }
        
        _all_locations.log(["/// RTK_raw"], -1)
        
        let raw = session.gpsLogger.readLines(removeHeader: true)
        
        for i in 0..<raw.count {
            let row = raw[i]
            if row.isEmpty { continue }
            let data = row.split(separator: ",")
            
            let rkt = data.count == 15
            
            let timestamp = String(data[0])
            let latitude =  Double(data[1]) ?? 0
            let longitude = Double(data[2]) ?? 0
            let altitude = Double(data[3]) ?? 0
            let xyAccuracy = rkt ? Double(data[6]) ?? 0 : Double(data[4]) ?? 0
            let zAccuracy = rkt ? Double(data[7]) ?? 0 : Double(data[5]) ?? 0
            
            _all_locations.log([
                timestamp,
                "gps_\(i)",
                String(format: "%.9f", latitude),
                String(format: "%.9f", longitude),
                String(format: "%.4f", altitude),
                "0.0000",
                "0.0000",
                "0.0000",
                String(format: "%.4f", xyAccuracy),
                String(format: "%.4f", zAccuracy)
            ], -1)
        }
        
        _all_locations.log(["/// RTK_offset_sampled"], -1)
        if let sampled = _matic_locations_gps_offset_sampled.read(removeHeader: false) {
            _all_locations.log([sampled], -1)
        }
        
        _all_locations.log(["/// RTK_geofusion"], -1)
        
        if let geofusion = _locations_geofusion.read(removeHeader: true) {
            _all_locations.log([geofusion], -1)
        }
        
        _all_locations.write()
    }
    
}
