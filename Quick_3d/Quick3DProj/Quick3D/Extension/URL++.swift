//
//  URL++.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 22/04/2022.
//

import Foundation

extension URL {
    var isImageFile: Bool {
        return lastPathComponent.fileExtension == "jpg" || lastPathComponent.fileExtension == "png"
    }
    
    var isPLYFile: Bool {
        return lastPathComponent.fileExtension == "ply"
    }

    var isNdJson: Bool {
        return lastPathComponent.fileExtension == "ndjson"
    }
    
    var isGLTFFile: Bool {
        return lastPathComponent.fileExtension == "gltf"
    }
    
    var isZipFile: Bool {
        return lastPathComponent.fileExtension == "zip"
    }
    
    // Get file size from local URL file.
    // - Returns: File size by bytes, return nil if cannot find or error happend.
    var fileSize: Int? {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: self.path)
            return fileAttributes[.size] as? Int
        } catch {
            print("Failed to get file attributes for \(self.path) with error: \(error.localizedDescription)")
            return nil
        }
    }
}
