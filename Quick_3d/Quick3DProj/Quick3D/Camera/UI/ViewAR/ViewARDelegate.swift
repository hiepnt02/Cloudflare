//
//  ViewARDelegate.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import Foundation

protocol ViewARDelegate {
    
    func ar(_ project: SfmProject?, didStart isReady: Bool)
    
    func ar(_ project: SfmProject?, error: Error)
 
    func ar(_ project: SfmProject?, willCalculate offset: SIMD3<Double>)
    
    func ar(_ project: SfmProject?, didCalculate offset: SIMD3<Double>)
    
    func ar(_ project: SfmProject?, didFailToCalculate error: Error)
    
    func ar(_ project: SfmProject?, didFailToDownload code: Int)
    
    func ar(_ project: SfmProject?, didFailToDownloadPointCloud error: Error)
    
    func ar(_ project: SfmProject?, didFailToDownloadIFC error: Error)
    
    func ar(_ project: SfmProject?, willDownload projectId: String)
    
    func ar(_ project: SfmProject?, didDownload offset: SIMD3<Double>)
    
    func ar(_ project: SfmProject?, didDownloadPointCloudItem offset: SIMD3<Double>)
    
    func ar(_ project: SfmProject?, didDownloadPointCloud offset: SIMD3<Double>)
    
    func ar(_ project: SfmProject?, didDownloadIFC layers: [LayerNode])
    
    func ar(_ project: SfmProject?, onPointCloudProgressChanged progress: Double)
    
    func ar(_ project: SfmProject?, arPositionDidMatch: Bool)
}
