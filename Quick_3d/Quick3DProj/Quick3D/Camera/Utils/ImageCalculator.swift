//
//  LocationCalculator.swift
//  Quick3D
//
//  Created by HaNST on 11/8/25.
//

import Foundation
import VigramSDK

struct ImageLocation {
    let originalLocation: LocationModel
    let location: LocationModel
    let eulerAngles: EulerAngles
}

public class ImageCalculator {
    
    static let parcialPointsCount: Int = 5
    
    static let oneSideParcialPointsCount: Int = 30
    
    static let arAccuracy: Double = 0.01
    
    static let thresholdAccuracy: Double = 0.015
    
    static func getBasePosition(_ frames: [FrameMetadata]) -> CameraPosition {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        var latitude: Double = -1
        var longitude: Double = -1
        var altitude: Double = -1
        var horizontal: Double = .infinity
        var vertical: Double = .infinity
        
        var isRTK = false
        
        frames.forEach { frame in
            let location = frame.location
            isRTK = frame.isRTK
            
            let arPosition: simd_double3 = make_simd_double3(frame.transform.columns.3)
            
            if horizontal > location.horizontal {
                horizontal = location.horizontal
                latitude = location.latitude
                longitude = location.longitude
                x = arPosition.x
                z = arPosition.z
            }
            
            if vertical > location.vertical {
                vertical = location.vertical
                altitude = location.altitude
                y = arPosition.y
            }
        }
        let basePosition = simd_double3(x: x, y: y, z: z)
        let baseLocation = LocationModel(latitude: latitude, longitude: longitude, altitude: altitude, horizontal: horizontal, vertical: vertical, heading: 0)
        return CameraPosition(coord: basePosition, location: baseLocation, isRTK: isRTK)
    }
    
    static func getBasePosition(_ positions: [PositionHistory]) -> PositionHistory {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        var latitude: Double = -1
        var longitude: Double = -1
        var altitude: Double = -1
        var offsetX: Double = 0
        var offsetY: Double = 0
        var offsetZ: Double = 0
        var horizontal: Double = .infinity
        var vertical: Double = .infinity
        
        positions.forEach { position in
            let location = position.location
            
            let arPosition: simd_double3 = position.coord
            let offset = position.offset!
            
            if horizontal > location.horizontal {
                horizontal = location.horizontal
                latitude = location.latitude
                longitude = location.longitude
                x = arPosition.x
                z = arPosition.z
                offsetX = offset.x
                offsetZ = offset.z
            }
            
            if vertical > location.vertical {
                vertical = location.vertical
                altitude = location.altitude
                y = arPosition.y
                offsetY = offset.y
            }
        }
        let basePosition = simd_double3(x: x, y: y, z: z)
        let baseOffset = simd_double3(x: offsetX, y: offsetY, z: offsetZ)
        let baseLocation = LocationModel(latitude: latitude, longitude: longitude, altitude: altitude, horizontal: horizontal, vertical: vertical, heading: 0)
        return PositionHistory(coord: basePosition, location: baseLocation, offset: baseOffset)
    }
    
