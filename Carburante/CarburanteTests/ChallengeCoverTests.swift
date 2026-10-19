//
//  ChallengeCoverTests.swift
//  CarburanteTests
//
//  Capa do desafio: recorte 3:2 no centro, tamanho final e o caminho no
//  bucket que o `set_challenge_cover` aceita.
//

import XCTest
import UIKit
@testable import Carburante

final class ChallengeCoverTests: XCTestCase {
    func testCrop_landscapeKeepsTheMiddleWidth() {
        // 4:3 deitada → 3:2 corta as pontas de cima e de baixo.
        let crop = ChallengeCover.cropRect(for: CGSize(width: 4032, height: 3024))
        XCTAssertEqual(crop, CGRect(x: 0, y: 168, width: 4032, height: 2688))
        // Panorâmica → corta os lados.
        let wide = ChallengeCover.cropRect(for: CGSize(width: 3000, height: 1000))
        XCTAssertEqual(wide, CGRect(x: 750, y: 0, width: 1500, height: 1000))
    }

    func testCrop_portraitTakesACenteredStrip() {
        let crop = ChallengeCover.cropRect(for: CGSize(width: 3024, height: 4032))
        XCTAssertEqual(crop, CGRect(x: 0, y: 1008, width: 3024, height: 2016))
        XCTAssertEqual(ChallengeCover.cropRect(for: .zero), .zero)
    }

    func testOutputSize_shrinksButNeverGrows() {
        XCTAssertEqual(ChallengeCover.outputSize(for: CGSize(width: 4032, height: 2688)),
                       CGSize(width: 1500, height: 1000))
        XCTAssertEqual(ChallengeCover.outputSize(for: CGSize(width: 900, height: 600)),
                       CGSize(width: 900, height: 600))
    }

    func testJPEG_comesOutCroppedAndReduced() throws {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 4000), format: format).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3000, height: 4000))
        }
        let jpeg = try XCTUnwrap(ChallengeCover.jpeg(from: photo))
        let cover = try XCTUnwrap(UIImage(data: jpeg))
        XCTAssertEqual(cover.size, CGSize(width: 1500, height: 1000))
    }

    /// Mesmo padrão do servidor: `^<challenge_id>/[A-Za-z0-9_-]+\.jpg$`, com
    /// o id como o Postgres escreve (`uuid::text`, minúsculo).
    func testPath_matchesTheServerRule() throws {
        let id = UUID(uuidString: "180AD24F-AD5B-48B4-9904-D9CA67AB6ADA")!
        let path = ChallengeCover.path(challengeID: id, version: "ab12cd34")
        XCTAssertEqual(path, "180ad24f-ad5b-48b4-9904-d9ca67ab6ada/cover-ab12cd34.jpg")
        let rule = try NSRegularExpression(pattern: "^180ad24f-ad5b-48b4-9904-d9ca67ab6ada/[A-Za-z0-9_-]+\\.jpg$")
        let fresh = ChallengeCover.path(challengeID: id)
        XCTAssertNotNil(rule.firstMatch(in: fresh, range: NSRange(fresh.startIndex..., in: fresh)))
        XCTAssertNotEqual(fresh, ChallengeCover.path(challengeID: id), "cada capa nova ganha nome novo")
    }

    func testIsRemote_onlyStoragePaths() {
        XCTAssertTrue(ChallengeCover.isRemote("180ad24f-ad5b-48b4-9904-d9ca67ab6ada/cover-ab12cd34.jpg"))
        XCTAssertFalse(ChallengeCover.isRemote("IMG_0005"))
        XCTAssertFalse(ChallengeCover.isRemote(nil))
    }
}
