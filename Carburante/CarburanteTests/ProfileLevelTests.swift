//
//  ProfileLevelTests.swift
//  CarburanteTests
//
//  Motor puro do nível do perfil (`ProfileLevel.from`). Curva íngreme de pontos.
//

import XCTest
@testable import Carburante

final class ProfileLevelTests: XCTestCase {

    private let t = ProfileLevel.thresholds  // [0, 5, 12, 22, 40, 65, 100, 150, 220, 320]

    func testZeroPointsIsLevelOneNoProgress() {
        let lv = ProfileLevel.from(points: 0)
        XCTAssertEqual(lv.level, 1)
        XCTAssertEqual(lv.pointsIntoLevel, 0)
        XCTAssertEqual(lv.pointsForNext, t[1])   // pontos p/ o nível 2 (piso do setup completo)
        XCTAssertEqual(lv.progress, 0)
        XCTAssertFalse(lv.isMax)
    }

    func testNegativePointsClampToZero() {
        XCTAssertEqual(ProfileLevel.from(points: -50), ProfileLevel.from(points: 0))
    }

    func testExactThresholdStartsNextLevelAtZeroOffset() {
        // 3 pontos = piso do nível 2 → entra no 2 com offset 0.
        let lv = ProfileLevel.from(points: t[1])
        XCTAssertEqual(lv.level, 2)
        XCTAssertEqual(lv.pointsIntoLevel, 0)
        XCTAssertEqual(lv.progress, 0)
    }

    func testMidLevelOffsetAndRemaining() {
        // Ponto médio da faixa do nível 3 [t[2], t[3]) — relativo à curva.
        let floor = t[2]
        let ceil = t[3]
        let span = ceil - floor
        let offset = span / 2
        let lv = ProfileLevel.from(points: floor + offset)
        XCTAssertEqual(lv.level, 3)
        XCTAssertEqual(lv.pointsIntoLevel, offset)
        XCTAssertEqual(lv.pointsForNext, span - offset)
        XCTAssertEqual(lv.spanOfLevel, span)
        XCTAssertEqual(lv.progress, Double(offset) / Double(span), accuracy: 0.0001)
    }

    func testMaxLevelHasNoNext() {
        // No piso do último limiar (320) → nível máximo, barra cheia, nada a mais.
        let lv = ProfileLevel.from(points: t.last!)
        XCTAssertEqual(lv.level, t.count)
        XCTAssertEqual(lv.pointsForNext, 0)
        XCTAssertEqual(lv.spanOfLevel, 0)
        XCTAssertTrue(lv.isMax)
        XCTAssertEqual(lv.progress, 1)
    }

    func testAboveMaxStaysMax() {
        let lv = ProfileLevel.from(points: 9_999)
        XCTAssertEqual(lv.level, t.count)
        XCTAssertTrue(lv.isMax)
        XCTAssertEqual(lv.progress, 1)
    }

    func testRegisteringFirstBikeStaysLevelOne() {
        // Cadastrar a 1ª moto destrava no MÁXIMO marca (1) + categoria nível I (1)
        // + clube de cilindrada (2) = 4 pts. Setup não é progresso: deve ficar no
        // nível 1. Nível 2 exige USO (abastecer/rodar). Regra que o usuário pediu.
        XCTAssertEqual(ProfileLevel.from(points: 4).level, 1)
    }

    func testCurveIsStrictlyIncreasing() {
        for i in 1..<t.count {
            XCTAssertGreaterThan(t[i], t[i - 1], "limiares devem crescer")
        }
    }

    func testLevelMonotonicInPoints() {
        // Mais pontos → nunca cai de nível.
        var lastLevel = 0
        for p in stride(from: 0, through: 400, by: 1) {
            let lv = ProfileLevel.from(points: p).level
            XCTAssertGreaterThanOrEqual(lv, lastLevel)
            lastLevel = lv
        }
    }
}