    static func updateRTKLocations(_ frames: [FrameMetadata], _ cameraTimeInterval: TimeInterval = 0.0)-> [FrameMetadata]{
        let locations = frames.map({$0.location})
        let timestamps = frames.map({$0.timestamp.addingTimeInterval(cameraTimeInterval)})
        let newLocations: [LocationModel] = updateRTKLocations(locations,timestamps)
        var res : [FrameMetadata] = []
        for item in frames.enumerated() {
            let frame = item.element
            let index = item.offset
            if frame.isRTK{
                frame.rtkLocation = newLocations[index]
            }
            res.append(frame)
        }
        return res
    }
    static func updateRTKLocations(_ locations: [LocationModel],_  timestamps:[Date])-> [LocationModel]{
        var res : [LocationModel] = []
        
        CaptureSession.current?.rtkLogger?.write()
        StorageManager.waitUntilCompleted()
        var offset = RTKManager.shared.mapToAntennaOffset()
        offset.y -= (VigramSDK.Configuration.middleAntenna * 0.01)
        let rawNmea = CaptureSession.current?.rtkLogger?.nmea.readLines(removeHeader: true) ?? []
       
        var rawData: [LocationModel] = []
       
        rawNmea.forEach { (line) in
            let splitStr = line.split(separator: ",", omittingEmptySubsequences: false)
            if splitStr.count < 14 || splitStr[3] == "unavailable" {
                return
            }
            print(splitStr[3])
            let data: [Double] = splitStr.compactMap(Double.init)
            
            let rawCoordinate = GPSCoordinate(latitude: data[1], longitude: data[2], referenceAltitude: data[7], geoidSeparation: data[8])
            let pitch = data[11]
            let roll = data[12]
            let yaw = data[13]
            let correctedCoordinate = rawCoordinate.translate(offset: offset, orientation: SIMD3(pitch: pitch, roll: roll, yaw: yaw))
            
            let rawLocation = LocationModel(
                latitude: correctedCoordinate.latitude,
                longitude: correctedCoordinate.longitude,
                altitude: correctedCoordinate.altitude,
                horizontal: data[9],
                vertical: data[10],
                heading: 0.0,
                coordinate: "",
                isRTK: false,
                timestamp: Date(timeIntervalSince1970: data[0])
            )
            rawData.append(rawLocation)
            
        }
        
        locations.enumerated().forEach {index, element in
            let location = element
            var newLocation: LocationModel = location
            var newCoord: simd_double3 = simd_double3(
                location.longitude,
                location.latitude,
                location.altitude
                )
            var horizontal = location.horizontal
            var vertical = location.vertical
            var course = location.course
            
            let time = timestamps[index]
            
            let filterdRawData: [LocationModel] = rawData.filter { abs($0.timestamp.timeIntervalSince(time)) < 2.0}
            
            if (filterdRawData.count > 3){
                let pickedRawData = filterdRawData.sorted { abs($0.timestamp.timeIntervalSince(time)) < abs($1.timestamp.timeIntervalSince(time)) }
                
                let prevLocation = pickedRawData[0]
                var nextLocation = pickedRawData[1]
                let backupLocation = pickedRawData[2]
                
                
                let frameTimeInterval = time.timeIntervalSince(prevLocation.timestamp)
                var RTKTimeInterVal = nextLocation.timestamp.timeIntervalSince(prevLocation.timestamp)
                //in some case, two same timestamp from vigram
                if(RTKTimeInterVal == 0.0){
                    nextLocation = backupLocation
                    RTKTimeInterVal = nextLocation.timestamp.timeIntervalSince(prevLocation.timestamp)
                }
                
                let prevCoord: simd_double3 = simd_double3(
                    prevLocation.longitude,
                    prevLocation.latitude,
                    prevLocation.altitude
                )
                let nextCoord : simd_double3 = simd_double3(
                    nextLocation.longitude,
                    nextLocation.latitude,
                    nextLocation.altitude
                    )
                if (RTKTimeInterVal != 0.0){
                    let velocity : simd_double3 = (nextCoord - prevCoord) / RTKTimeInterVal
                    newCoord = prevCoord + velocity * frameTimeInterval
                    horizontal = (prevLocation.horizontal + nextLocation.horizontal) / 2.0
                    vertical = (prevLocation.vertical + nextLocation.vertical) / 2.0
                    course = (prevLocation.course + nextLocation.course) / 2.0
                }else{
                    newCoord = prevCoord
                    horizontal = prevLocation.horizontal
                    vertical = prevLocation.vertical
                    course = prevLocation.course
                }
                newLocation = LocationModel(
                    latitude: newCoord.y,
                    longitude: newCoord.x,
                    altitude: newCoord.z,
                    horizontal: horizontal,
                    vertical: vertical,
                    heading: course,
                    coordinate: location.coordinate,
                    isRTK: location.isRTK,
                    timestamp: time)
                
                rawData = rawData.filter { $0.timestamp.timeIntervalSince(time) > -2.0 }
            }
            res.append(newLocation)
        }
        return res
    }
    
    static func updatePositionOffsets(_ positionHistories: [PositionHistory])-> [SIMD3<Double>?]{
        let offsets : [SIMD3<Double>?] = positionHistories.map({$0.offset})
        let timestamps: [Date] = positionHistories.map({$0.frameTimestamp})
        var res : [SIMD3<Double>?] = []
        
        offsets.enumerated().forEach {index, element in
            let offset = element
            var newOffset = offset
            
            if (index > 0){
                let location = positionHistories[index].location
                let prevLocation = positionHistories[index-1].location
                let prevOffset = offsets[index-1]
                
                let time = timestamps[index]
                let frameTimeInterval = time.timeIntervalSince(prevLocation.timestamp)
                let RTKTimeInterVal = location.timestamp.timeIntervalSince(prevLocation.timestamp)
               
                if (
                    frameTimeInterval != 0.0
                    && RTKTimeInterVal != 0.0
                    && offset != nil
                    && prevOffset != nil
                ){
                    
                    let velocity : simd_double3 = (offset! - prevOffset!) / RTKTimeInterVal
                    newOffset = prevOffset! + velocity * frameTimeInterval
                   
                }
               
            }
            res.append(newOffset)
        }
        return res
    }
    
