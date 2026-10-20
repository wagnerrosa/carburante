//
//  PhotoStorageTests.swift
//  CarburanteTests
//
//  A foto guardada (hodômetro, foto do desafio) é vista pela turma do
//  desafio: não pode levar o lugar onde foi tirada. O seletor de fotos do iOS
//  entrega a original com GPS; o app regrava a partir dos pixels.
//

import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import Carburante

final class PhotoStorageTests: XCTestCase {

    /// JPEG com GPS e data, como sai da câmera do iPhone.
    private func jpegWithLocation(size: CGSize) throws -> Data {
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.systemOrange.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        let data = NSMutableData()
        let dest = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        let properties: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 27.6, kCGImagePropertyGPSLatitudeRef: "S",
                kCGImagePropertyGPSLongitude: 48.5, kCGImagePropertyGPSLongitudeRef: "W",
            ],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:10:19 10:00:00"],
        ]
        CGImageDestinationAddImage(dest, try XCTUnwrap(image.cgImage), properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return data as Data
    }

    private func properties(_ data: Data) throws -> [CFString: Any] {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        return try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    }

    func testOriginalReallyCarriesLocation() throws {
        // Sanidade do teste: sem GPS na entrada, os outros não provariam nada.
        let original = try jpegWithLocation(size: CGSize(width: 300, height: 200))
        XCTAssertNotNil(try properties(original)[kCGImagePropertyGPSDictionary])
    }

    func testSavedPhotoDropsLocation() throws {
        for size in [CGSize(width: 300, height: 200), CGSize(width: 3000, height: 2000)] {
            let original = try jpegWithLocation(size: size)
            let image = try XCTUnwrap(UIImage(data: original))
            let saved = try XCTUnwrap(PhotoStorage.jpeg(image))
            let props = try properties(saved)
            XCTAssertNil(props[kCGImagePropertyGPSDictionary], "GPS vazou (\(size))")
            let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
            XCTAssertNil(exif?[kCGImagePropertyExifDateTimeOriginal], "data original vazou (\(size))")
        }
    }

    func testLargePhotoIsDownscaled() throws {
        let image = try XCTUnwrap(UIImage(data: try jpegWithLocation(size: CGSize(width: 4000, height: 3000))))
        let saved = try XCTUnwrap(UIImage(data: try XCTUnwrap(PhotoStorage.jpeg(image))))
        XCTAssertEqual(max(saved.size.width * saved.scale, saved.size.height * saved.scale),
                       PhotoStorage.maxDimension)
    }
}
