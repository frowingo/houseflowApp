import UIKit
import FausCrewCore

/// Re-encodes a camera photo as JPEG under the backend's 3 MB limit with UIKit
/// only. Returns nil when no quality fits, so Core's `ChoreReviewPhotoUpload`
/// validation is never reached with an oversized file.
nonisolated enum ChoreReviewPhotoEncoder {
    static let maxPixelDimension: CGFloat = 2048
    private static let qualities: [CGFloat] = [0.8, 0.65, 0.5, 0.35]

    static func prepared(from image: UIImage) -> Data? {
        let scaled = downscaled(image)
        for quality in qualities {
            if let jpeg = scaled.jpegData(compressionQuality: quality),
               jpeg.count <= ChoreReviewPhotoRules.maxByteCount {
                return jpeg
            }
        }
        return nil
    }

    private static func downscaled(_ image: UIImage) -> UIImage {
        let longestSide = max(image.size.width, image.size.height)
        let ratio = min(1, maxPixelDimension / max(longestSide, 1))
        let targetSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
