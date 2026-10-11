//
//  AnalyticsPremiumTests.swift
//  CarburanteTests
//
//  Produto da assinatura → valor de `premium_plan` / `plan` no PostHog
//  (`Analytics.premiumPlan`). Os filtros do painel dependem destes valores.
//

import XCTest
@testable import Carburante

final class AnalyticsPremiumTests: XCTestCase {

    func testNoSubscription() {
        XCTAssertEqual(Analytics.premiumPlan(for: nil), "none")
    }

    func testMonthly() {
        XCTAssertEqual(Analytics.premiumPlan(for: PremiumEntitlement.monthlyID), "monthly")
    }

    func testYearly() {
        XCTAssertEqual(Analytics.premiumPlan(for: PremiumEntitlement.yearlyID), "yearly")
    }

    func testUnknownProduct() {
        XCTAssertEqual(Analytics.premiumPlan(for: "carburante.premium.lifetime"), "unknown")
    }

    /// Gatilhos do `paywall_viewed`: chaves congeladas (o painel filtra por elas).
    func testPaywallTriggersAreFrozen() {
        XCTAssertEqual(PaywallReason.settings.rawValue, "settings")
        XCTAssertEqual(PaywallReason.secondBike.rawValue, "second_bike")
        XCTAssertEqual(PaywallReason.readOnlyBike.rawValue, "read_only_bike")
        XCTAssertEqual(PaywallReason.costs.rawValue, "costs")
        XCTAssertEqual(PaywallReason.icons.rawValue, "icons")
    }
}
