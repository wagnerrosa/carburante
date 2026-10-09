//
//  CostSummaryTests.swift
//  CarburanteTests
//
//  Custos completos (`CostCalculator`): gasolina + manutenção por período,
//  custo real por km, manutenção por tipo, mês a mês e ritmo do ano.
//

import XCTest
@testable import Carburante

@MainActor
final class CostSummaryTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func fuel(_ date: Date, odometer: Double, cost: Double) -> FuelEntry {
        FuelEntry(odometer: odometer, liters: cost / 6, totalCost: cost, isFullTank: true, date: date)
    }

    // MARK: - Período

    func testSummaryAddsFuelAndMaintenanceInsideThePeriodOnly() {
        let entries = [
            fuel(day(2026, 3, 1), odometer: 1000, cost: 60),
            fuel(day(2026, 3, 31), odometer: 2000, cost: 100),
            fuel(day(2026, 4, 2), odometer: 2100, cost: 80),  // fora (abril)
        ]
        let maintenance = [
            MaintenanceCost(date: day(2026, 3, 10), amount: 250, label: "Troca de óleo"),
            MaintenanceCost(date: day(2026, 2, 10), amount: 900, label: "Pneus"),  // fora (fevereiro)
        ]
        let march = calendar.dateInterval(of: .month, for: day(2026, 3, 15))!
        let s = CostCalculator.summary(fuel: entries, maintenance: maintenance, in: march)

        XCTAssertEqual(s.fuel, 160)
        XCTAssertEqual(s.maintenance, 250)
        XCTAssertEqual(s.total, 410)
        // 1000 → 2000 dentro de março + 1/4 do trecho 31/03 12h → 02/04 12h (100 km):
        // os km entre leituras são repartidos pelo tempo, como no Resumo.
        XCTAssertEqual(s.distance, 1025, accuracy: 0.5)
        XCTAssertEqual(s.costPerKm!, 410.0 / 1025, accuracy: 0.0001)
        XCTAssertEqual(s.fuelCostPerKm!, 160.0 / 1025, accuracy: 0.0001)
    }

    func testNoDistanceMeansNoCostPerKm() {
        let s = CostCalculator.summary(fuel: [], maintenance: [MaintenanceCost(date: day(2026, 5, 1), amount: 100, label: "Freios")],
                                       in: calendar.dateInterval(of: .month, for: day(2026, 5, 1))!)
        XCTAssertNil(s.costPerKm)
        XCTAssertEqual(s.total, 100)
    }

    func testMaintenanceByTypeIsGroupedAndSortedByAmount() {
        let maintenance = [
            MaintenanceCost(date: day(2026, 1, 5), amount: 200, label: "Troca de óleo"),
            MaintenanceCost(date: day(2026, 6, 5), amount: 220, label: "Troca de óleo"),
            MaintenanceCost(date: day(2026, 3, 5), amount: 1200, label: "Pneu traseiro"),
            MaintenanceCost(date: day(2026, 4, 5), amount: 90, label: "Freios"),
        ]
        let year = calendar.dateInterval(of: .year, for: day(2026, 6, 1))!
        let s = CostCalculator.summary(fuel: [], maintenance: maintenance, in: year)
        XCTAssertEqual(s.maintenanceByType, [
            .init(label: "Pneu traseiro", amount: 1200),
            .init(label: "Troca de óleo", amount: 420),
            .init(label: "Freios", amount: 90),
        ])
    }

    // MARK: - Mês a mês

    func testMonthlyKeepsEmptyMonthsAndSplitsFuelFromMaintenance() {
        let months = CostCalculator.monthly(
            fuel: [fuel(day(2026, 9, 3), odometer: 100, cost: 70)],
            maintenance: [MaintenanceCost(date: day(2026, 9, 20), amount: 300, label: "Revisão geral")],
            monthCount: 3, now: day(2026, 10, 8), calendar: calendar)
        XCTAssertEqual(months.count, 3)  // ago, set, out
        XCTAssertEqual(months[0], MonthCost(month: calendar.dateInterval(of: .month, for: day(2026, 8, 1))!.start,
                                            fuel: 0, maintenance: 0))
        XCTAssertEqual(months[1].fuel, 70)
        XCTAssertEqual(months[1].maintenance, 300)
        XCTAssertEqual(months[2].fuel + months[2].maintenance, 0)
    }

    // MARK: - Ritmo do ano

    func testYearPaceProjectsAndComparesWithLastYear() {
        let entries = [
            fuel(day(2025, 1, 20), odometer: 100, cost: 400),  // ano anterior, mesmo período
            fuel(day(2025, 11, 1), odometer: 200, cost: 999),  // ano anterior, depois do mesmo dia → fora
            fuel(day(2026, 2, 1), odometer: 300, cost: 500),
        ]
        let now = day(2026, 7, 2)  // ~metade do ano
        let pace = CostCalculator.yearPace(fuel: entries, maintenance: [], now: now, calendar: calendar)
        XCTAssertEqual(pace.soFar, 500)
        XCTAssertEqual(pace.previousSamePeriod, 400)
        XCTAssertEqual(pace.change!, 0.25, accuracy: 0.0001)
        XCTAssertEqual(pace.projection!, 1000, accuracy: 15)  // dobra na metade do ano
    }

    func testNoComparisonWhenBikeArrivedLateLastYear() {
        // Primeiro registro em nov/2025: comparar jan–jul/2026 com meio mês de
        // 2025 daria um "+1.000%" sem sentido → sem comparação.
        let entries = [
            fuel(day(2025, 11, 20), odometer: 100, cost: 40),
            fuel(day(2026, 3, 1), odometer: 900, cost: 600),
        ]
        let pace = CostCalculator.yearPace(fuel: entries, maintenance: [], now: day(2026, 7, 2), calendar: calendar)
        XCTAssertNil(pace.previousSamePeriod)
        XCTAssertNil(pace.change)
        XCTAssertNotNil(pace.projection)
    }

    func testYearPaceStaysQuietEarlyInTheYear() {
        let pace = CostCalculator.yearPace(fuel: [fuel(day(2026, 1, 3), odometer: 1, cost: 50)],
                                           maintenance: [], now: day(2026, 1, 10), calendar: calendar)
        XCTAssertNil(pace.projection)  // menos de 30 dias de ano
        XCTAssertNil(pace.previousSamePeriod)
        XCTAssertNil(pace.change)
    }

    // MARK: - Tudo

    func testAllTimeStartsAtFirstRecordAndAveragesPerMonth() {
        let entries = [fuel(day(2026, 3, 10), odometer: 1, cost: 100)]
        let maintenance = [MaintenanceCost(date: day(2026, 1, 20), amount: 200, label: "Freios")]
        let now = day(2026, 10, 8)
        let interval = CostCalculator.allTimeInterval(fuel: entries, maintenance: maintenance, now: now)!
        XCTAssertEqual(interval.start, day(2026, 1, 20))
        // jan…out = 10 meses
        XCTAssertEqual(CostCalculator.monthlyAverage(total: 300, since: interval.start, now: now, calendar: calendar), 30)
        XCTAssertNil(CostCalculator.allTimeInterval(fuel: [], maintenance: [], now: now))
    }
}
