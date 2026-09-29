//
//  FuelGapTests.swift
//  CarburanteTests
//
//  Lacuna de abastecimento (PLAN/lacuna-abastecimento.md): abastecimentos não
//  registrados antes de um registro quebram a medição. O trecho aberto é
//  descartado e a conta recomeça — cheio vira âncora nova, parcial não ancora.
//

import XCTest
@testable import Carburante

@MainActor
final class FuelGapTests: XCTestCase {

    private func entry(_ odo: Double, _ liters: Double, _ cost: Double = 0,
                       full: Bool = true, gap: Bool = false) -> FuelEntry {
        let date = DateComponents(calendar: .current, year: 2026, month: 1, day: 1).date!
        return FuelEntry(odometer: odo, liters: liters, totalCost: cost, isFullTank: full,
                         date: date, missedPrevious: gap)
    }

    // MARK: - segments

    /// Caso real do plano: 1.066 km ÷ 4 L = 266 km/l. Com a lacuna marcada, o
    /// trecho some — nenhum km/l absurdo entra na média.
    func testGapFullDropsOpenSegment() {
        let entries = [entry(27_000, 10), entry(27_434, 12), entry(28_500, 4, gap: true)]
        let segs = ConsumptionCalculator.segments(from: entries)
        XCTAssertEqual(segs.count, 1)
        XCTAssertEqual(segs.first?.endOdometer, 27_434)
        XCTAssertFalse(segs.contains { $0.kmPerLiter > 100 })
    }

    /// Lacuna cheia vira âncora: o próximo cheio já mede, só com os litros de
    /// depois da lacuna.
    func testGapFullAnchorsNextFull() {
        let entries = [entry(1_000, 10), entry(3_000, 4, gap: true), entry(3_300, 10, 60)]
        let segs = ConsumptionCalculator.segments(from: entries)
        XCTAssertEqual(segs.count, 1)
        XCTAssertEqual(segs.first?.distance, 300)
        XCTAssertEqual(segs.first?.liters, 10)
        XCTAssertEqual(segs.first?.cost, 60)
    }

    /// Lacuna parcial não ancora: o 1º cheio depois dela só ancora; o 2º mede.
    func testGapPartialNeedsTwoFulls() {
        let partialOnly = [entry(1_000, 10), entry(3_000, 4, full: false, gap: true),
                           entry(3_200, 8)]
        XCTAssertTrue(ConsumptionCalculator.segments(from: partialOnly).isEmpty)

        let withSecond = partialOnly + [entry(3_500, 10)]
        let segs = ConsumptionCalculator.segments(from: withSecond)
        XCTAssertEqual(segs.count, 1)
        XCTAssertEqual(segs.first?.distance, 300)
        XCTAssertEqual(segs.first?.liters, 10)
    }

    /// Parciais abertos antes da lacuna não vazam para o trecho seguinte.
    func testGapDiscardsPendingPartials() {
        let entries = [entry(1_000, 10), entry(1_100, 5, full: false),
                       entry(3_000, 4, gap: true), entry(3_200, 8)]
        let segs = ConsumptionCalculator.segments(from: entries)
        XCTAssertEqual(segs.count, 1)
        XCTAssertEqual(segs.first?.liters, 8)
    }

    /// Não regressão: sem lacuna, resultado idêntico ao do full-to-full clássico.
    func testNoGapUnchanged() {
        let entries = [entry(1_000, 10), entry(1_100, 5, full: false), entry(1_200, 8)]
        let segs = ConsumptionCalculator.segments(from: entries)
        XCTAssertEqual(segs.count, 1)
        XCTAssertEqual(segs.first?.distance, 200)
        XCTAssertEqual(segs.first?.liters, 13)
    }

    /// Resumo/recordes leem de `segments` → a lacuna some da média também.
    func testSummaryIgnoresGapSegment() {
        let entries = [entry(1_000, 10), entry(1_300, 10), entry(3_000, 4, gap: true)]
        XCTAssertEqual(ConsumptionCalculator.summary(from: entries).averageKmPerLiter, 30)
        XCTAssertEqual(ConsumptionCalculator.records(from: entries).bestKmPerLiter, 30)
    }

    // MARK: - fullTanksUntilFirstReading

    /// Âncora + lacuna cheia, sem nenhum trecho medido: falta 1.
    func testFullTanksUntil_afterFullGap() {
        let entries = [entry(1_000, 10), entry(3_000, 4, gap: true)]
        XCTAssertEqual(ConsumptionCalculator.fullTanksUntilFirstReading(from: entries), 1)
    }

    /// Âncora + lacuna parcial: a âncora antiga não vale mais → faltam 2.
    func testFullTanksUntil_afterPartialGap() {
        let entries = [entry(1_000, 10), entry(3_000, 4, full: false, gap: true)]
        XCTAssertEqual(ConsumptionCalculator.fullTanksUntilFirstReading(from: entries), 2)
    }

    /// Consumo já medido antes da lacuna continua valendo → 0.
    func testFullTanksUntil_measuredBeforeGap() {
        let entries = [entry(1_000, 10), entry(1_300, 10), entry(3_000, 4, full: false, gap: true)]
        XCTAssertEqual(ConsumptionCalculator.fullTanksUntilFirstReading(from: entries), 0)
    }

    // MARK: - Detecção: salto de km (FuelGap.jumpLimit)

    /// Sem histórico: base de 1.500 km.
    func testJumpLimit_noHistory() {
        XCTAssertEqual(FuelGap.jumpLimit(deltas: [], daysSinceLast: nil), 1_500)
        XCTAssertTrue(FuelGap.isSuspiciousJump(delta: 43_756, deltas: [], daysSinceLast: nil))
        XCTAssertFalse(FuelGap.isSuspiciousJump(delta: 300, deltas: [], daysSinceLast: nil))
    }

