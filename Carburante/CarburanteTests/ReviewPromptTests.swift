//
//  ReviewPromptTests.swift
//  CarburanteTests
//
//  Quando pedir avaliação na App Store (`ReviewPrompt`).
//

import XCTest
@testable import Carburante

final class ReviewPromptTests: XCTestCase {

    func testAsksWhenSegmentClosesInNewVersion() {
        XCTAssertTrue(ReviewPrompt.shouldAsk(closedConsumptionSegment: true, isHistorical: false,
                                             askedVersion: "", currentVersion: "1.0"))
        XCTAssertTrue(ReviewPrompt.shouldAsk(closedConsumptionSegment: true, isHistorical: false,
                                             askedVersion: "1.0", currentVersion: "1.1"))
    }

    func testNeverAsksTwiceInSameVersion() {
        XCTAssertFalse(ReviewPrompt.shouldAsk(closedConsumptionSegment: true, isHistorical: false,
                                              askedVersion: "1.0", currentVersion: "1.0"))
    }

    func testNoConsumptionReadingNoAsk() {
        // Abastecimento parcial, 1º cheio (âncora) ou lacuna: sem km/l novo.
        XCTAssertFalse(ReviewPrompt.shouldAsk(closedConsumptionSegment: false, isHistorical: false,
                                              askedVersion: "", currentVersion: "1.0"))
    }

    func testHistoricalEntryNoAsk() {
        XCTAssertFalse(ReviewPrompt.shouldAsk(closedConsumptionSegment: true, isHistorical: true,
                                              askedVersion: "", currentVersion: "1.0"))
    }
}
