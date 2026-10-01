//
//  FuelPriceTests.swift
//  CarburanteTests
//
//  Plausibilidade do preço por litro (`FuelPrice`).
//

import XCTest
@testable import Carburante

final class FuelPriceTests: XCTestCase {

    func testNormalPricesArePlausible() {
        XCTAssertFalse(FuelPrice.isImplausible(cost: 65.80, liters: 10.95))  // gasolina ~R$ 6
        XCTAssertFalse(FuelPrice.isImplausible(cost: 40, liters: 10))        // etanol R$ 4
        XCTAssertFalse(FuelPrice.isImplausible(cost: 9.5, liters: 2))        // premium R$ 4,75
    }

    /// Caso de campo: OCR leu R$ 28,49 como 2.849.
    func testCommaLostInCostIsImplausible() {
        XCTAssertTrue(FuelPrice.isImplausible(cost: 2_849, liters: 4.5))
    }

    /// Vírgula perdida nos litros: 10,95 → 1.095 L.
    func testCommaLostInLitersIsImplausible() {
        XCTAssertTrue(FuelPrice.isImplausible(cost: 65.80, liters: 1_095))
    }

    /// Erro de 10× também sai da faixa (R$ 6,50 → R$ 65 por litro).
    func testTenfoldErrorIsImplausible() {
        XCTAssertTrue(FuelPrice.isImplausible(cost: 650, liters: 10))
        XCTAssertTrue(FuelPrice.isImplausible(cost: 6.5, liters: 10))
    }

    func testRangeEdgesArePlausible() {
        XCTAssertFalse(FuelPrice.isImplausible(cost: 20, liters: 10))   // R$ 2,00
        XCTAssertFalse(FuelPrice.isImplausible(cost: 150, liters: 10))  // R$ 15,00
    }

    func testMissingValuesNeverWarn() {
        XCTAssertFalse(FuelPrice.isImplausible(cost: nil, liters: 10))
        XCTAssertFalse(FuelPrice.isImplausible(cost: 60, liters: nil))
        XCTAssertFalse(FuelPrice.isImplausible(cost: 60, liters: 0))
        XCTAssertFalse(FuelPrice.isImplausible(cost: 0, liters: 10))
        XCTAssertNil(FuelPrice.perLiter(cost: 60, liters: 0))
    }
}
