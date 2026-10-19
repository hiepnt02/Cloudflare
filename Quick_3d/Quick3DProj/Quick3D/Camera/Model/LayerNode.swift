//
//  LayerNode.swift
//
//  Created by Admin on 13/10/25.
//

import Foundation
import Combine
import ZIPFoundation

struct IFCMetadata {
    let xformName: String
    let name: String?
    let type: String?
    let guid: String?
    let label: String?
}

struct USDZMetadata: Codable {
    let offset: [Double]
   
    func getOffset() -> SIMD3<Double> {
        SIMD3(x: offset[0], y: offset[2], z: -offset[1])
    }
}

class LayerNode: Identifiable, ObservableObject {
    let id : String
    let displayName: String?
    let name: String
    let type: String
    let depth: Int
    
    @Published var isVisible: Bool = true
    @Published var isExpanded: Bool = false
    @Published var children: [LayerNode] = []
    @Published var opacity: Double = defaultOpacity
    @Published var isSelected: Bool = false
    
    static let defaultOpacity: Double = 0.7
    
    var isIfcBuildingElementProxy: Bool {
        return type == "IfcBuildingElementProxy"
    }
    
    var title: String {
        let result: String = displayName ?? name
        return result.hasPrefix("N_") ? String(result.dropFirst(2)) : result
    }
    
    weak var parent: LayerNode? {
        didSet {
            parentCancellable?.cancel()
            parentCancellable = parent?.objectWillChange.sink { [weak self] in
                Task { @MainActor in
                    self?.objectWillChange.send()
                }
            }
        }
    }
    
    private var parentCancellable: AnyCancellable?
    
    init(id: String, name: String, displayName: String?, type: String, depth: Int, children: [LayerNode] = [], isVisible: Bool = true, isExpanded: Bool = false, isSelected: Bool = false, opacity: Double = defaultOpacity) {
        self.id = id
        self.name = name
        self.depth = depth
        self.displayName = displayName
        self.type = type
        self.isVisible = isVisible
        self.isExpanded = isExpanded
        self.children = children
        self.children.forEach { $0.parent = self }
        self.isSelected = isSelected
        self.opacity = opacity
    }
    
    // 🔥 Effective visibility = parent must be visible too
    var isEffectivelyVisible: Bool {
        if let parent = parent {
            return isVisible && parent.isEffectivelyVisible
        } else {
            return isVisible
        }
    }
    
    func applyOpacity(_ value: Double) {
        self.opacity = value
        for child in children {
            child.applyOpacity(value)
        }
    }
}

extension LayerNode {
    func copyWith(children: [LayerNode]) -> LayerNode {
        return LayerNode(
            id: self.id,
            name: self.name,
            displayName: self.displayName,
            type: self.type,
            depth: self.depth,
            children: children,
            isVisible: self.isVisible,
            isExpanded: self.isExpanded,
            isSelected: self.isSelected,
            opacity: self.opacity
        )
    }
}

func expandUpToProxyNodes(in nodes: [LayerNode]) {
    for node in nodes {
        if node.depth >= 4 {
            continue
        }
        if node.isIfcBuildingElementProxy {
            // This is a proxy - expand it but don't expand its children
            continue
        }
        node.isExpanded = true
        // This node is not a proxy, so recursively expand its children
        expandUpToProxyNodes(in: node.children)
    }
}

extension LayerNode {
    func debugDescription(indent: String = "") -> String {
        var result = "\(indent)📦 \(name) [isIfcBuildingElementProxy: \(isIfcBuildingElementProxy), expanded: \(isExpanded)]"
        for child in children {
            result += "\n" + child.debugDescription(indent: indent + "   ")
        }
        return result
    }
}

func printLayerTree(_ layers: [LayerNode]) {
    print("📂 Layer Tree:")
    for layer in layers {
        print(layer.debugDescription())
    }
}

class USDAParser {
    
    func parseUSDAFile(content: String) -> [IFCMetadata] {
        var metadata: [IFCMetadata] = []
        let lines = content.components(separatedBy: .newlines)
        
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            // Look for "def Xform" declarations - must be exact match
            if line.hasPrefix("def Xform \"") && line.contains("\"") {
                // Extract xform name more carefully
                let pattern = "def Xform \"([^\"]+)\""
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let range = Range(match.range(at: 1), in: line) {
                    let xformName = String(line[range])
                    let metadataItem = parseXformBlock(lines: lines, startIndex: i, xformName: xformName)
                    metadata.append(metadataItem)
                }
            }
            i += 1
        }
        
