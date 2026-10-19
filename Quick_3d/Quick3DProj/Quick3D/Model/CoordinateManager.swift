//
//  CoordinateManager.swift
//  Quick3D
//
//  Created by HungNT on 5/1/25.
//

import Foundation

class CoordinateManager {
    static let shared = CoordinateManager()
    
    private init() { }
    
    var username: String?
    var horizontalCoordinates: [String: String] = [:]
    var verticalCoordinates: [String: String] = [:]
    
    func getHCoordinates() -> [String: String] {
        if horizontalCoordinates.isEmpty {
            getHCoordinatesFromJson()
        }
        return horizontalCoordinates
    }
    
    func getVCoordinates() -> [String: String] {
        if verticalCoordinates.isEmpty {
            getVCoordinatesFromJson()
        }
        return verticalCoordinates
    }
    
    func getHCoordinateLabel(coordinateKey: String?) -> String? {
        if let coordinateKey = coordinateKey {
            if (horizontalCoordinates.isEmpty) {
                getHCoordinatesFromJson()
            }
            return horizontalCoordinates[coordinateKey]
        }
        return nil
    }
    
    func getVCoordinateLabel(coordinateKey: String?) -> String? {
        if let coordinateKey = coordinateKey {
            if (verticalCoordinates.isEmpty) {
                getVCoordinatesFromJson()
            }
            return verticalCoordinates[coordinateKey]
        }
        return nil
    }
    
    func getHCoordinatesFromJson() {
        if let url = Bundle.main.url(forResource: "coordinateData", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]]
                guard let jsonArray = jsonArray else {
                    print("Error when parsing JSON")
                    return
                }
                
                for item in jsonArray {
                    guard let epsgCode = item.keys.first, let description = item[epsgCode] as? String else { continue }
                    horizontalCoordinates[epsgCode] = description
                }
            } catch {
                print("Exception when parsing data from JSON: \(error)")
            }
        }
    }
    
    func getVCoordinatesFromJson() {
        if let url = Bundle.main.url(forResource: "verticalCoordinateData", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]]
                guard let jsonArray = jsonArray else {
                    print("Error when parsing JSON")
                    return
                }
                
                for item in jsonArray {
                    guard let epsgCode = item.keys.first, let description = item[epsgCode] as? String else { continue }
                    verticalCoordinates[epsgCode] = description
                }
            } catch {
                print("Exception when parsing data from JSON: \(error)")
            }
        }
    }
}
