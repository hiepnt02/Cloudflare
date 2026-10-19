//
//  CSVWriter.swift
//  Quick3D
//
//  Created by HaNST on 17/12/24.
//

import Foundation

class CSVWriter {
    
    private let fileUrl: URL
    private let canAppend: Bool
    private var data: [[String]] = []
    
    private let maxRow = 1000
    
    private var time: Date?
    
    private let lock = NSLock()
    
    var onError: ((Error) -> Void)? = nil
    
    init(_ headers: [String], fileUrl: URL, canAppend: Bool = true) {
        self.fileUrl = fileUrl
        
        if !headers.isEmpty {
            self.data.append(headers)
        }
        
        self.canAppend = canAppend
        
        if !canAppend {
            if FileManager.default.fileExists(atPath: fileUrl.path) {
                try? FileManager.default.removeItem(at: fileUrl)
            }
        }
    }
    
    func append(_ row: [String],_ deltaTime: Double = 1) {
        
        lock.lock()
        defer {
            lock.unlock()
        }
        
        if row.isEmpty {
            return
        }
        
        let d = Date()
        
        if let t = time {
            if d.timeIntervalSince1970 - t.timeIntervalSince1970 > deltaTime {
                time = d
            } else {
                return
            }
        } else {
            time = Date()
        }
        
//            print("LOG: \(row)")
        
        data.append(row)
        
        if data.count >= maxRow {
            writeFile()
        }
    }
    
    private func writeFile() {
        let text = data.map { $0.joined(separator: ",")}.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: "\n")
        StorageManager.write(fileUrl, text: text, canAppend: canAppend)
        data = []
    }
    
    func write() {
        lock.lock()
        defer {
            lock.unlock()
        }
        writeFile()
    }
    
    func clear() {
        lock.lock()
        defer {
            lock.unlock()
        }
        if FileManager.default.fileExists(atPath: fileUrl.path) {
            try? FileManager.default.removeItem(at: fileUrl)
        }
    }
    
}

