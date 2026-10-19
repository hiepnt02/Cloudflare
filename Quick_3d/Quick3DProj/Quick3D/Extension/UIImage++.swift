//
//  UIImage++.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 18/04/2022.
//

import Foundation
import UIKit

extension UIImage {
    convenience init?(fromLocalUrl url: URL) {
        do {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            self.init(data: data)
        } catch {
            return nil
        }
    }

    func scaled(to expectedSize: CGSize) -> UIImage? {

        let size = self.size

        let widthRatio  = expectedSize.width  / size.width
        let heightRatio = expectedSize.height / size.height

        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }

        return image(scaledTo: newSize)
    }
    
    func image(scaledTo size: CGSize) -> UIImage? {
        // Block cases where size = {0, 0} or negative values ​​to prevent crashes.
        guard size.width > 0 && size.height > 0 else {
            return nil
        }
        
        // Use UIGraphicsImageRenderer as recommended by Apple.
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 0     // scale = 0 will automatically use the scale of the current device's screen.
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        
        // Create and return a new image.
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
