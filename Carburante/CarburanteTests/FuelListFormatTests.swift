//
//  FuelListFormatTests.swift
//  CarburanteTests
//
//  Regras puras do histórico de abastecimentos: seta de tendência do km/l
//  (`ConsumptionTrend`) e títulos de mês/dia (`AppFormat`).
//

import XCTest
@testable import Carburante

final class FuelListFormatTests: XCTestCase {

    // MARK: - ConsumptionTrend

    func testNoAverageHasNoTrend() {
        XCTAssertNil(ConsumptionTrend.of(kmPerLiter: 20, average: nil))
        XCTAssertNil(ConsumptionTrend.of(kmPerLiter: 20, average: 0))
    }

    func testEqualToAverageHasNoTrend() {
        XCTAssertNil(ConsumptionTrend.of(kmPerLiter: 20, average: 20))
    }

    func testSmallDeviationIsNoise() {
        // ±4% da média: ruído de bomba, sem seta.
        XCTAssertNil(ConsumptionTrend.of(kmPerLiter: 20.8, average: 20))
        XCTAssertNil(ConsumptionTrend.of(kmPerLiter: 19.2, average: 20))
    }

    func testThresholdIsInclusive() {
        XCTAssertEqual(ConsumptionTrend.of(kmPerLiter: 21, average: 20), .up)
        XCTAssertEqual(ConsumptionTrend.of(kmPerLiter: 19, average: 20), .down)
    }

    func testClearDeviations() {
        XCTAssertEqual(ConsumptionTrend.of(kmPerLiter: 14.6, average: 12), .up)
        XCTAssertEqual(ConsumptionTrend.of(kmPerLiter: 10, average: 12), .down)
    }

    // MARK: - AppFormat

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func testMonthTitleCurrentYearOmitsYear() {
        let now = date(2026, 9, 28)
        XCTAssertEqual(AppFormat.monthTitle(date(2026, 9, 1), now: now, calendar: cal), "Setembro")
    }

    func testMonthTitleOtherYearKeepsLowercasePreposition() {
        // `.capitalized` gerava "Fevereiro De 2025".
        let now = date(2026, 9, 28)
        XCTAssertEqual(AppFormat.monthTitle(date(2025, 2, 1), now: now, calendar: cal), "Fevereiro de 2025")
    }

    func testWeekdayDay() {
        XCTAssertEqual(AppFormat.weekdayDay(date(2026, 9, 28)), "Segunda-feira, 28")
    }

    func testRelativeDay() {
        let now = date(2026, 9, 28)   // segunda-feira
        XCTAssertEqual(AppFormat.relativeDay(date(2026, 9, 28), now: now, calendar: cal), "Hoje")
        XCTAssertEqual(AppFormat.relativeDay(date(2026, 9, 27), now: now, calendar: cal), "Ontem")
        XCTAssertEqual(AppFormat.relativeDay(date(2026, 9, 25), now: now, calendar: cal), "Sexta-feira")
        XCTAssertEqual(AppFormat.relativeDay(date(2026, 9, 10), now: now, calendar: cal), "10 de set.")
        XCTAssertEqual(AppFormat.relativeDay(date(2025, 12, 3), now: now, calendar: cal), "3 de dez. de 2025")
    }

    func testSentenceCased() {
        XCTAssertEqual(AppFormat.sentenceCased("março de 2026"), "Março de 2026")
        XCTAssertEqual(AppFormat.sentenceCased(""), "")
    }

    func testKmPerLiterValueHasNoUnit() {
        XCTAssertEqual(AppFormat.kmPerLiterValue(14.56), "14,6")
        XCTAssertEqual(AppFormat.kmPerLiter(14.56), "14,6 km/l")
    }
}
