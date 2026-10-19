//
//  ViewARCalculationSettingEvent.swift
//  Quick3D
//
//  Created by HaNST on 02/02/26.
//

import Foundation

class ViewARCalculationSettingEvent: EventIdentity, ViewAREvent {

    private let positionHistoryMaxSize: Int
    private let positionHistoryHorizontal: Double
    private let positionHistoryDistance: Double
    
    init(
        positionHistoryMaxSize: Int,
        positionHistoryHorizontal: Double,
        positionHistoryDistance: Double
    ) {
        self.positionHistoryMaxSize = positionHistoryMaxSize
        self.positionHistoryHorizontal = positionHistoryHorizontal
        self.positionHistoryDistance = positionHistoryDistance
    }
    
    func call(_ context: ViewARContext) {
        context.positionHistoryMaxSize = positionHistoryMaxSize
        context.positionHistoryHorizontal = positionHistoryHorizontal
        context.positionHistoryDistance = positionHistoryDistance
    }
}
