//
//  Encodable++.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 22/05/2023.
//

import Foundation

extension Encodable {
    func toJson() -> [String: Any]? {
        guard
            let data = try? JSONEncoder().encode(self),
            let object = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
            let json = object as? [String: Any]
        else {
            return nil
        }

        return json
    }
}
