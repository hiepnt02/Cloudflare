//
//  GeoCoordinateHelper.swift
//  Quick3D
//
//  Created by MOR on 5/2/25.
//

import Foundation

class GeoCoordinateHelper {
    static let shared = GeoCoordinateHelper()
    private init() { }
    private var geoCoordinate: [CoordinateSystemNtripModel] = []
    
    func getGeoCoordinateLabel() -> [CoordinateSystemNtripModel] {
        if (geoCoordinate.isEmpty) {
            getGeoCoordinatesFromJson()
        }
        return geoCoordinate
    }

    func getSortedGeoCoordinateLabel(counts: [String: Int]) -> [CoordinateSystemNtripModel] {
        if geoCoordinate.isEmpty {
            getGeoCoordinatesFromJson()
        }
        return geoCoordinate.enumerated()
            .sorted { lhs, rhs in
                let l = counts[lhs.element.code, default: 0]
                let r = counts[rhs.element.code, default: 0]
                if l != r { return l > r }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
    
    private func getGeoCoordinatesFromJson() {
        if let url = Bundle.main.url(forResource: "GeoCoordinateData", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]]
                guard let jsonArray = jsonArray else {
                    print("Error when parsing JSON")
                    return
                }
                
                for item in jsonArray {
                    guard let coordinateKey = item.keys.first, let description = item[coordinateKey] as? String else { continue }
                    let splitName = description.components(separatedBy: ":")
                    if splitName.count == 2 {
                        let code = splitName.first ?? ""
                        let name = splitName[1]
                        geoCoordinate.append(CoordinateSystemNtripModel(code: code, name: name, id: coordinateKey))
                    }
                }
            } catch {
                print("Exception when parsing data from JSON: \(error)")
            }
        }
    }
}