    static func calculateLocations(_ positions: [PositionHistory],_ scale: Double? = nil) -> simd_double4x4 {
        let filtered = positions.filter { $0.offset != nil }
        if filtered.count < 2 {
            return matrix_identity_double4x4
        }
        
        let arPoints = filtered.map { simd_double2(Double( $0.coord.x ) , Double( $0.coord.z )) }
        
        let locationPoints  = updatePositionOffsets(filtered).map { simd_double2(Double( $0!.x ) , Double( $0!.z ))}
        
        let svd2d = SVD2D(locationPoints, arPoints, false, scale == 1.0 ? nil : scale)
        
        var transformMatrix = svd2d.getRTMatrix4x4SVD()
        
        
        let aveLocationVert: Double = filtered.count==0 ? 0.0 : filtered.map{$0.offset!.y}.reduce(0, +) / Double(filtered.count)
        let aveARVert: Double = filtered.count==0 ? 0.0 :  filtered.map{$0.coord.y}.reduce(0, +) / Double(filtered.count)
        let offsetVert: Double = aveLocationVert - aveARVert

        transformMatrix.columns.3.y = offsetVert
        return transformMatrix
    }
    
    static func calculateLocations(_ frames: [FrameMetadata]) -> (root: LocationModel, images: [ImageLocation]) {
        
        var result : [ImageLocation] = []
        
        let base = getBasePosition(frames)
        let root = base.root()
        
        let arPoints = frames.map { simd_double2(Double( $0.position.x ) , Double( $0.position.z )) }
        
        let locationPoints  = frames.map { frame in
            let point = base.coordinates(frame.location)
            return simd_double2(point.coord.x, point.coord.z)
        }
        
        let icpInstance = ICP2D(locationPoints, arPoints)
        let finalTransform = icpInstance.iterate(maxIterations: 20, minErrorChange: 0.0)
        
        let Rz = atan2(finalTransform.columns.0.y, finalTransform.columns.0.x)
        
        frames.forEach { frame in
            let point = make_simd_double3(frame.transform.columns.3)
            let newPoint = finalTransform * simd_double3(point.x, point.z, 1)

            let T = Transformation(frame.transform, order: .yxz)
            let E = T.eulerAngles.transform()
            let eulerAngles = EulerAngles(E.x, E.y, E.z + Rz)
            
            let location = PositionModel.calculate(location: root.location,
                                                   x: point.x,
                                                   y: point.y,
                                                   z: point.z,
                                                   horizontal: root.location.horizontal,
                                                   vertical: root.location.vertical)
            
            let newLocation = PositionModel.calculate(location: root.location,
                                                      x: newPoint.x,
                                                      y: point.y,
                                                      z: newPoint.y,
                                                      horizontal: root.location.horizontal,
                                                      vertical: root.location.vertical)
            
            result.append(ImageLocation(originalLocation: location, location: newLocation, eulerAngles: eulerAngles))
        }
        
        return (root.location, result)
    }
    
    static func averageFocalLegnth(_ frames: [FrameMetadata]) -> (focalLength: Double, principalPointX: Double, principalPointY: Double) {
        
        let focalLength = frames.map { Double($0.intrinsics.columns.0.x) }.reduce(0, +) / Double(frames.count)
        let principalPointX = frames.map { Double($0.intrinsics.columns.2.x) }.reduce(0, +) / Double(frames.count)
        let principalPointY = frames.map { Double($0.intrinsics.columns.2.y) }.reduce(0, +) / Double(frames.count)
        
        return (focalLength, principalPointX, principalPointY)
    }
    
