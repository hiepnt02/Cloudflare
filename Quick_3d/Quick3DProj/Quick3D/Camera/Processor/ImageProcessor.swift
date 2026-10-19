//
//  ImageProcessor.swift
//  Quick3D
//
//  Created by HaNST on 06/03/26.
//

import Foundation
import ARKit

final class ImageProcessor: FrameProcessor {
    
    var isLimited: Bool { false }
    
    func process(
        _ session: CaptureSession,
        frame: FrameData,
        onCompleted: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        let job = ImageOperation(session, frame: frame)
        job.onError = onError
        job.onCompleted = onCompleted
        job.execute()
    }
    
    func waitUntilCompleted() {
    }
    
    func cancel() {
    }
    
    func combine() async throws {
        guard let session = CaptureSession.current else {
            return
        }
        
        let frames = ImageCalculator.updateRTKLocations(session.frames)
        let metas = session.metas
        
        let initLocation = ImageCalculator.calculateInitImageLocation(frames)
        let arfittedLocations = ImageCalculator.calculateARFitted(frames: frames, root: initLocation.root, images: initLocation.images)
        let locations = ImageCalculator.calculateGeoFusionFromARFitted(frames: frames, root: arfittedLocations.root, images: arfittedLocations.images)
        let averageFocalLegnth = ImageCalculator.averageFocalLegnth(frames)

        let highAccuracyFrame: FrameMetadata? = session.getHighAccuracyFrame()
        let deferPhotoUpdated = session.isEligibleForGlobalCorrection

        for index in 0..<metas.count {
            let frame = frames[index]
            var meta = metas[index]
            let imageArFitted = arfittedLocations.images[index]
            let imageCalculated = locations.images[index]
            
            meta.setFocalLengthPixel(averageFocalLegnth.focalLength, 960, 720)
            meta.setGPSLocation(imageCalculated.location)
            meta.setEulerAngles(eulerAngles: imageCalculated.eulerAngles)
            
            if let highAccuracyFrame = highAccuracyFrame, !frame.isRTK {
                let simdCoordinate = frame.gpsLocation.simdCoordinate + highAccuracyFrame.rtkLocation!.simdCoordinate - highAccuracyFrame.gpsLocation.simdCoordinate
                
                let rtk = LocationModel(latitude: simdCoordinate.z,
                                        longitude: simdCoordinate.x,
                                        altitude: simdCoordinate.y,
                                        horizontal: frame.gpsLocation.horizontal,
                                        vertical: frame.gpsLocation.vertical,
                                        coordinate: highAccuracyFrame.rtkLocation!.coordinate)
                
                meta.setCoordinate(rtk.coordinate)
                meta.setRTKLocation(rtk,
                    rtkId: highAccuracyFrame.rtkId,
                    rtkSerialNumber: highAccuracyFrame.rtkSerialNumber
                )
            }
            
            meta.setTimeExport(date: frame.timestamp)
            try exportJpeg(meta: meta)
            
            session.locationLogger.appendAR(
                image: frame.imageNameWithoutExtension,
                location: imageCalculated.originalLocation,
                eulerAngles: Transformation(frame.transform, order: .yxz).eulerAngles
            )

            session.locationLogger.appendARFitted(
                image: frame.imageNameWithoutExtension,
                location: imageArFitted.location,
                eulerAngles: imageArFitted.eulerAngles
            )
            
            session.locationLogger.appendRTKOffsetSampled(
                image: frame.imageNameWithoutExtension,
                location: frame.location,
                eulerAngles: imageArFitted.eulerAngles
            )
            
            session.locationLogger.appendGeofusion(
                image: frame.imageNameWithoutExtension,
                location: imageCalculated.location,
                eulerAngles: imageCalculated.eulerAngles
            )

            // Phiên có RTK fix: photoUpdated được dời sang CaptureSession.export() để ghi
            // với pose đã hiệu chỉnh sau khi biết kết quả regeneration (QUICK-915).
            if !deferPhotoUpdated {
                session.catchLogger.appendPhotoUpdated(
                    imageName: frame.imageNameWithoutExtension,
                    transform: frame.transform,
                    gps: imageCalculated.location,
                    eulerAngles: imageCalculated.eulerAngles
                )
            }
        }

        session.setCorrectedLocations(root: locations.root, locations: locations.images)
        session.flushLocation(locations.root)
    }
    
    private func exportJpeg(meta: JpegMetadataCache) throws {
        // 1. Verify metadata
        guard let metadata = meta.metadata else {
            throw ExportJpegError.missingMetadata
        }
        
        // 2. Validate image source
        guard let imageSource = CGImageSourceCreateWithURL(meta.fileURL as CFURL, nil) else {
            throw ExportJpegError.invalidImageSource
        }
        
        // 3. Validate image destination
        guard let destination = CGImageDestinationCreateWithURL(meta.fileURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ExportJpegError.cannotCreateDestination
        }
        
        // 4. Perform image copy with metadata
        let options: CFDictionary = [
            kCGImageDestinationMetadata: metadata
        ] as CFDictionary
        
        if !CGImageDestinationCopyImageSource(destination, imageSource, options, nil) {
            throw ExportJpegError.failedToCopyMetadata
        }
        
        // 5. Update GPS data
        do {
            try ImageDataHelper.updateGPSData(meta.fileURL, latitude: meta.latitude, longitude: meta.longitude)
        } catch {
            throw ExportJpegError.gpsUpdateFailed(error)
        }
    }
}

enum ExportJpegError: LocalizedError {
    case missingMetadata
    case invalidImageSource
    case cannotCreateDestination
    case failedToCopyMetadata
    case gpsUpdateFailed(Error)

    var errorDescription: String? {
        switch self {
        case .missingMetadata:
            return "Metadata is missing or invalid."
        case .invalidImageSource:
            return "Unable to create image source from the provided URL."
        case .cannotCreateDestination:
            return "Failed to create image destination for JPEG export."
        case .failedToCopyMetadata:
            return "An error occurred while copying metadata to the image."
        case .gpsUpdateFailed(let error):
            return "Failed to update GPS data: \(error.localizedDescription)"
        }
    }
}
