//
//  MetalPointClouds.swift
//  Quick3D
//
//  Created by HaNST on 6/11/25.
//

import Foundation
import Metal
import SceneKit

class MetalPointClouds {
    
    private let lock = NSLock()
    
    var data: [MetalPointCloud] = []
    let spacing: Float
    let pointSize: Int
    var writer: GLTFWriter?
    let group = DispatchGroup()
    
    weak var session: CaptureSession?
    
    init(spacing: Int, pointSize: Int) {
        self.spacing = Float(spacing)
        self.pointSize = pointSize
    }
    
    func last(_ count: Int) throws -> MetalPointCloud {
        lock.lock()
        defer {
            lock.unlock()
        }
        
        let item: MetalPointCloud
        if let last = data.last, last.canAppend(count) {
            item = last
        } else if let pointCloud = MetalManager.shared.makePointCloud(options: .storageModeShared) {
            
            if let last = data.last, let writer = self.writer {
                last.write(writer: writer, group: group)
            }
            
            item = pointCloud
            item.pointSize = pointSize
            data.append(item)
            
        } else {
            throw NSError(domain: "MetalPointClouds", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer."])
        }
        return item
    }
    
    func update() {
        session?.livePreviewContext?.updatePointClouds()
    }
    
    func append(_ pointCloud: MetalPointCloud, completion: (() -> Void)? = nil) throws {
        
        lock.lock()
        defer {
            lock.unlock()
        }
        
        let item: MetalPointCloud
        if let last = data.last, last.canAppend(pointCloud) {
            item = last
        } else {
            if let last = data.last, let writer = self.writer {
                last.write(writer: writer, group: group)
            }
            let pointCloud = MetalManager.shared.makePointCloud(options: .storageModeShared)
            
            if pointCloud == nil {
                throw NSError(domain: "MetalPointClouds", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer."])
            }
            
            item = pointCloud!
            item.pointSize = pointSize
            data.append(item)
            session?.livePreviewContext?.updatePointClouds()
        }
        
        MetalManager.shared.copy(source: pointCloud, destination: item) { [weak self] destination, _ in
            guard let self = self else { return }
            if let writer = self.writer {
                destination.write(writer: writer, group: self.group)
            }
            completion?()
        }
    }
    
    func write() {
        group.wait()
        if let writer = self.writer {
            // Ghi xong buffer này mới dispatch buffer sau. write(force:) đẩy mỗi 100k điểm
            // thành một job async, mà mỗi job copy ~3.2MB ra Swift Array rồi chờ writer.lock —
            // dispatch tất cả buffer một lượt làm peak RAM lúc save tăng theo độ lớn session.
            data.forEach {
                $0.write(writer: writer, group: group, force: true)
                group.wait()
            }
        }
    }
}