    static func checkCriteriaAccuracy(_ location:LocationModel) -> Bool{
        return (location.horizontal < thresholdAccuracy && location.vertical < thresholdAccuracy )
    }
    
        
    static func calculateInitImageLocation(_ frames: [FrameMetadata])  -> (root: LocationModel, images: [ImageLocation]){
        var result : [ImageLocation] = []
        
        let base = getBasePosition(frames)
        
        let root = WGSLocalConverter.getOriginLocation(position: base.coord,location:base.location)
        
        // init
        frames.forEach { frame in
            let point = make_simd_double3(frame.transform.columns.3)
            let T = Transformation(frame.transform, order: .yxz)
            let E = T.eulerAngles.transform()
            let eulerAngles = EulerAngles(E.x, E.y, E.z)
            
            let location = WGSLocalConverter.xyzToLocation(
                position: point,
                originLocation: root,
                horizontal: frame.location.horizontal,
                vertical: frame.location.vertical)
            
            result.append(ImageLocation(originalLocation: location, location: location, eulerAngles: eulerAngles))
        }
        
        return (root, result)
    }
    
    static func calculateARFitted(frames: [FrameMetadata], root: LocationModel, images: [ImageLocation])  -> (root: LocationModel, images: [ImageLocation]){
        
        var result : [ImageLocation] = images
        
        result = calculateAllSVD2D(root:root, frames:frames, images:result)
        
        return (root, result)
    }
    
    static func calculateGeoFusionFromARFitted(frames: [FrameMetadata], root: LocationModel, images: [ImageLocation])   -> (root: LocationModel, images: [ImageLocation]) {
        
        var result : [ImageLocation] = images
        
        result = calculatePartialSVD2D(root:root, frames:frames, images:result, isIncludeHighAccurate: false)
        
        result = calculateVertical(root:root, frames:frames, images:result)
        
//        result = calculateWeight(root:root, frames:frames, images:result)
        
        return (root, result)
    }
    
    static func calculateLocationsWithHighAccuracy(_ frames: [FrameMetadata]) -> (root: LocationModel, images: [ImageLocation]) {
        
        // init
        var (root, result) = calculateInitImageLocation(frames)
        
        result = calculateAllSVD2D(root:root, frames:frames, images:result)
        
        result = calculatePartialSVD2D(root:root, frames:frames, images:result, isIncludeHighAccurate: false)
        
        result = calculateVertical(root:root, frames:frames, images:result)
        
//        result = calculateWeight(root:root, frames:frames, images:result)
        
        return (root, result)
    }
    
    
    static func calculateAllSVD2D(root: LocationModel, frames: [FrameMetadata], images: [ImageLocation]) -> [ImageLocation] {
        var result : [ImageLocation] = []
        
        let filterdFramesIndeces = frames.filter { checkCriteriaAccuracy($0.location) }
            .enumerated()
            .map{$0.offset}
        let isEnoughData: Bool = filterdFramesIndeces.count > 2 * parcialPointsCount + 1
        
        var filterdLocations = frames.map { $0.location }
        var filterdImages = images
        if(isEnoughData){
            filterdLocations = filterdLocations.enumerated()
            .filter { filterdFramesIndeces.contains($0.offset) }
            .map{$0.element}
            filterdImages = images.enumerated()
            .filter { filterdFramesIndeces.contains($0.offset) }
            .map{$0.element}
            
        }
        
        let locationPoints  = filterdLocations.map { location in
            let point = WGSLocalConverter.llaToXyz(location: location, originLocation: root)
            return simd_double2(point.x, point.z)
        }
        
        let arPoints = filterdImages.map { image in
            let point = WGSLocalConverter.llaToXyz(location: image.location, originLocation: root)
            return simd_double2(point.x, point.z)
        }
        
        let svd2d = SVD2D(locationPoints, arPoints, false)
        
        let finalTransform = svd2d.getRTMatrix3x3SVD()

        let Rz = atan2(finalTransform.columns.0.y, finalTransform.columns.0.x)

        images.forEach { image in
            var point = WGSLocalConverter.llaToXyz(location: image.location, originLocation: root)
            let newPoint = finalTransform * simd_double3(point.x, point.z, 1)

            let E = image.eulerAngles
            let eulerAngles = EulerAngles(E.x, E.y , E.z + Rz)
            point.x = newPoint.x
            point.z = newPoint.y
            let location = WGSLocalConverter.xyzToLocation(
                position: point,
                originLocation: root,
                horizontal: image.location.horizontal,
                vertical: image.location.vertical)
            
            result.append(ImageLocation(originalLocation: image.originalLocation, location: location, eulerAngles: eulerAngles))
        }
        
        return result
    }
    
