//
//  ARPositionStepEnum.swift
//  Quick3D
//
//  Created by HungNT on 8/1/26.
//

import Foundation

// Enum for step distance when move ARView
enum ARPositionStepEnum: String, CaseIterable, Identifiable {
    
    case oneThousandMM, oneHundredMM, tenMM, oneMM, pointOneMM
    
    var id: String { rawValue }
    
    func getText(_ lang: String) -> String {
        switch self {
        case .oneMM:
            return "1"
        case .tenMM:
            return "10"
        case .oneHundredMM:
            return "100"
        case .oneThousandMM:
            return "1000"
        case .pointOneMM:
            return "0.1"
        }
    }
    
    func getStepValue() -> Decimal {
        switch self {
        case .oneMM:
            return 1
        case .tenMM:
            return 10
        case .oneHundredMM:
            return 100
        case .oneThousandMM:
            return 1000
        case .pointOneMM:
            return 0.1
        }
    }
    
    func getDegree() -> Decimal {
        switch self {
        case .oneMM:
            return 1
        case .tenMM:
            return 10
        case .oneHundredMM:
            return 100
        case .oneThousandMM:
            return 1000
        case .pointOneMM:
            return 0.1
        }
    }
}
