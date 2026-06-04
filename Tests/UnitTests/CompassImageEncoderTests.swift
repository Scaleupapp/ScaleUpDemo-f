import XCTest
import UIKit
@testable import ScaleUp

final class CompassImageEncoderTests: XCTestCase {
    private func solidImage(_ size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.gray.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
    func testDownscalesLargeImageAndEncodes() throws {
        let big = solidImage(CGSize(width: 3000, height: 2000))
        let result = try XCTUnwrap(CompassImageEncoder.downscaleAndEncode(big))
        XCTAssertEqual(result.mimeType, "image/jpeg")
        XCTAssertFalse(result.base64.isEmpty)
        let decoded = try XCTUnwrap(UIImage(data: result.data))
        XCTAssertLessThanOrEqual(max(decoded.size.width, decoded.size.height), 1568 + 1)
    }
    func testSmallImageNotUpscaled() throws {
        let small = solidImage(CGSize(width: 400, height: 300))
        let result = try XCTUnwrap(CompassImageEncoder.downscaleAndEncode(small))
        let decoded = try XCTUnwrap(UIImage(data: result.data))
        XCTAssertEqual(max(decoded.size.width, decoded.size.height), 400, accuracy: 1)
    }
}