    static func getPartialPointsIndeces(frames: [FrameMetadata],targetIndex:Int, count:Int) -> [Int]{
        var result: [Int] = []
        if(checkCriteriaAccuracy(frames[targetIndex].location)){
            result.append(targetIndex)
        }
        var accuratedIndecies : [(index: Int, location: LocationModel)] = frames
            .enumerated()
            .map{frame in
            return (index: frame.offset, location: frame.element.location)
            }.filter{item in checkCriteriaAccuracy(item.location)}
            
        
        var prevIndecies = accuratedIndecies.filter({$0.index < targetIndex})
        var nextIndecies = accuratedIndecies.filter({$0.index > targetIndex})
        
        if prevIndecies.isEmpty {
            result += nextIndecies.prefix(oneSideParcialPointsCount).map{item in item.index}.sorted()
            return result
        }
        
        if nextIndecies.isEmpty {
            result += prevIndecies.suffix(oneSideParcialPointsCount).map{item in item.index}.sorted()
            return result
        }
        
        result += nextIndecies.prefix(count).map{item in item.index}
        result += prevIndecies.suffix(count).map{item in item.index}
        result = result.sorted()
        return result
    }
    
    static func calculatePartialSVD2D(root: LocationModel, frames: [FrameMetadata], images: [ImageLocation], isIncludeHighAccurate:Bool = false) -> [ImageLocation] {
        
        var result : [ImageLocation] = []
        
        let isEnoughData = frames.filter{ checkCriteriaAccuracy($0.location) }.count > 2 * parcialPointsCount + 1
        
        if !isEnoughData {
            return images
        }
        
        frames.enumerated().forEach { item in
            
            let index: Int = item.offset
            let image = images[index]
            let frame = frames[index]
            var location = LocationModel(
                latitude: frame.location.latitude,
                longitude: frame.location.longitude,
                altitude: image.location.altitude,
                horizontal: frame.location.horizontal,
                vertical: frame.location.vertical)
            var eulerAngles = image.eulerAngles
            
            if(isIncludeHighAccurate || !checkCriteriaAccuracy(image.location)){
                let partialIndeces = getPartialPointsIndeces(frames: frames, targetIndex: index, count: parcialPointsCount)
                
                let arPoints = images.enumerated()
                    .filter{partialIndeces.contains($0.offset)}
                    .map{item in
                        let point = WGSLocalConverter.llaToXyz(location: item.element.location, originLocation: root)
                        return simd_double2(point.x, point.z)
                    }
                
                let locationPoints = frames.enumerated()
                    .filter{partialIndeces.contains($0.offset)}
                    .map{item in
                        let point = WGSLocalConverter.llaToXyz(location: item.element.location, originLocation: root)
                        return simd_double2(point.x, point.z)
                    }
                
                
                let svd2d = SVD2D(locationPoints, arPoints, true)
                let finalTransform = svd2d.getRTMatrix3x3SVD()
                
                let Rz = atan2(finalTransform.columns.0.y, finalTransform.columns.0.x)
                
                var point = WGSLocalConverter.llaToXyz(location: image.location, originLocation: root)
                let newPoint = finalTransform * simd_double3(point.x, point.z, 1)

                let E = image.eulerAngles
                
                eulerAngles = EulerAngles(E.x, E.y, E.z + Rz)
                point.x = newPoint.x
                point.z = newPoint.y
                
                location = WGSLocalConverter.xyzToLocation(
                    position: point,
                    originLocation: root,
                    horizontal: image.location.horizontal,
                    vertical: image.location.vertical)
                
            }
            
            result.append(ImageLocation(originalLocation: image.originalLocation, location: location, eulerAngles: image.eulerAngles))
        }
        
        return result
    }
    
    
    
    
    static func calculateVertical(root: LocationModel, frames: [FrameMetadata], images: [ImageLocation]) -> [ImageLocation] {
        
        var result : [ImageLocation] = []
        
        let isEnoughData = frames.filter{ checkCriteriaAccuracy($0.location) }.count > 2 * parcialPointsCount + 1
        
        if !isEnoughData {
            return images
        }
        
        frames.enumerated().forEach { f in
            
            let index: Int = f.offset
            let image = images[index]
            
            let partialIndeces = getPartialPointsIndeces(frames: frames, targetIndex: index, count: parcialPointsCount)
            
            let arPoints = images.enumerated()
                .filter{partialIndeces.contains($0.offset)}
                .map{item in
                    let point = WGSLocalConverter.llaToXyz(location: item.element.location, originLocation: root)
                    return point.y
                }
            
            let locationPoints = frames.enumerated()
                .filter{partialIndeces.contains($0.offset)}
                .map{item in
                    let point = WGSLocalConverter.llaToXyz(location: item.element.location, originLocation: root)
                    return point.y
                }
            
            let deltaY :Double = (locationPoints.reduce(0,+) - arPoints.reduce(0,+)) / (Double(locationPoints.count))
            
            var point = WGSLocalConverter.llaToXyz(location: image.location, originLocation: root)
            point.y += deltaY
            
            let location = WGSLocalConverter.xyzToLocation(
                position: point,
                originLocation: root,
                horizontal: image.location.horizontal,
                vertical: image.location.vertical)
            
            result.append(ImageLocation(originalLocation: image.originalLocation, location: location, eulerAngles: image.eulerAngles))
        }
        
        return result
    }
    
    
    
