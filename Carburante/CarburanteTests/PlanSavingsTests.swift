//
//  PlanSavingsTests.swift
//  CarburanteTests
//
//  Desconto do anual frente a 12× o mensal (cartão do anual na assinatura).
//

import XCTest
@testable import Carburante

final class PlanSavingsTests: XCTestCase {

    private func d(_ s: String) -> Decimal { Decimal(string: s)! }

    /// Preços de lançamento: 12 × 6,90 = 82,80; 69,90 é 15,58% menos → 15%.
    func testLaunchPrices() {
        let savings = PlanSavings(monthly: d("6.90"), yearly: d("69.90"))
        XCTAssertEqual(savings?.fullYearPrice, d("82.80"))
        XCTAssertEqual(savings?.percent, 15)
    }

    /// Arredonda para baixo: 32,74% vira 32%, nunca 33%.
    func testRoundsDown() {
        XCTAssertEqual(PlanSavings(monthly: d("9.90"), yearly: d("79.90"))?.percent, 32)
    }

    func testNoSavingsWhenYearlyIsNotCheaper() {
        XCTAssertNil(PlanSavings(monthly: d("6.90"), yearly: d("82.80")))
        XCTAssertNil(PlanSavings(monthly: d("6.90"), yearly: d("99.90")))
    }

    /// Menos de 1% não vira selo "Economize 0%".
    func testTinySavingsIsNil() {
        XCTAssertNil(PlanSavings(monthly: d("10.00"), yearly: d("119.90")))
    }

    func testZeroPricesAreNil() {
        XCTAssertNil(PlanSavings(monthly: 0, yearly: d("69.90")))
        XCTAssertNil(PlanSavings(monthly: d("6.90"), yearly: 0))
    }
}
