//
//  GarageLimitTests.swift
//  CarburanteTests
//
//  Regra pura do limite da garagem no plano grátis (`GarageLimit.access`).
//

import XCTest
@testable import Carburante

final class GarageLimitTests: XCTestCase {

    private let launch = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 86_400

    /// Dias depois do corte (negativo = antes).
    private func at(_ days: Double) -> Date { launch.addingTimeInterval(days * day) }

    private func bike(_ status: MotorcycleStatus = .active, created: Double,
                      used: Double? = nil) -> GarageLimit.Bike {
        GarageLimit.Bike(id: UUID(), status: status, createdAt: at(created),
                         lastActivity: at(used ?? created))
    }

    private func access(_ bikes: [GarageLimit.Bike], premium: Bool = false,
                        now: Double = 100) -> GarageLimit.Access {
        GarageLimit.access(for: bikes, isPremium: premium, launch: launch, now: at(now))
    }

    // MARK: - Cadastrar

    func testEmptyGarageCanAdd() {
        XCTAssertTrue(access([]).canAddMotorcycle)
    }

    func testOneActiveBikeBlocksAdding() {
        let a = bike(created: 1)
        let result = access([a])
        XCTAssertFalse(result.canAddMotorcycle)
        XCTAssertFalse(result.isReadOnly(a.id))
    }

    func testLegacyActiveBikeAlsoTakesTheSlot() {
        XCTAssertFalse(access([bike(created: -10)]).canAddMotorcycle)
    }

    func testBikeForSaleLetsYouAddTheNext() {
        XCTAssertTrue(access([bike(.forSale, created: 1)]).canAddMotorcycle)
    }

    func testOnlyOneTradeAtATime() {
        let bikes = [bike(.forSale, created: 1), bike(.forSale, created: 2)]
        XCTAssertFalse(access(bikes).canAddMotorcycle)
    }

    func testSoldBikesDoNotCount() {
        let bikes = [bike(.sold, created: 1), bike(.sold, created: 2)]
        XCTAssertTrue(access(bikes).canAddMotorcycle)
        XCTAssertTrue(access(bikes).readOnlyIDs.isEmpty)
    }

    func testPremiumIsUnlimited() {
        let bikes = [bike(created: 1), bike(created: 2), bike(created: 3)]
        XCTAssertEqual(access(bikes, premium: true), .unlimited)
    }

    // MARK: - Quem já tinha várias motos

    func testLegacyBikesNeverBecomeReadOnly() {
        let bikes = [bike(created: -30), bike(created: -20), bike(created: -10)]
        let result = access(bikes)
        XCTAssertTrue(result.readOnlyIDs.isEmpty)
        XCTAssertFalse(result.canAddMotorcycle)
    }

    func testBikeCreatedExactlyAtLaunchCounts() {
        let old = bike(created: -1)
        let new = bike(created: 0)
        XCTAssertEqual(access([old, new]).readOnlyIDs, [new.id])
    }

    func testLegacyActiveBikeKeepsTheSlot() {
        // Desistiu da venda da antiga: a nova fica só para consulta.
        let old = bike(created: -10)
        let new = bike(created: 5, used: 90)
        XCTAssertEqual(access([old, new]).readOnlyIDs, [new.id])
    }

    // MARK: - Troca de moto

    func testTradeKeepsBikeForSaleEditableFor30Days() {
        let old = bike(.forSale, created: 1)
        let new = bike(created: 50)
        let result = access([old, new], now: 79)
        XCTAssertTrue(result.readOnlyIDs.isEmpty)
        XCTAssertFalse(result.canAddMotorcycle)
    }

    func testTradeGraceEnds() {
        let old = bike(.forSale, created: 1)
        let new = bike(created: 50)
        XCTAssertEqual(access([old, new], now: 81).readOnlyIDs, [old.id])
    }

    func testNoGraceWhenTheBikeForSaleIsTheNewerOne() {
        let first = bike(created: 1)
        let second = bike(.forSale, created: 50)
        XCTAssertEqual(access([first, second], now: 55).readOnlyIDs, [second.id])
    }

    func testLegacyBikeForSaleStaysEditable() {
        let old = bike(.forSale, created: -10)
        let new = bike(created: 50)
        XCTAssertTrue(access([old, new], now: 200).readOnlyIDs.isEmpty)
    }

    func testBikeForSaleAloneKeepsTheSlot() {
        let old = bike(.forSale, created: 1)
        XCTAssertTrue(access([old], now: 500).readOnlyIDs.isEmpty)
    }

    // MARK: - Duas disputando a vaga (assinatura vencida, desistiu da venda)

    func testMostRecentlyUsedKeepsTheSlot() {
        let a = bike(created: 1, used: 90)
        let b = bike(created: 10, used: 40)
        XCTAssertEqual(access([a, b]).readOnlyIDs, [b.id])
    }

    func testActiveBeatsForSaleForTheSlot() {
        let selling = bike(.forSale, created: 20, used: 99)
        let riding = bike(created: 10, used: 30)
        XCTAssertEqual(access([selling, riding]).readOnlyIDs, [selling.id])
    }

    func testThreeBikesAfterSubscriptionEnds() {
        let a = bike(created: 1, used: 60)
        let b = bike(created: 2, used: 70)
        let c = bike(created: 3, used: 65)
        XCTAssertEqual(access([a, b, c]).readOnlyIDs, [a.id, c.id])
    }
}
