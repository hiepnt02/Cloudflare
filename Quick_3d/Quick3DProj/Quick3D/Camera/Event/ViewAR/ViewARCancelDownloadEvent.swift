//
//  ViewARCancelDownloadEvent.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import Foundation

class ViewARCancelDownloadEvent: EventIdentity, ViewAREvent {
    
    func call(_ context: ViewARContext) {
        context.cancel()
    }
}