    /// Moto que roda tanques longos: 3 × p90 passa da base.
    func testJumpLimit_historyRaisesLimit() {
        let deltas: [Double] = [500, 550, 600, 620, 700]
        XCTAssertEqual(FuelGap.jumpLimit(deltas: deltas, daysSinceLast: nil), 2_100)
    }

    /// Menos de 3 deltas = ruído → só a base.
    func testJumpLimit_fewDeltasUseBase() {
        XCTAssertEqual(FuelGap.jumpLimit(deltas: [900, 1_000], daysSinceLast: nil), 1_500)
    }

    /// Poucos dias limitam o salto (~1.000 km/dia); muitos dias parados não
    /// afrouxam além do limite do histórico.
    func testJumpLimit_days() {
        XCTAssertEqual(FuelGap.jumpLimit(deltas: [], daysSinceLast: 0), 1_000, "mesmo dia conta como 1")
        XCTAssertEqual(FuelGap.jumpLimit(deltas: [], daysSinceLast: 1), 1_000)
        XCTAssertEqual(FuelGap.jumpLimit(deltas: [], daysSinceLast: 60), 1_500)
    }

    /// Deltas ignoram trechos que terminam numa lacuna já marcada.
    func testDeltasSkipMarkedGaps() {
        let entries = [entry(1_000, 10), entry(1_200, 10), entry(9_000, 4, gap: true), entry(9_300, 10)]
        XCTAssertEqual(FuelGap.deltas(from: entries), [200, 300])
    }

    // MARK: - Detecção: km/l implícito

    /// Sem histórico de consumo: teto absoluto (80 km/l). Caso do plano: 266 km/l.
    func testKmPerLiter_absoluteCeiling() {
        let history = [entry(27_434, 12)]
        XCTAssertTrue(FuelGap.isImplausibleKmPerLiter(adding: entry(28_500, 4), to: history))
        XCTAssertFalse(FuelGap.isImplausibleKmPerLiter(adding: entry(27_734, 10), to: history))
    }

    /// Com histórico: 2 × mediana. Moto de 30 km/l → 1 abastecimento esquecido
    /// num salto pequeno (150 km ÷ 2 L = 75 km/l) passa dos 60 e avisa.
    func testKmPerLiter_medianCeiling() {
        let history = [entry(1_000, 10), entry(1_300, 10), entry(1_600, 10)]
        XCTAssertEqual(FuelGap.kmPerLiterCeiling(history: [30, 30]), 60)
        XCTAssertTrue(FuelGap.isImplausibleKmPerLiter(adding: entry(1_750, 2), to: history))
        XCTAssertFalse(FuelGap.isImplausibleKmPerLiter(adding: entry(1_900, 9), to: history))
    }

    /// Parcial no meio do trecho entra no cálculo (mesmo número da média) —
    /// sem ele, o km/l implícito sairia falsamente alto.
    func testKmPerLiter_countsPartialsInSegment() {
        let history = [entry(1_000, 10), entry(1_300, 10), entry(1_600, 10),
                       entry(1_750, 5, full: false)]
        XCTAssertEqual(FuelGap.impliedKmPerLiter(adding: entry(1_900, 5), to: history) ?? 0, 30,
                       accuracy: 0.001)
        XCTAssertFalse(FuelGap.isImplausibleKmPerLiter(adding: entry(1_900, 5), to: history))
    }

    /// Parcial ou lacuna marcada não fecham trecho → nada a avisar.
    func testKmPerLiter_nothingToCheck() {
        let history = [entry(1_000, 10)]
        XCTAssertNil(FuelGap.impliedKmPerLiter(adding: entry(3_000, 2, full: false), to: history))
        XCTAssertNil(FuelGap.impliedKmPerLiter(adding: entry(3_000, 2, gap: true), to: history))
    }

    func testStats() {
        XCTAssertEqual(FuelGap.percentile90([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]), 9)
        XCTAssertEqual(FuelGap.median([3, 1, 2]), 2)
        XCTAssertEqual(FuelGap.median([4, 1, 2, 3]), 2.5)
    }

    // MARK: - Modelo e sync

    func testFuelLogCarriesFlagToEntry() {
        let log = FuelLog(odometer: 1_000, liters: 10, totalCost: 60, fuelType: .gasolinaComum)
        XCTAssertFalse(log.asFuelEntry.missedPrevious, "default = sem lacuna")
        log.missedPrevious = true
        XCTAssertTrue(log.asFuelEntry.missedPrevious)
    }

    func testPullAppliesFlag() throws {
        let now = Date()
        let dto = FuelLogDTO(
            id: UUID(), motorcycle_id: UUID(), user_id: UUID(),
            date: now, odometer: 1_000, liters: 10, total_cost: 60,
            fuel_type: FuelType.gasolinaComum.rawValue, is_full_tank: true,
            latitude: nil, longitude: nil, city: nil, state: nil, country: nil,
            temperature_c: nil, receipt_image_url: nil, odometer_photo_url: nil,
            ocr_processed: false, ocr_confidence: nil,
            date_was_edited: false, location_was_edited: false,
            updated_at: now, revision: 1, deleted_at: nil, created_at: now,
            missed_previous: true
        )
        let log = FuelLog(odometer: 1_000, liters: 10, totalCost: 60, fuelType: .gasolinaComum)
        SyncService.applyFuel(dto, to: log)
        XCTAssertTrue(log.missedPrevious)

        // A chave vai no JSON do push (coluna missed_previous).
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(dto)) as? [String: Any]
        XCTAssertEqual(json?["missed_previous"] as? Bool, true)
    }
}