    static func calculateWeight(root: LocationModel, frames: [FrameMetadata], images: [ImageLocation]) -> [ImageLocation] {
        
        var result : [ImageLocation] = []
        
        let isEnoughData = frames.filter{ checkCriteriaAccuracy($0.location) }.count > 2 * parcialPointsCount + 1
        
        if !isEnoughData {
            return images
        }
        
        frames.enumerated().forEach { f in
            
            let index: Int = f.offset
            let image = images[index]
            
            let pointRtk = WGSLocalConverter.llaToXyz(location: f.element.location, originLocation: root)
            let pointMod = WGSLocalConverter.llaToXyz(location: image.location, originLocation: root)
            
            let rtkAccuracy = max(f.element.location.horizontal, f.element.location.vertical)
            let sumOfWeight = 1 / rtkAccuracy + 1 / arAccuracy
            let point = (pointMod / arAccuracy + pointRtk / rtkAccuracy) / sumOfWeight
            
            let location = WGSLocalConverter.xyzToLocation(
                position: point,
                originLocation: root,
                horizontal: image.location.horizontal,
                vertical: image.location.vertical)
            
            result.append(ImageLocation(originalLocation: image.originalLocation, location: location, eulerAngles: image.eulerAngles))
        }
        
        return result
    }
    
    static func calculateAccuracy(matrix: simd_float4x4, offset: simd_double3, source: [simd_double3], target: [simd_double3])  ->  Double {
        var result: Double = 0.0
        
        // Xar = Mm * Xrtk
        // Xrtk = Moffset * Xlocal
        // Xar = Mfinal * Xlocal
        //
        // Xar = Mfinal * Moffset.inverse * Xrtk
        // Xrtk = (Mfinal * Moffset.inverse).inverse * Xar
        
        if source.count != target.count {
            return result
        }
        
        if source.count < 3 {
            return result
        }
        
        var matrixD =  simd_double4x4(
            simd_double4(matrix.columns.0),
            simd_double4(matrix.columns.1),
            simd_double4(matrix.columns.2),
            simd_double4(matrix.columns.3)
        )
        
        return calculateAccuracy(matrix: matrixD, offset: offset, source: source, target: target)
    }
    
    static func calculateAccuracy(matrix: simd_double4x4, offset: simd_double3, source: [simd_double3], target: [simd_double3])  ->  Double {
        var result: Double = 0.0
        
        // Xar = Mm * Xrtk
        // Xrtk = Moffset * Xlocal
        // Xar = Mfinal * Xlocal
        //
        // Xar = Mfinal * Moffset.inverse * Xrtk
        // Xrtk = (Mfinal * Moffset.inverse).inverse * Xar
        
        if source.count != target.count {
            return result
        }
        
        if source.count < 3 {
            return result
        }
        
        var matrixD = matrix
        
        var offsetMatrixD: simd_double4x4 = matrix_identity_double4x4
        offsetMatrixD.columns.3 += simd_double4(offset, 0.0)
        
        matrixD = matrixD * offsetMatrixD.inverse
        
        matrixD = matrixD.inverse

        var deltas: [simd_double3] = []
        for i in 0..<source.count {
            let convertedSource = matrixD * simd_double4(source[i], 1.0)
            let convertedSource3 = simd_double3(convertedSource.x, convertedSource.y, convertedSource.z)
            
            deltas.append(convertedSource3 - target[i])
        }
        
        result = sqrt(deltas.map { pow($0.x, 2) + pow($0.y, 2) + pow($0.z, 2)}.reduce(0.0, +) / Double(source.count - 1))
        
        return result
    }
}

