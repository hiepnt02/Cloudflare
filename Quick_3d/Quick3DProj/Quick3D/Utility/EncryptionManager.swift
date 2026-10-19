//
// EncryptionManager.swift
// Quick3D
//
// Created by HungNT on 20/12/24.
//

import Foundation
import CryptoKit
import Keys

struct EncryptionManager {
        
    enum SigningError: Error {
        case keyNotValid
        case signedDataNotValid
    }
    
    static public func signString(_ string: String) -> String {
        do {
            guard let privateKey = Data(base64Encoded: Quick3DKeys().pix4DKey), privateKey.count == 32
            else {
              throw SigningError.keyNotValid
            }
            guard let data = string.data(using: .utf8)
            else {
              throw SigningError.signedDataNotValid
            }
            let signingPrivateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKey)
            let signature = try signingPrivateKey.signature(for: data)
            var signatureBase64 = signature.base64EncodedString()
            while signatureBase64.hasSuffix("=") {
                signatureBase64 = String(signatureBase64.dropLast())
            }
            return signatureBase64
        } catch {
            print(error)
            return ""
        }
    }
}
