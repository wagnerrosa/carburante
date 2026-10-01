//
//  OdometerContextTests.swift
//  CarburanteTests
//
//  Contexto do hodômetro no registro antigo (`Models/OdometerContext.swift`):
//  regra do abastecimento (bloqueante), faixa esperada, placeholder, frase de
//  contexto e texto do aviso — a mesma língua nas duas telas de registro antigo.
//

import XCTest
@testable import Carburante

final class OdometerContextTests: XCTestCase {

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: .current, year: y, month: m, day: d, hour: 12).date!
    }

    private lazy var now = day(2026, 9, 28)
    private lazy var jun28 = day(2026, 6, 28)
    private lazy var jul10 = day(2026, 7, 10)

    private func bounds(
        floor: Double? = nil, floorDate: Date? = nil,
        ceiling: Double? = nil, ceilingDate: Date? = nil,
        backdated: Bool = true
    ) -> OdometerBounds {
        OdometerBounds(floor: floor, floorDate: floorDate, ceiling: ceiling,
                       ceilingDate: ceilingDate, isBackdated: backdated)
    }

    private lazy var between = bounds(floor: 19_958, floorDate: jun28, ceiling: 20_310, ceilingDate: jul10)

    // MARK: - Abastecimento (bloqueante)

    func testFuelIssue_backdatedBelowAndAbove() {
        XCTAssertEqual(between.fuelIssue(km: 6_000), .belowEarlier(km: 19_958, date: jun28))
        XCTAssertEqual(between.fuelIssue(km: 21_000), .aboveLater(km: 20_310, date: jul10))
        XCTAssertNil(between.fuelIssue(km: 20_100))
    }

    /// Na hora: piso global sem data → "a moto já está com".
    func testFuelIssue_notBackdatedFloorIsCurrent() {
        let b = bounds(floor: 22_498, backdated: false)
        XCTAssertEqual(b.fuelIssue(km: 22_000), .belowCurrent(km: 22_498))
        XCTAssertNil(b.fuelIssue(km: 22_600), "sem teto na hora")
    }

    // MARK: - Faixa esperada e placeholder

    func testRange_capAtCurrentOnlyForMaintenance() {
        let onlyBefore = bounds(floor: 19_958, floorDate: jun28)
        XCTAssertEqual(onlyBefore.rangePlaceholder(currentOdometer: 22_498, capAtCurrent: true), "19.958 a 22.498")
        XCTAssertEqual(onlyBefore.rangePlaceholder(currentOdometer: 22_498, capAtCurrent: false), "A partir de 19.958")
    }

    func testRangePlaceholder_forms() {
        XCTAssertEqual(between.rangePlaceholder(currentOdometer: 22_498, capAtCurrent: true), "19.958 a 20.310")
        XCTAssertEqual(bounds(ceiling: 20_310, ceilingDate: jul10)
            .rangePlaceholder(currentOdometer: 22_498, capAtCurrent: false), "Até 20.310")
        XCTAssertEqual(bounds().rangePlaceholder(currentOdometer: 22_498, capAtCurrent: true), "Até 22.498",
                       "sem vizinhos, a manutenção antiga não passa do hodômetro atual")
        XCTAssertNil(bounds().rangePlaceholder(currentOdometer: 22_498, capAtCurrent: false))
    }

    /// Na hora não há faixa: o placeholder de sempre ("Atual: …") já diz o piso.
    func testRange_notBackdatedHasNone() {
        let b = bounds(floor: 22_498, backdated: false)
        XCTAssertNil(b.rangePlaceholder(currentOdometer: 22_498, capAtCurrent: true))
    }

    /// Dado antigo incoerente (piso > teto) não vira faixa absurda.
    func testRangePlaceholder_incoherentIsNil() {
        let b = bounds(floor: 21_000, floorDate: jun28, ceiling: 20_310, ceilingDate: jul10)
        XCTAssertNil(b.rangePlaceholder(currentOdometer: 22_498, capAtCurrent: true))
    }

    // MARK: - Frase de contexto

    func testContext_bothNeighbors() {
        XCTAssertEqual(between.contextSentence(currentOdometer: 22_498, capAtCurrent: true, now: now),
                       "Em 28 de jun. a moto tinha 19.958 km e, em 10 de jul., 20.310 km.")
    }

    func testContext_onlyBefore() {
        let b = bounds(floor: 19_958, floorDate: jun28)
        XCTAssertEqual(b.contextSentence(currentOdometer: 22_498, capAtCurrent: true, now: now),
                       "Em 28 de jun. a moto tinha 19.958 km; agora está com 22.498 km.")
        XCTAssertEqual(b.contextSentence(currentOdometer: 22_498, capAtCurrent: false, now: now),
                       "Em 28 de jun. a moto tinha 19.958 km.")
    }

    func testContext_onlyAfter() {
        XCTAssertEqual(bounds(ceiling: 20_310, ceilingDate: jul10)
            .contextSentence(currentOdometer: 22_498, capAtCurrent: true, now: now),
                       "Em 10 de jul. a moto tinha 20.310 km.")
    }

    func testContext_noNeighbors() {
        XCTAssertEqual(bounds().contextSentence(currentOdometer: 22_498, capAtCurrent: true, now: now),
                       "A moto está com 22.498 km.")
        XCTAssertNil(bounds().contextSentence(currentOdometer: 22_498, capAtCurrent: false, now: now))
        XCTAssertNil(bounds().contextSentence(currentOdometer: 0, capAtCurrent: true, now: now))
    }

    // MARK: - Aviso

    func testMessages() {
        XCTAssertEqual(OdometerIssue.belowEarlier(km: 19_958, date: jun28).message(now: now),
                       "Em 28 de jun. a moto já tinha 19.958 km. Confira o número ou a data.")
        XCTAssertEqual(OdometerIssue.aboveLater(km: 20_310, date: jul10).message(now: now),
                       "Em 10 de jul. a moto tinha só 20.310 km. Confira o número ou a data.")
        XCTAssertEqual(OdometerIssue.aboveCurrent(km: 22_498).message(now: now),
                       "A moto está com 22.498 km. Confira o número.")
        XCTAssertEqual(OdometerIssue.belowCurrent(km: 22_498).message(now: now),
                       "A moto já está com 22.498 km.")
    }

    /// Ano só aparece fora do ano corrente.
    func testDayMonth_yearOnlyOutsideCurrentYear() {
        XCTAssertEqual(AppFormat.dayMonth(jun28, now: now), "28 de jun.")
        XCTAssertEqual(AppFormat.dayMonth(day(2025, 12, 3), now: now), "3 de dez. de 2025")
    }

    // MARK: - Registro na hora acima do hodômetro (OdometerAdvance)

    func testAdvance_nilWhenNotAbove() {
        XCTAssertNil(OdometerAdvance.check(km: 1000, current: 1000, deltas: [], daysSinceLast: 3))
        XCTAssertNil(OdometerAdvance.check(km: 900, current: 1000, deltas: [], daysSinceLast: 3))
        XCTAssertNil(OdometerAdvance.check(km: 900, current: 0, deltas: [], daysSinceLast: 3),
                     "moto sem hodômetro: nada a comparar")
    }

    func testAdvance_neutralMessage() {
        let a = OdometerAdvance.check(km: 12_450, current: 12_300, deltas: [300, 280, 310], daysSinceLast: 4)
        XCTAssertEqual(a?.isSuspicious, false)
        XCTAssertEqual(a?.message, "Isto vai atualizar o hodômetro de 12.300 km para 12.450 km")
    }

    /// Typo (um zero a mais) passa do limite de salto do abastecimento.
    func testAdvance_typoIsSuspicious() {
        let a = OdometerAdvance.check(km: 124_500, current: 12_300, deltas: [300, 280, 310], daysSinceLast: 4)
        XCTAssertEqual(a?.isSuspicious, true)
        XCTAssertEqual(a?.message, "+112.200 km desde o último registro — confira o km")
    }
}