public class WGSLocalConverter {
    
    private static let a :Double = 6378137.0 //Semi-major axis
    private static let f: Double = 1.0/298.257223563 // Flattining
    private static let b: Double = a * (1 - f) // Semi-minor axis
    private static let e2: Double = 2 * f - f * f // Eccentricity squared
    private static let e: Double = 2 * f - f * f // Eccentricity
    
    static func llaToENU(lat: Double, lon: Double, alt: Double, originLat: Double, originLon: Double, originAlt: Double = 0.0) -> (e: Double, n: Double, u: Double) {
        let matrix = ecefToEnuMatrix(originLat: originLat, originLon: originLon)
        let originECEF = llaToEcef(lat: originLat, lon: originLon, alt: originAlt)
        let positionECEF = llaToEcef(lat: lat, lon: lon, alt: alt)
        let originECEFsimd = simd_double3(originECEF.x, originECEF.y, originECEF.z)
        let positionECEFsimd = simd_double3(positionECEF.x, positionECEF.y, positionECEF.z)
        let delta = positionECEFsimd - originECEFsimd
        let enu = matrix * delta
        return (e: enu.x, n: enu.y, u: enu.z)
    }
    
    static func llaToENU(location:LocationModel, originLocation:LocationModel) -> (e: Double, n: Double, u: Double) {
        return llaToENU(lat:location.latitude, lon: location.longitude, alt: location.altitude, originLat: originLocation.latitude, originLon: originLocation.longitude, originAlt: originLocation.altitude)
    }
    
    static func ENUToLla(e: Double, n: Double, u: Double, originLat: Double, originLon: Double, originAlt: Double = 0.0) -> (lat: Double, lon: Double, alt: Double) {
        let positionECEFsimd = enuToEcef(e: e, n: n, u: u, originLat: originLat, originLon: originLon, originAlt: originAlt)
        let location = ecefTolla(x: positionECEFsimd.x, y: positionECEFsimd.y, z: positionECEFsimd.z)
        return (lat: location.lat, lon: location.lon, alt: location.alt)
    }
    
    static func ENUToLla(e: Double, n: Double, u: Double, originLocation:LocationModel) -> (lat: Double, lon: Double, alt: Double)  {
        return ENUToLla(e:e, n: n, u: u, originLat: originLocation.latitude, originLon: originLocation.longitude, originAlt: originLocation.altitude)
    }
    
    static func xyzToLla(position: SIMD3<Double>, originLocation:LocationModel) -> (lat: Double, lon: Double, alt: Double)  {
        let enu = xyzToEnu(xyz: position)
        return ENUToLla(e:enu.e, n: enu.n, u: enu.u, originLat: originLocation.latitude, originLon: originLocation.longitude, originAlt: originLocation.altitude)
    }
    
    static func llaToXyz(location: LocationModel, originLocation:LocationModel) -> SIMD3<Double>  {
        let enu = llaToENU(lat: location.latitude, lon: location.longitude, alt: location.altitude, originLat: originLocation.latitude, originLon: originLocation.longitude, originAlt: originLocation.altitude)
        return enuToXyz(e:enu.e,n: enu.n, u: enu.u)
    }
    
    static func xyzToLocation(position: SIMD3<Double>, originLocation:LocationModel, horizontal:Double, vertical:Double) -> LocationModel {
        let enu = xyzToEnu(xyz: position)
        let lla = ENUToLla(e:enu.e, n: enu.n, u: enu.u, originLat: originLocation.latitude, originLon: originLocation.longitude, originAlt: originLocation.altitude)
        return LocationModel(latitude: lla.lat, longitude: lla.lon, altitude: lla.alt, horizontal: horizontal, vertical: vertical)
    }
    
    static func getOriginLocation(position: SIMD3<Double>, location:LocationModel, horizontal:Double=1.0, vertical:Double=1.0) -> LocationModel {
        let enu = xyzToEnu(xyz: position)
        let matrix = ecefToEnuMatrix(originLat: location.latitude, originLon: location.longitude)
        
        let enu_vector = simd_double3(enu.e, enu.n, enu.u)
        let locationEcef = llaToEcef(lat: location.latitude, lon: location.longitude, alt: location.altitude)
        let delta = matrix.inverse * enu_vector
        let ecef = SIMD3<Double>(locationEcef.x, locationEcef.y, locationEcef.z) - delta
        let lla = ecefTolla(x: ecef.x, y: ecef.y, z: ecef.z)
        return LocationModel(latitude: lla.lat, longitude: lla.lon, altitude: lla.alt, horizontal: horizontal, vertical: vertical)
    }
    
