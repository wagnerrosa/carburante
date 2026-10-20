//
//  AnalyticsChallengeTests.swift
//  CarburanteTests
//
//  Medição dos Desafios (D9): chaves congeladas que vão para o PostHog —
//  prazo, fase e faixas. Mudar uma delas quebra os painéis.
//

import XCTest
@testable import Carburante

final class AnalyticsChallengeTests: XCTestCase {
    private let brt = TimeZone(identifier: "America/Sao_Paulo")!

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = brt
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func testDurationKey_fromThePeriodTheFormMade() {
        let start = day(2026, 10, 20)
        let week = ChallengeDuration.week.period(from: start, until: start, timeZone: brt)
        let month = ChallengeDuration.month.period(from: start, until: start, timeZone: brt)
        let until = ChallengeDuration.until.period(from: start, until: day(2026, 11, 2), timeZone: brt)
        XCTAssertEqual(ChallengeDuration.analyticsKey(for: week), "week")
        XCTAssertEqual(ChallengeDuration.analyticsKey(for: month), "month")
        XCTAssertEqual(ChallengeDuration.analyticsKey(for: until), "until")
        XCTAssertEqual(week.dayCount, 7)
    }

    func testPhaseKeys_frozen() {
        let keys = [ChallengePeriod.Phase.upcoming(daysToStart: 2), .running(daysLeft: 3),
                    .closing(daysToClose: 1), .finished].map(\.analyticsKey)
        XCTAssertEqual(keys, ["upcoming", "running", "closing", "finished"])
    }

    func testBands() {
        XCTAssertEqual([1, 2, 5, 6, 10, 11, 25, 26, 50].map(Analytics.memberCountBand),
                       ["1", "2-5", "2-5", "6-10", "6-10", "11-25", "11-25", "26+", "26+"])
        XCTAssertEqual([1, 7, 8, 31, 32, 90, 91, 365].map(Analytics.challengeDaysBand),
                       ["1-7", "1-7", "8-31", "8-31", "32-90", "32-90", "91+", "91+"])
    }
}
