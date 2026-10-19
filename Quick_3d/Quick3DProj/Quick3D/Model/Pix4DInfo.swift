//
//  Pix4DInfo.swift
//  Quick3D
//
//  Created by HungNT on 20/5/26.
//

import Foundation
import UIKit
import DeviceKit

struct Pix4DInfo {
    
    // MARK: - Models
    
    struct RTKOffset: Codable {
        let value: [Float]
        let device: String
    }

    struct ExportSettings: Codable {
        let exportAfterSave: Bool
    }

    struct Offsets: Codable {
        let rtkOffsets: [RTKOffset]?
        let caseName: String
    }

    struct Overlap: Codable {
        let percentage: Int
    }

    struct Triggering: Codable {
        let overlap: Overlap
    }

    struct Settings: Codable {
        let export: ExportSettings
        let offsets: Offsets?
        let triggering: Triggering
    }
    
    struct AppConfiguration: Codable {
        let id: String
        let iat: Int
        let exp: Int
        let settings: Settings
        let name: String
        var features: Features? = nil
    }
    
    struct Features: Codable {
        let cloud: Cloud
    }

    struct Cloud: Codable {
        let cloudCrs: CloudCrs
        let cloudUrl: String
    }

    struct CloudCrs: Codable {
        let wkt: String
    }
    
    // MARK: - Public Functions
    
    // Open Pix4D Capture without Features condition (Runs on MainActor due to direct UI interaction)
    @MainActor
    func openPix4DCapture() {
        let settings = makeDeviceSettings()
        let appConfiguration = makeAppConfiguration(settings: settings, features: nil)
        
        openPix4DApp(with: appConfiguration)
    }
    
    // Open Pix4D with asynchronous AR data retrieved from the API.
    func openPix4DViewAR(projectId: String, productData: ProductData) async {
        do {
            let settings = makeDeviceSettings()
            
            // Retrieve and examine Feature data from the API.
            guard let featuresData = try await productData.getFeaturesData(projectId: projectId),
                  let cloud = featuresData["features"] as? [String: Any],
                  let cloudData = cloud["cloud"] as? [String: Any] else {
                print("Error: Failed to parse features data structures")
                return
            }
            
            // Securely process CRS WKT information.
            var wkt = ""
            if let cloudCrs = cloudData["cloudCrs"] as? [String: Any],
               let rawWkt = cloudCrs["wkt"] as? String {
                wkt = rawWkt.replacingOccurrences(of: "\\\"", with: "\"")
                            .replacingOccurrences(of: "\\", with: "")
            }
            
            let cloudUrl = cloudData["cloudUrl"] as? String ?? ""
            let features = Features(cloud: Cloud(cloudCrs: CloudCrs(wkt: wkt), cloudUrl: cloudUrl))
            
            // Create overall configuration data
            let appConfiguration = makeAppConfiguration(settings: settings, features: features)
            print("Job Site: \(String(describing: appConfiguration))")
            
            // Open the URL on the Main Thread.
            await MainActor.run {
                openPix4DApp(with: appConfiguration)
            }
        } catch {
            print("Error fetching job site data: \(error)")
        }
    }
    
    // MARK: - Private Helper Functions
    
    // Create Settings configurations based on the current device type independently.
    private func makeDeviceSettings() -> Settings {
        let device = Device.current
        let deviceName = Device.identifier
        var offsetValue: [Float] = []
        var rtkOffsets: [RTKOffset]? = nil
        
        switch device {
        case .iPadPro11Inch2, .iPadPro11Inch3, .iPadPro11Inch4:
            offsetValue = [-0.067, -0.019, 0.021]
        case .iPadPro12Inch5, .iPadPro12Inch6:
            offsetValue = [-0.082, -0.019, 0.021]
        default:
            break
        }
        
        if !offsetValue.isEmpty {
            rtkOffsets = [RTKOffset(value: offsetValue, device: deviceName)]
        }
        
        return Settings(
            export: ExportSettings(exportAfterSave: true),
            offsets: rtkOffsets != nil ? Offsets(rtkOffsets: rtkOffsets, caseName: "Casetify SPC+") : nil,
            triggering: Triggering(overlap: Overlap(percentage: 90))
        )
    }
    
    // Packaging the standard AppConfiguration data model
    private func makeAppConfiguration(settings: Settings, features: Features?) -> AppConfiguration {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "ltd.landlog.scquick3d"
        let iat = Int(Date.now.timeIntervalSince1970)
        let exp = iat + 12 * 3600
        
        return AppConfiguration(
            id: bundleIdentifier,
            iat: iat,
            exp: exp,
            settings: settings,
            name: "Smart Construction Quick3D",
            features: features
        )
    }
    
    // Handling encoding, encryption, and enabling Deep Link opening in the Pix4D application.
    @MainActor
    private func openPix4DApp(with configuration: AppConfiguration) {
        guard let jsonData = try? JSONEncoder().encode(configuration),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("Error: Failed to encode configuration to JSON string")
            return
        }
        
        // Reformat JSON string to avoid escape characters and forward slashes.
        let jsonStrFormatted = jsonString.replacingOccurrences(of: "\\/", with: "/")
        
        // Base64 encoding and digital signing of configuration data strings.
        guard let base64Data = jsonStrFormatted.data(using: .utf8) else { return }
        let base64String = base64Data.base64EncodedString()
        let signatureString = EncryptionManager.signString(base64String)
        
        // Initialize Deep Link URL
        let urlString = "pix4dcatch.export://?appConfiguration=\(base64String).\(signatureString)"
        guard let url = URL(string: urlString) else {
            print("Error: Invalid URL scheme structure")
            return
        }
        
        // Implement external application navigation interactions.
        UIApplication.shared.open(url, options: [.universalLinksOnly: false]) { completed in
            //print("App open triggered: \(completed)")
        }
    }
}