    // (lat, lon), x is (0,0), y(0, 90), z(90, -)
    private static func llaToEcef(lat: Double, lon:Double, alt: Double) -> (x:Double,y: Double,z: Double) {
        let phi = lat.radians
        let lambda = lon.radians
        
        let sin_phi = sin(phi)
        let N = a / sqrt(1 - e2 * sin_phi * sin_phi)
        
        let x = (N + alt) * cos(phi) * cos(lambda)
        let y = (N + alt) * cos(phi) * sin(lambda)
        let z = (N * (1 - e2) + alt) * sin_phi
        
        return (x: x, y: y, z: z)
    }
    private static func ecefTolla (x:Double,y: Double,z: Double) -> (lat: Double, lon:Double, alt: Double)  {
        
        let lambda = atan2(y , x)
       
        // https://pdfcoffee.com/bowring-1976-pdf-free.html
        func bowingMethod() -> Double {
            let ep = (a*a) / (b*b) - 1.0
            let p = sqrt(x*x + y*y)
            let th = atan2(a*z, b*p)
            let sinTh = sin(th)
            let cosTh = cos(th)
            
            return atan2(z + ep  * b * sinTh * sinTh * sinTh,p - e2 * a * cosTh * cosTh * cosTh)
        }
        
        let phi = bowingMethod()
        
        let N = a / sqrt(1 - e2 * sin(phi) * sin(phi))
        
        let p = sqrt(x*x + y*y)
        let alt = p/cos(phi) - N
        
        return (lat: phi.degrees, lon: lambda.degrees, alt: alt)
    }
    
    private static func ecefToEnuMatrix(originLat:Double, originLon:Double)->simd_double3x3{
        let phi = originLat.radians
        let lambda = originLon.radians
        
        let sin_phi = sin(phi)
        let cos_phi = cos(phi)
        let sin_lambda = sin(lambda)
        let cos_lambda = cos(lambda)
        return simd_double3x3(
            simd_double3(-sin_lambda,-sin_phi*cos_lambda,cos_phi*cos_lambda),
            simd_double3( cos_lambda, -sin_phi*sin_lambda, cos_phi*sin_lambda),
            simd_double3(0.0,cos_phi,sin_phi)
            )
    }
    private static func ecefToENU(x: Double, y: Double, z: Double, originLat: Double, originLon: Double, originAlt: Double = 0.0) -> (e: Double, n: Double, u: Double) {
        let matrix = ecefToEnuMatrix(originLat: originLat, originLon: originLon)
        let originECEF = llaToEcef(lat: originLat, lon: originLon, alt: originAlt)
        let originECEFsimd = simd_double3(originECEF.x, originECEF.y, originECEF.z)
        let positionECEF = simd_double3(x, y, z)
        let delta = positionECEF - originECEFsimd
        let enu = matrix * delta
        return (e: enu.x, n: enu.y, u: enu.z)
    }
    private static func enuToEcef(e: Double, n: Double, u: Double, originLat: Double, originLon: Double, originAlt: Double = 0.0) -> (x: Double, y: Double, z: Double) {
        let matrix = ecefToEnuMatrix(originLat: originLat, originLon: originLon)
        let originECEF = llaToEcef(lat: originLat, lon: originLon, alt: originAlt)
        let originECEFsimd = simd_double3(originECEF.x, originECEF.y, originECEF.z)
        let enu = simd_double3(e, n, u)
        let delta = matrix.inverse * enu
        
        let positionECEFsimd2 = originECEFsimd + delta
        return (x: positionECEFsimd2.x, y: positionECEFsimd2.y, z: positionECEFsimd2.z)
    }
    
    private static func enuToXyz(e: Double, n: Double, u: Double) -> SIMD3<Double> {
        return simd_double3(x: e, y: u, z: -n)
    }
    private static func enuToXyz(enu: SIMD3<Double>) -> SIMD3<Double> {
        return simd_double3(enu.x, enu.z, -enu.y)
    }
    private static func xyzToEnu(xyz: SIMD3<Double>) -> (e: Double, n: Double, u: Double)  {
        return (xyz.x, -xyz.z, xyz.y)
    }
    
    
}
