//
//  UIImage++.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 18/04/2022.
//

import Foundation
import ImageIO
import UIKit

extension UIImage {
    /// Decodes the image at `url` downscaled so its longest edge is `maxPixelSize`.
    /// A project thumbnail file is a full resolution photo, decoding it as-is costs
    /// tens of MB per project, which does not fit a list of cached cell thumbnails.
    /// ImageIO downsamples while decoding so the full size bitmap is never created.
    static func downsampled(from url: URL, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
        return UIImage(cgImage: cgImage)
    }

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
