//
//  PremiumEntitlementTests.swift
//  CarburanteTests
//
//  Regra pura do direito Premium (`PremiumEntitlement.activeProductID`).
//

import XCTest
@testable import Carburante

final class PremiumEntitlementTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var tomorrow: Date { now.addingTimeInterval(86_400) }
    private var yesterday: Date { now.addingTimeInterval(-86_400) }

    private func entry(_ id: String, expires: Date?, revoked: Date? = nil) -> PremiumEntitlement.Entry {
        PremiumEntitlement.Entry(productID: id, expirationDate: expires, revocationDate: revoked)
    }

    func testNoTransactionsIsFree() {
        XCTAssertNil(PremiumEntitlement.activeProductID(in: [], now: now))
    }

    func testValidMonthlyIsPremium() {
        let entries = [entry(PremiumEntitlement.monthlyID, expires: tomorrow)]
        XCTAssertEqual(PremiumEntitlement.activeProductID(in: entries, now: now), PremiumEntitlement.monthlyID)
    }

    func testExpiredIsFree() {
        let entries = [entry(PremiumEntitlement.yearlyID, expires: yesterday)]
        XCTAssertNil(PremiumEntitlement.activeProductID(in: entries, now: now))
    }

    func testExpiringExactlyNowIsFree() {
        let entries = [entry(PremiumEntitlement.monthlyID, expires: now)]
        XCTAssertNil(PremiumEntitlement.activeProductID(in: entries, now: now))
    }

    func testRefundedIsFree() {
        let entries = [entry(PremiumEntitlement.yearlyID, expires: tomorrow, revoked: yesterday)]
        XCTAssertNil(PremiumEntitlement.activeProductID(in: entries, now: now))
    }

    func testUnknownProductIsIgnored() {
        let entries = [entry("carburante.lifetime.test", expires: nil)]
        XCTAssertNil(PremiumEntitlement.activeProductID(in: entries, now: now))
    }

    func testLatestExpirationWins() {
        // Trocou do mensal para o anual no meio do mês: as duas aparecem por um tempo.
        let entries = [
            entry(PremiumEntitlement.monthlyID, expires: tomorrow),
            entry(PremiumEntitlement.yearlyID, expires: now.addingTimeInterval(365 * 86_400)),
        ]
        XCTAssertEqual(PremiumEntitlement.activeProductID(in: entries, now: now), PremiumEntitlement.yearlyID)
    }

    func testValidSurvivesAlongsideRevoked() {
        let entries = [
            entry(PremiumEntitlement.yearlyID, expires: tomorrow, revoked: yesterday),
            entry(PremiumEntitlement.monthlyID, expires: tomorrow),
        ]
        XCTAssertEqual(PremiumEntitlement.activeProductID(in: entries, now: now), PremiumEntitlement.monthlyID)
    }

    func testPlanNames() {
        XCTAssertEqual(PremiumEntitlement.planName(for: PremiumEntitlement.monthlyID), "Mensal")
        XCTAssertEqual(PremiumEntitlement.planName(for: PremiumEntitlement.yearlyID), "Anual")
        XCTAssertNil(PremiumEntitlement.planName(for: "outro"))
    }

    /// IDs batem com o App Store Connect — Product ID é imutável lá.
    func testProductIDsMatchAppStoreConnect() {
        XCTAssertEqual(PremiumEntitlement.productIDs,
                       ["carburante.premium.monthly", "carburante.premium.yearly"])
    }
}
