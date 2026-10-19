//
//  ManualCalibrationDelegate.swift
//  Quick3D
//

import Foundation

protocol ManualCalibrationDelegate {

    func calibration(didUpdate selection: CalibrationSelection)

    func calibration(didComplete result: CalibrationResult)

    func calibration(didFail error: Error)

}
