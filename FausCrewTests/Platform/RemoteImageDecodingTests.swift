import XCTest
import UIKit
@testable import FausCrew

@MainActor
final class RemoteImageDecodingTests: XCTestCase {
    func testDownloadSizeAllowsUnknownLengthAndFiveMegabytes() {
        XCTAssertTrue(RemoteImageDecoding.isAllowedByteCount(-1))
        XCTAssertTrue(RemoteImageDecoding.isAllowedByteCount(0))
        XCTAssertTrue(RemoteImageDecoding.isAllowedByteCount(5 * 1024 * 1024))
        XCTAssertFalse(RemoteImageDecoding.isAllowedByteCount(5 * 1024 * 1024 + 1))
        XCTAssertFalse(RemoteImageDecoding.isAllowedByteCount(.max))
    }

    func testNonSquareThumbnailsReachShortEdgeTargetAndKeepAspectRatio() throws {
        for size in [CGSize(width: 1600, height: 900), CGSize(width: 900, height: 1600)] {
            let data = try imageData(size: size)
            let thumbnail = try XCTUnwrap(RemoteImageDecoding.thumbnail(from: data)?.cgImage)

            XCTAssertGreaterThanOrEqual(
                min(thumbnail.width, thumbnail.height),
                RemoteImageDecoding.minimumThumbnailShortEdgePixels
            )
            XCTAssertLessThan(CGFloat(max(thumbnail.width, thumbnail.height)), max(size.width, size.height))
            XCTAssertEqual(
                CGFloat(thumbnail.width) / CGFloat(thumbnail.height),
                size.width / size.height,
                accuracy: 0.01
            )
        }
    }

    func testSmallSourcesAreNotUpscaled() throws {
        for size in [CGSize(width: 100, height: 60), CGSize(width: 60, height: 100)] {
            let data = try imageData(size: size)
            let thumbnail = try XCTUnwrap(RemoteImageDecoding.thumbnail(from: data)?.cgImage)

            XCTAssertEqual(thumbnail.width, Int(size.width))
            XCTAssertEqual(thumbnail.height, Int(size.height))
        }
    }

    func testExtremeAspectRatiosStayWithinLongEdgeCeiling() throws {
        for size in [CGSize(width: 4000, height: 100), CGSize(width: 100, height: 4000)] {
            let data = try imageData(size: size)
            let thumbnail = try XCTUnwrap(RemoteImageDecoding.thumbnail(from: data)?.cgImage)

            XCTAssertEqual(max(thumbnail.width, thumbnail.height), 1024)
            XCTAssertGreaterThan(min(thumbnail.width, thumbnail.height), 0)
        }
    }

    func testInvalidImageDataDoesNotProduceAThumbnail() {
        XCTAssertNil(RemoteImageDecoding.thumbnail(from: Data()))
        XCTAssertNil(RemoteImageDecoding.thumbnail(from: Data("not an image".utf8)))
    }

    private func imageData(size: CGSize) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
    }
}