        return metadata
    }
    
    private func parseXformBlock(lines: [String], startIndex: Int, xformName: String) -> IFCMetadata {
        var name: String?
        var type: String?
        var guid: String?
        var label: String?
        
        var braceCount = 0
        var i = startIndex
        var foundOpeningBrace = false
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            // Count braces BEFORE processing attributes
            let openBraces = line.filter { $0 == "{" }.count
            let closeBraces = line.filter { $0 == "}" }.count
            
            // Update brace count
            braceCount += openBraces
            
            // Mark when we've found the opening brace of THIS Xform
            if openBraces > 0 && !foundOpeningBrace {
                foundOpeningBrace = true
            }
            
            // Only extract attributes after we've opened the brace and we're at depth 1
            // Don't extract from nested def Xform blocks
            if foundOpeningBrace && braceCount == 1 && !line.hasPrefix("def Xform") {
                if line.contains("custom string ifc:name") {
                    name = extractQuotedValue(from: line, after: "=")
                } else if line.contains("custom token  ifc:type") {
                    type = extractQuotedValue(from: line, after: "=")
                } else if line.contains("custom string ifc:guid") {
                    guid = extractQuotedValue(from: line, after: "=")
                } else if line.contains("custom string ifc:label") {
                    label = extractQuotedValue(from: line, after: "=")
                }
            }
            
            // Update brace count for closing braces
            braceCount -= closeBraces
            
            // Exit when we've closed the block
            if braceCount == 0 && foundOpeningBrace {
                break
            }
            
            i += 1
        }
        
        return IFCMetadata(
            xformName: xformName,
            name: name,
            type: type,
            guid: guid,
            label: label
        )
    }
    
    private func extractQuotedValue(from line: String, after marker: String) -> String? {
        guard let range = line.range(of: marker) else { return nil }
        let substring = String(line[range.upperBound...])
        
        // Find content between quotes
        let components = substring.components(separatedBy: "\"")
        if components.count >= 2 {
            return components[1]
        }
        
        return nil
    }
}

// 1️⃣ Parse text content (usda)
func parseIFCMetadata(from content: String) -> [IFCMetadata] {
    // Find every "def Xform "Name""
    let xformPattern = #"def Xform\s+"([^"]+)""#
    guard let xformRegex = try? NSRegularExpression(pattern: xformPattern) else { return [] }
    let nsrange = NSRange(content.startIndex..<content.endIndex, in: content)
    let matches = xformRegex.matches(in: content, range: nsrange)
    
    var results: [IFCMetadata] = []
    let lines = content.components(separatedBy: .newlines)
    
    for match in matches {
        guard let nameRange = Range(match.range(at: 1), in: content) else { continue }
        let xformName = String(content[nameRange])
        
        // Find the line index of this match
        let matchLocation = match.range.location
        let lineIndex = lines.firstIndex { line in
            guard let range = content.range(of: line) else { return false }
            return NSRange(range, in: content).location >= matchLocation
        } ?? 0
        
        // Search the next few lines for metadata
        let nearby = lines.dropFirst(lineIndex).prefix(15).joined(separator: "\n")
        
        func extract(_ key: String) -> String? {
            let pattern = #"ifc:\#(key)\s*=\s*"([^"]+)""#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            let nsrange = NSRange(nearby.startIndex..<nearby.endIndex, in: nearby)
            if let result = regex.firstMatch(in: nearby, range: nsrange),
               let range = Range(result.range(at: 2), in: nearby) {
                return String(nearby[range])
            }
            return nil
        }
        
        let name = extract("name")
        let type = extract("type")
        let guid = extract("guid")
        let label = extract("label")
        
        if name != nil || type != nil || guid != nil {
            results.append(
                IFCMetadata(
                    xformName: xformName,
                    name: name,
                    type: type,
                    guid: guid,
                    label: label
                )
            )
        }
    }
    
    return results
}

// 2️⃣ Extract .usda from .usdz and parse
func extractIFCMetadata(from usdzURL: URL) -> [IFCMetadata] {
    let fm = FileManager.default
    let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    var results: [IFCMetadata] = []
    
    do {
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try fm.unzipItem(at: usdzURL, to: tempDir)
        
        // Find all .usda files inside the unzipped folder
        let files = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        let usdaFiles = files.filter { $0.pathExtension.lowercased() == "usda" }
        
        guard let usdaFile = usdaFiles.first else {
            print("⚠️ No .usda file found in \(usdzURL.lastPathComponent)")
            return []
        }
        
        let content = try String(contentsOf: usdaFile, encoding: .utf8)
        let parser = USDAParser()
        results = parser.parseUSDAFile(content: content)
        
        for item in results {
            print("""
            Xform: \(item.xformName)
            Name: \(item.name ?? "-")
            Type: \(item.type ?? "-")
            GUID: \(item.guid ?? "-")
            Label: \(item.label ?? "-")
            -----
            """)
        }

    } catch {
        print("❌ Failed to extract IFC metadata: \(error)")
    }
    
    return results
}
