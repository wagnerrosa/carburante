//
//  TextRecognizerTests.swift
//  CarburanteTests
//
//  Orientação da foto chega ao Vision (PLAN/ocr-hodometro.md §6): foto em
//  retrato do iPhone tem os pixels deitados + `imageOrientation = .right`.
//

import XCTest
import UIKit
import ImageIO
@testable import Carburante

final class TextRecognizerTests: XCTestCase {

    func testOrientationMapping() {
        XCTAssertEqual(CGImagePropertyOrientation(UIImage.Orientation.up), .up)
        XCTAssertEqual(CGImagePropertyOrientation(UIImage.Orientation.right), .right)
        XCTAssertEqual(CGImagePropertyOrientation(UIImage.Orientation.left), .left)
        XCTAssertEqual(CGImagePropertyOrientation(UIImage.Orientation.down), .down)
        XCTAssertEqual(CGImagePropertyOrientation(UIImage.Orientation.leftMirrored), .leftMirrored)
    }

    /// Mesmo arranjo de uma foto em retrato da câmera: pixels girados 90° e a
    /// rotação só no metadado. O número precisa ser lido em pé.
    func testReadsPortraitPhotoUpright() async throws {
        let upright = Self.render("48327")
        // Pixels = imagem em pé girada 90° no sentido horário (.left exibe assim).
        let sideways = Self.redraw(UIImage(cgImage: upright.cgImage!, scale: 1, orientation: .left))
        // `.right` desfaz: exibida, volta a ficar em pé.
        let photo = UIImage(cgImage: sideways.cgImage!, scale: 1, orientation: .right)
        XCTAssertEqual(photo.size, upright.size)

        let result = try await TextRecognizer.recognize(in: photo)
        XCTAssertTrue(result.lines.contains { $0.replacingOccurrences(of: " ", with: "").contains("48327") },
                      "lido: \(result.lines)")
    }

    private static func render(_ text: String) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: 600, height: 200)
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            (text as NSString).draw(at: CGPoint(x: 60, y: 50),
                                    withAttributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: 90, weight: .bold),
                                                     .foregroundColor: UIColor.black])
        }
    }

    private static func redraw(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(at: .zero)
        }
    }
}
