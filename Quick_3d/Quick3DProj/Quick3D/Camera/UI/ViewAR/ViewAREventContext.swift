//
//  ViewAREventContext.swift
//  Quick3D
//
//  Created by HaNST on 15/7/26.
//

import Foundation

protocol ViewAREventContext: AnyObject {
    
    var positionHistoryMaxSize: Int { set get }

    var positionHistoryHorizontal: Double { set get }

    var positionHistoryDistance: Double { set get }

    var isAllowARUpdatePosition: Bool { set get }
    
    var arUpdatePosition: Bool { set get }
    
    func cancel()
    
    func updatePointCloudSize(to newSize: CGFloat)
    
    func downloadARProject(projectId: String, isAR: Bool)
    
    func setOpacity(for node: LayerNode?, opacity: Double)
    
    func setVisible(for node: LayerNode?, visible: Bool)
    
    func updateARPosition(position: SIMD3<Float>, eulerAngles: SIMD3<Float>, scale: Float) 
    
    func setLightNodeVisible(_ visible: Bool)
    
    func toggleOcclusion(isEnabled: Bool)
    
    func setPointCloudOpacity(_ opacity: CGFloat)
    
    func setPointCloudVisible(_ visible: Bool)
    
    func setAxisVisible(_ visible: Bool)
}
