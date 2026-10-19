//
//  CameraContextTemplate.swift
//  Quick3D
//
//  Created by Admin on 9/3/26.
//

import Foundation
import ARKit

open class CameraContextTemplate: NSObject {
    
    let queue = DispatchQueue(label: "ltd.landlog.scquick3d.CameraContextTemplate", attributes: [])

    private var eventLast: Int = -1
 
    private var isPaused: Bool = false
    
    public private(set) var view: ARSCNView?
    
    func handle(_ event: Event, execute: @escaping () -> Void) {
        queue.async { [weak self] in
            if self?.eventLast != event.id {
                self?.eventLast = event.id
                execute()
            }
        }
    }
    
    func setup(_ view: ARSCNView) {
        self.view = view
    }
    
    func clear() {
        self.view?.session.delegate = nil
        self.view?.delegate = nil
        self.view = nil
    }
    
    func pause() {
        if !isPaused, let session = self.view?.session {
            session.pause()
            isPaused = true
        }
    }
    
    func resume() {
        if isPaused, let session = self.view?.session {
            session.run(configuration(), options: [])
            isPaused = false
        }
    }
    
    func start() {
        if let session = self.view?.session {
            session.run(configuration(), options: options())
        }
    }
    
    func restart() {
        pause()
        start()
    }
    
    func configuration() -> ARConfiguration {
        return ARWorldTrackingConfiguration()
    }
    
    func options() -> ARSession.RunOptions {
        return []
    }
}

class CameraVideoFormatHelper {
    
    static let maxFramesPerSecond: Int = 30

    static let videoFromats: [ImageResolutionEnum: ARConfiguration.VideoFormat ] = {
        
        let availableFormats = ARWorldTrackingConfiguration.supportedVideoFormats

        let normalResolution = availableFormats[0].imageResolution
        
        let fourKResolution = CGSize(width: 3840, height: 2160)
        
        var normalFormat: ARConfiguration.VideoFormat?
        
        var fourKFormat: ARConfiguration.VideoFormat?
        
        var highFormat: ARConfiguration.VideoFormat?
        
        var formats = availableFormats.filter {
            $0.captureDeviceType == .builtInWideAngleCamera
            && $0.captureDevicePosition == .back
            && $0.framesPerSecond <= maxFramesPerSecond
        }.sorted { $0.framesPerSecond > $1.framesPerSecond  }
        
        for format in formats {
            if normalFormat == nil && format.imageResolution == normalResolution {
                normalFormat = format
            }
            if fourKFormat == nil && format.imageResolution == fourKResolution {
                fourKFormat = format
            }
            if #available(iOS 16.0, *) {
                if highFormat == nil && format.imageResolution == normalResolution && format.isRecommendedForHighResolutionFrameCapturing {
                    highFormat = format
                }
            }
        }
        
        var result: [ImageResolutionEnum: ARConfiguration.VideoFormat ] = [:]
        
        if let normal = normalFormat {
            result[.normal] = normal
        }
        
        if let fourK = fourKFormat {
            result[.fourK] = fourK
        }
        
        if let high = highFormat {
            result[.maximum] = high
        }
        
        return result
    }()
    
}
