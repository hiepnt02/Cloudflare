//
//  DocumentPicker.swift
//  Quick3D
//
//  Created by ryoma.terai on 2024/09/09.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum FileType {
    case las
    case ifc
    case xml
    case zip
    case tif
    case json
    case dxf
    case ply
    case fbx
    case glb
    case dwg
}

let FileTypes: [FileType: UTType] = [
    FileType.las: UTType(tag: "las", tagClass: .filenameExtension, conformingTo: UTType.data)!,
    FileType.ifc: UTType(tag: "ifc", tagClass: .filenameExtension, conformingTo: UTType.data)!,
    FileType.xml: UTType.xml,
    FileType.zip: UTType.zip,
    FileType.tif: UTType(tag: "tif", tagClass: .filenameExtension, conformingTo: UTType.data)!,
    FileType.json: UTType.json,
    FileType.dxf: UTType(tag: "dxf", tagClass: .filenameExtension, conformingTo: UTType.data)!,
    FileType.ply: UTType(tag: "ply", tagClass: .filenameExtension, conformingTo: UTType.data)!,
    FileType.fbx: UTType(filenameExtension: "fbx") ?? UTType(tag: "fbx", tagClass: .filenameExtension, conformingTo: UTType.data)!,
    FileType.glb: UTType(filenameExtension: "glb") ?? UTType(tag: "glb", tagClass: .filenameExtension, conformingTo: UTType.data)!,
    FileType.dwg: UTType(filenameExtension: "dwg") ?? UTType(tag: "dwg", tagClass: .filenameExtension, conformingTo: UTType.data)!
]

struct DocumentPicker: UIViewControllerRepresentable {
    
    var selectTypes: [UTType]
    var callback: (
        URL?, // Url of file selected
        String? // Name of file selected
    ) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(callback: callback)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var callback: (URL?, String?) -> Void
        
        init(callback: @escaping (URL?, String?) -> Void) {
            self.callback = callback
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                // Initiate access to a secured resource
                guard url.startAccessingSecurityScopedResource() else {
                    print("Could not obtain security scope access")
                    return
                }
                
                // Release when you're done accessing
                defer {
                    url.stopAccessingSecurityScopedResource()
                }
                
                // Get the URL of the document directory
                let fileManager = FileManager.default
                if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                    // Preserve the file name and specify the path to copy the file to the URL of the document directory
                    let destinationURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)
                    
                    let originPath = URL(fileURLWithPath: url.path)
                    let destinationPath = URL(fileURLWithPath: destinationURL.path)

                    // Convert to NSString and normalize paths
                    let originPathNorm = (originPath.path as NSString).standardizingPath
                    let destinationPathNorm = (destinationPath.path as NSString).standardizingPath
                    
                    // In case the destination file is the original file
                    // (copying a file to the exact file, it is necessary to skip the copy)
                    if originPathNorm == destinationPathNorm {
                        let selectedFileName = getFileName(url: url)
                        callback(url, selectedFileName)
                        return
                    }
                    
                    do {
                        // Copy the file
                        if fileManager.fileExists(atPath: destinationURL.path) {
                            // If the file already exists, delete it before overwriting it.
                            try fileManager.removeItem(at: destinationURL)
                        }
                        try fileManager.copyItem(at: url, to: destinationURL)
                        print("File copied: \(destinationURL)")
                        let selectedFileName = getFileName(url: destinationURL)
                        callback(destinationURL, selectedFileName)
                    } catch {
                        print("Failed to copy file: \(error)")
                        callback(nil, nil)
                    }
                }
            }
        }
        
        private func getFileName(url: URL) -> String {
            if let lastSlashIndex = url.absoluteString.lastIndex(of: "/") {
                return String(url.absoluteString[url.absoluteString.index(after: lastSlashIndex)...])
            }
            
            return ""
        }
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        var picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        picker = UIDocumentPickerViewController(forOpeningContentTypes: selectTypes)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}

