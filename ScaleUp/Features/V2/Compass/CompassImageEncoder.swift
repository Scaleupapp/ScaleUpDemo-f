import UIKit

enum CompassImageEncoder {
    /// Downscale (longest side ≤ maxDimension) + JPEG-encode. Returns the JPEG data, its base64, and mime type.
    static func downscaleAndEncode(_ image: UIImage, maxDimension: CGFloat = 1568, quality: CGFloat = 0.7) -> (data: Data, base64: String, mimeType: String)? {
        let scaled = downscale(image, maxDimension: maxDimension)
        guard let data = scaled.jpegData(compressionQuality: quality) else { return nil }
        return (data, data.base64EncodedString(), "image/jpeg")
    }

    static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else {
            // Return a scale=1 copy so .size equals pixel dimensions for consistent API.
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
        }
        let ratio = maxDimension / longest
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        // Render at scale=1 so the resulting UIImage's .size equals the target point dimensions,
        // which is what the JPEG pixel dimensions will be (no Retina inflation).
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
