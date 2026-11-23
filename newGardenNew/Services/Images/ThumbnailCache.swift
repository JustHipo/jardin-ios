import Foundation
import ImageIO
import UIKit

/// Caches decoded thumbnails so SwiftUI's frequent `body` re-evaluation doesn't re-decode a
/// full-size photo on every scroll frame. Fixes M4 from the audit: `PlantImageView` called
/// `CGImageSourceCreateThumbnailAtIndex` directly inside `body` with no cache at all.
///
/// ImageIO thumbnailing (not `UIImage(data:)`) stays, because it decodes only the pixels
/// needed for the target size instead of the whole image — that part of the old code was
/// already correct.
actor ThumbnailCache {
    static let shared = ThumbnailCache()

    private var cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200
    }

    func thumbnail(for data: Data, id: String, maxDimension: CGFloat) -> UIImage? {
        let key = "\(id)-\(Int(maxDimension))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension * UIScreen.main.scale,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: key)
        return image
    }
}
