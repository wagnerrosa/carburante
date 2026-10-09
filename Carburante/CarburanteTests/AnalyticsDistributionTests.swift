//
//  AnalyticsDistributionTests.swift
//  CarburanteTests
//
//  Canal de instalação informado pela Apple → valor da super property
//  `distribution` que os filtros do PostHog usam (`Analytics.distribution`).
//

import XCTest
import StoreKit
@testable import Carburante

final class AnalyticsDistributionTests: XCTestCase {

    func testAppStoreIsProduction() {
        XCTAssertEqual(Analytics.distribution(for: .production), "appstore")
    }

    func testTestFlightIsSandbox() {
        XCTAssertEqual(Analytics.distribution(for: .sandbox), "testflight")
    }

    func testXcodeBuild() {
        XCTAssertEqual(Analytics.distribution(for: .xcode), "xcode")
    }
}
