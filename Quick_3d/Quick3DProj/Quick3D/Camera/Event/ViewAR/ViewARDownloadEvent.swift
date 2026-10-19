//
//  ViewARDownloadEvent.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import Foundation

class ViewARDownloadEvent: EventIdentity, ViewAREvent {
    
    let projectId: String
    let isAR: Bool
    
    init(projectId: String, isAR: Bool) {
        self.projectId = projectId
        self.isAR = isAR
    }
    
    func call(_ context: ViewARContext) {
        context.downloadARProject(projectId: projectId, isAR: isAR)
    }
}
