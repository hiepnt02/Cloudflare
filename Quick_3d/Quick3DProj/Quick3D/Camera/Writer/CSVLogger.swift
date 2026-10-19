//
//  CSVLogger.swift
//  Quick3D
//
//  Created by HaNST on 16/10/25.
//

import Foundation

class CSVLogger {
    
    private let file: CSVWriter
    private let url: URL
    
    var onError: ((Error) -> Void)? {
        set(value) {
            file.onError = value
        }
        get {
            file.onError
        }
    }
    
    init(_ headers: [String] = [], fileUrl: URL, canAppend: Bool = true) {
        url = fileUrl
        file = CSVWriter(headers, fileUrl: fileUrl, canAppend: canAppend)
    }
    
    func log(_ row: [String],_ deltaTime: Double = 1) {
        file.append(row, deltaTime)
    }
    
    func write() {
        file.write()
    }
    
    func clear() {
        file.clear()
    }
    
    func read(removeHeader: Bool = false) -> String? {
        guard let data = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        var rows = data.components(separatedBy: "\n")
        if removeHeader {
            rows.removeFirst()
        }
        return rows.joined(separator: "\n")
    }
    
    func readLines(removeHeader: Bool = false) -> [String] {
        guard let data = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        var rows = data.components(separatedBy: "\n")
        if removeHeader {
            rows.removeFirst()
        }
        return rows
    }
}

