//
//  AnalyticsPremiumTests.swift
//  CarburanteTests
//
//  Produto da assinatura → valor de `premium_plan` / `plan` no PostHog
//  (`Analytics.premiumPlan`). Os filtros do painel dependem destes valores.
//

import XCTest
import StoreKit
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

    // MARK: - Motivo do purchase_failed (chaves congeladas: o painel filtra por elas)

    func testStoreKitErrorReasons() {
        XCTAssertEqual(Analytics.purchaseFailureReason(StoreKitError.networkError(URLError(.notConnectedToInternet))),
                       "network_error")
        XCTAssertEqual(Analytics.purchaseFailureReason(StoreKitError.notAvailableInStorefront),
                       "not_available_in_storefront")
        XCTAssertEqual(Analytics.purchaseFailureReason(StoreKitError.notEntitled), "not_entitled")
        XCTAssertEqual(Analytics.purchaseFailureReason(StoreKitError.unknown), "storekit_unknown")
    }

    func testPurchaseErrorReasons() {
        XCTAssertEqual(Analytics.purchaseFailureReason(Product.PurchaseError.productUnavailable),
                       "product_unavailable")
        XCTAssertEqual(Analytics.purchaseFailureReason(Product.PurchaseError.purchaseNotAllowed),
                       "purchase_not_allowed")
    }

    /// Erro de outra origem: domínio#código, nunca a mensagem (pode ter dado pessoal).
    func testOtherErrorUsesDomainAndCode() {
        let error = NSError(domain: "SKErrorDomain", code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "mensagem com dado pessoal"])
        XCTAssertEqual(Analytics.purchaseFailureReason(error), "SKErrorDomain#2")
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
