//
//  DocumentPicker.swift
//  Quick3D
//
//  Created by ryoma.terai on 2024/09/10.
//

import SwiftUI
import UIKit

struct DocumentPicker: UIViewControllerRepresentable {
    
    var callback: (URL) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(callback: callback)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var callback: (URL) -> Void
        
        init(callback: @escaping (URL) -> Void) {
            self.callback = callback
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                callback(url)
            }
        }
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}

