//
//  ImageOperation.swift
//  Quick3D
//
//  Created by HaNST on 4/2/26.
//

import Foundation
import CoreImage

class ImageOperation: FrameOperation, @unchecked Sendable {
    
    override func process() throws {
        
        guard let session = self.session, let frame = self.frame else { return }
        
        do {
            
            let pointCloudOperation = MetalManager.shared.isPrefixSumSupported ? MetalPointCloudOperation(session, frame: frame) : DefaultPointCloudOperation(session, frame: frame)
            try pointCloudOperation.process()
            
            let image = try JpegImage(
                session,
                fileName: frame.imageName,
                data: frame.capturedImage,
                imgId: frame.id,
            )
            
            let _ = try DepthImage(
                session,
                fileName: frame.depthMapImageName,
                data: frame.depthMap,
                imgId: frame.id
            )
            
            let _ = try DepthConfidenceImage(
                session,
                fileName: frame.confidenceMapImageName,
                data: frame.confidenceMap,
                imgId: frame.id
            )
            
            let imgUrl = image.fileURL
            
            var meta = JpegMetadataCache(fileURL: imgUrl, imgId: frame.id)
            
            meta.setSubsecTimeOriginal(frame.exif["SubsecTimeOriginal"] as? String)
            meta.setCoordinate(frame.location.coordinate)
            if let location = frame.rtkLocation {
                meta.setRTKLocation(
                    location,
                    rtkId: RTKManager.shared.id,
                    rtkSerialNumber: RTKManager.shared.serialNumber
                )
            }
            
            // Write logs
            session.add(FrameMetadata(frame), meta: meta)
            
            // Logging
            session.catchLogger.startCapture(frame)
            session.catchLogger.appendPhotoTaken(
                imageName: frame.imageNameWithoutExtension,
                info: frame,
                eulerAngles: EulerAnglesModel.transform(
                    eulerAngles: frame.eulerAngles
                )
            )
            session.locationLogger.appendRaw(
                image: frame.imageNameWithoutExtension,
                location: frame.location
            )
            
        } catch {
            print("JPEG Error \(error)")
            session.sessionLogger.logProcessing("image", "processError", level: .error, ["error": "\(error)"])
            throw error
        }
    }
}
