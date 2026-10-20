//
//  ChallengeImageStoreTests.swift
//  CarburanteTests
//
//  Fotos da turma no cache (D6): quando a cópia guardada ficou velha e a
//  decodificação reduzida das miniaturas.
//

import XCTest
@testable import Carburante

final class ChallengeImageStoreTests: XCTestCase {
    /// O dono trocou a foto (mesmo caminho no bucket) depois da cópia guardada.
    func testStale_onlyWhenTheBucketFileChangedAfterTheCopy() {
        let copy = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(ChallengeImageStore.isStale(savedAt: copy, remoteChangedAt: copy.addingTimeInterval(60)))
        XCTAssertFalse(ChallengeImageStore.isStale(savedAt: copy, remoteChangedAt: copy.addingTimeInterval(-60)))
        XCTAssertFalse(ChallengeImageStore.isStale(savedAt: copy, remoteChangedAt: copy))
        // Sem data de um dos lados: fica a cópia (não baixa a cada abertura).
        XCTAssertFalse(ChallengeImageStore.isStale(savedAt: nil, remoteChangedAt: copy))
        XCTAssertFalse(ChallengeImageStore.isStale(savedAt: copy, remoteChangedAt: nil))
    }

    /// Miniatura decodifica pequena (uma foto de 2048 px inteira ocupa ~12 MB).
    func testDecode_reducedToTheLongestSide() throws {
        let size = CGSize(width: 2048, height: 1536)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.7))

        let thumbnail = try XCTUnwrap(ChallengeImageStore.decode(data, maxPixel: 160))
        XCTAssertEqual(max(thumbnail.size.width * thumbnail.scale, thumbnail.size.height * thumbnail.scale), 160)
        let full = try XCTUnwrap(ChallengeImageStore.decode(data, maxPixel: nil))
        XCTAssertEqual(full.size.width * full.scale, 2048)
        XCTAssertNil(ChallengeImageStore.decode(Data("não é foto".utf8), maxPixel: 160))
    }
}
