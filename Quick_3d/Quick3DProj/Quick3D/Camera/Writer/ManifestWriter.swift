//
//  ManifestModel.swift
//  Quick3D
//
//  Created by HaNST on 26/11/24.
//

import Foundation

class ManifestWriter {

    private let session: CaptureSession
    
    init(_ session: CaptureSession) {
        self.session = session
    }
    
    func write() throws {
        StorageManager.waitUntilCompleted()
        let logFiles = try getAllLogFiles(session.url)
        let inputs = try getAllPhotoFiles(session.url)
        
        let model = ManifestModel(logFiles: logFiles, inputs: inputs)
        let jsonData = try JSONEncoder().encode(model)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        let manifestURL = session.url.appendingPathComponent("manifest.json")
        
        StorageManager.write(manifestURL, text: jsonString)
        StorageManager.waitUntilCompleted()
    }

    private func getAllPhotoFiles(_ folder: URL, prefix: String = "") throws -> [ImageOutputModel] {
        var files: [ImageOutputModel] = []

        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: session.url,
            includingPropertiesForKeys: nil
        )

        try fileURLs.filter { url in
            let name = url.lastPathComponent
            return name.hasSuffix(".jpg")
        }.forEach { url in
            let photoFile = url.lastPathComponent
            let index = try getPhotoIndex(photoFile)

            let depthFile = "DepthMap_\(index).tiff"
            let confidenceFile = "Confidence_\(index).tiff"

            let parentUrl = url.deletingLastPathComponent()

            if !FileManager.default.fileExists(
                atPath: parentUrl.appendingPathComponent(depthFile).path
            ) {
                throw NSError(
                    domain: "ManifestWriter",
                    code: 0,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Cannot detect depth file."
                    ]
                )
            }

            if !FileManager.default.fileExists(
                atPath: parentUrl.appendingPathComponent(confidenceFile).path
            ) {
                throw NSError(
                    domain: "ManifestWriter",
                    code: 0,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Cannot detect confidence file."
                    ]
                )
            }

            let model = ImageOutputModel(
                depthMap: depthFile,
                photo: photoFile,
                depthMapConfidence: confidenceFile
            )

            files.append(model)
        }

        return files
    }

    private func getPhotoIndex(_ name: String) throws -> String {
        let parts = name.components(separatedBy: "_")
        if parts.count > 1 {
            let lastPart = parts[1]
            if let number = lastPart.components(separatedBy: ".").first {
                return number
            }
        }
        throw NSError(
            domain: "ManifestWriter",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Cannot detect photo index."]
        )
    }

    private func getAllLogFiles(_ folder: URL, prefix: String = "") throws -> [String] {
        var files: [String] = []

        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        )

        try fileURLs.filter { url in
            let name = url.lastPathComponent
            return !name.hasSuffix(".jpg") && !name.hasSuffix(".tiff")
        }.forEach { url in
            if try isDirectory(url: url) {
                files += try getAllLogFiles(
                    url,
                    prefix: "\(url.lastPathComponent)/"
                )
            } else {
                files.append("\(prefix)\(url.lastPathComponent)")
            }
        }

        return files
    }

    func isDirectory(url: URL) throws -> Bool {
        let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
        return resourceValues.isDirectory ?? false
    }

}
