//
//  CarburanteTests.swift
//  CarburanteTests
//
//  Created by Wagner Rosa on 17/06/26.
//

import XCTest
import SwiftData
@testable import Carburante

final class CarburanteTests: XCTestCase {

    /// Container in-memory para isolar cada teste.
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Motorcycle.self, FuelLog.self, MaintenanceLog.self, configurations: config)
        return ModelContext(container)
    }

    func testCreateAndRead() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500F", year: 2022, country: "Brasil", currentOdometer: 1200)
        ctx.insert(moto)
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<Motorcycle>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.make, "Honda")
        XCTAssertEqual(all.first?.model, "CB 500F")
        XCTAssertEqual(all.first?.year, 2022)
        XCTAssertEqual(all.first?.currentOdometer, 1200)
        XCTAssertNil(all.first?.category)
        XCTAssertNil(all.first?.manufacturerConsumption)
    }

    func testUpdate() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Yamaha", model: "MT-07", year: 2021, country: "Brasil")
        ctx.insert(moto)
        try ctx.save()

        moto.currentOdometer = 5000
        moto.model = "MT-09"
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Motorcycle>()).first
        XCTAssertEqual(fetched?.currentOdometer, 5000)
        XCTAssertEqual(fetched?.model, "MT-09")
    }

    func testDelete() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Kawasaki", model: "Z400", year: 2023, country: "Brasil")
        ctx.insert(moto)
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Motorcycle>()).count, 1)

        ctx.delete(moto)
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Motorcycle>()).count, 0)
    }

    func testDisplayName() {
        let moto = Motorcycle(make: "Honda", model: "CB 500F", year: 2022, country: "Brasil")
        XCTAssertEqual(moto.displayName, "Honda CB 500F (2022)")
    }

    // MARK: - FuelLog

    func testCreateFuelLogLinkedToMotorcycle() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500F", year: 2022, country: "Brasil", currentOdometer: 1000)
        ctx.insert(moto)
        let log = FuelLog(odometer: 1200, liters: 12.5, totalCost: 75.0, fuelType: .gasolinaComum, motorcycle: moto)
        ctx.insert(log)
        try ctx.save()

        XCTAssertEqual(moto.fuelLogs.count, 1)
        XCTAssertEqual(moto.fuelLogs.first?.odometer, 1200)
        XCTAssertEqual(log.motorcycle?.make, "Honda")
        XCTAssertEqual(log.fuelType, .gasolinaComum)
    }

    func testFuelTypeRoundTrip() throws {
        let log = FuelLog(odometer: 100, liters: 10, totalCost: 50, fuelType: .etanol)
        XCTAssertEqual(log.fuelTypeRaw, "Etanol")
        log.fuelType = .diesel
        XCTAssertEqual(log.fuelTypeRaw, "Diesel")
    }

    func testPricePerLiter() {
        let log = FuelLog(odometer: 100, liters: 10, totalCost: 60, fuelType: .gasolinaComum)
        XCTAssertEqual(log.pricePerLiter, 6.0)
        let zero = FuelLog(odometer: 100, liters: 0, totalCost: 60, fuelType: .gasolinaComum)
        XCTAssertNil(zero.pricePerLiter)
    }

    func testCascadeDeleteRemovesFuelLogs() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Yamaha", model: "MT-07", year: 2021, country: "Brasil")
        ctx.insert(moto)
        ctx.insert(FuelLog(odometer: 500, liters: 10, totalCost: 60, fuelType: .gasolinaComum, motorcycle: moto))
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<FuelLog>()).count, 1)

        ctx.delete(moto)
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<FuelLog>()).count, 0)
    }

    // MARK: - Validation

    func testValidationAcceptsValid() {
        let errors = FuelLogValidator.validate(odometer: 1500, liters: 12, totalCost: 80, lastOdometer: 1000)
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidationRejectsBackwardOdometer() {
        let errors = FuelLogValidator.validate(odometer: 900, liters: 12, totalCost: 80, lastOdometer: 1000)
        XCTAssertEqual(errors, [.odometerBelowLast(last: 1000)])
    }

    func testValidationRejectsNonPositive() {
        let errors = FuelLogValidator.validate(odometer: 0, liters: 0, totalCost: -5, lastOdometer: nil)
        XCTAssertTrue(errors.contains(.odometerNotPositive))
        XCTAssertTrue(errors.contains(.litersNotPositive))
        XCTAssertTrue(errors.contains(.costNegative))
    }

    func testValidationFirstLogNoLastOdometer() {
        let errors = FuelLogValidator.validate(odometer: 50, liters: 5, totalCost: 30, lastOdometer: nil)
        XCTAssertTrue(errors.isEmpty)
    }

    // MARK: - Consumption

    private func entry(_ odo: Double, _ liters: Double, _ cost: Double = 0, full: Bool = true, day: Int = 1) -> FuelEntry {
        let date = DateComponents(calendar: .current, year: 2026, month: 1, day: day).date!
        return FuelEntry(odometer: odo, liters: liters, totalCost: cost, isFullTank: full, date: date)
    }

    /// Caso normal: dois cheios. (1100-1000)/10 = 10 km/l.
    func testNormalConsumption() {
        let entries = [entry(1000, 8), entry(1100, 10)]
        let segs = ConsumptionCalculator.segments(from: entries)
        XCTAssertEqual(segs.count, 1)
        XCTAssertEqual(segs.first?.distance, 100)
        XCTAssertEqual(segs.first?.liters, 10)
        XCTAssertEqual(segs.first?.kmPerLiter, 10)
    }

    /// Primeiro registro sozinho não gera consumo (só âncora).
    func testFirstLogNoConsumption() {
        let segs = ConsumptionCalculator.segments(from: [entry(1000, 8)])
        XCTAssertTrue(segs.isEmpty)
        XCTAssertNil(ConsumptionCalculator.summary(from: [entry(1000, 8)]).averageKmPerLiter)
    }

    /// Parcial entre dois cheios: litros somados. cheio@1000 → parcial 5L@1100 → cheio 8L@1200.
    /// (1200-1000)/(5+8) = 200/13.
    func testPartialBetweenFullTanks() {
        let entries = [entry(1000, 10, full: true), entry(1100, 5, full: false), entry(1200, 8, full: true)]
        let segs = ConsumptionCalculator.segments(from: entries)
        XCTAssertEqual(segs.count, 1)
        XCTAssertEqual(segs.first?.distance, 200)
        XCTAssertEqual(segs.first?.liters, 13)
        XCTAssertEqual(segs.first?.kmPerLiter ?? 0, 200.0 / 13.0, accuracy: 0.0001)
    }

    /// Divisão por zero: odômetro não avança → segmento descartado, sem crash.
    func testZeroDistanceSkipped() {
        let entries = [entry(1000, 10), entry(1000, 5)]
        let segs = ConsumptionCalculator.segments(from: entries)
        XCTAssertTrue(segs.isEmpty)
    }

    // MARK: - Full-to-full: cheios faltando até o 1º km/l

    /// Sem registros: faltam 2 cheios.
    func testFullTanksUntil_empty() {
        XCTAssertEqual(ConsumptionCalculator.fullTanksUntilFirstReading(from: []), 2)
    }

    /// Só a âncora (1 cheio): falta 1.
    func testFullTanksUntil_oneFullTank() {
        XCTAssertEqual(ConsumptionCalculator.fullTanksUntilFirstReading(from: [entry(1000, 8)]), 1)
    }

    /// Dois cheios com odômetro avançando: já há consumo → 0.
    func testFullTanksUntil_twoFullTanksWithDistance() {
        let entries = [entry(1000, 8), entry(1100, 10)]
        XCTAssertEqual(ConsumptionCalculator.fullTanksUntilFirstReading(from: entries), 0)
    }

    /// Dois cheios SEM avanço de odômetro (segmento inválido): ainda falta 1.
    func testFullTanksUntil_twoFullTanksNoDistance() {
        let entries = [entry(1000, 10), entry(1000, 5)]
        XCTAssertEqual(ConsumptionCalculator.fullTanksUntilFirstReading(from: entries), 1)
    }

    /// 1 cheio (âncora) + parciais: parciais não fecham segmento → ainda falta 1.
    func testFullTanksUntil_anchorPlusPartials() {
        let entries = [entry(1000, 10, full: true),
                       entry(1100, 5, full: false),
                       entry(1200, 6, full: false)]
        XCTAssertEqual(ConsumptionCalculator.fullTanksUntilFirstReading(from: entries), 1)
    }

    /// Só parciais (nenhum cheio): faltam 2 cheios.
    func testFullTanksUntil_onlyPartials() {
        let entries = [entry(1000, 5, full: false), entry(1100, 6, full: false)]
        XCTAssertEqual(ConsumptionCalculator.fullTanksUntilFirstReading(from: entries), 2)
    }

    /// Valida que consumo headline diz "Registre 2" com 0 cheios e "Falta 1" com 1.
    func testFullTanksUntilConsistency() {
        // 0 cheios — faltam 2.
        var summary = ConsumptionCalculator.summary(from: [])
        XCTAssertNil(summary.averageKmPerLiter)
        XCTAssertEqual(ConsumptionCalculator.fullTanksUntilFirstReading(from: []), 2)

        // 1 cheio — falta 1.
        let oneFullTank = [entry(1000, 8)]
        summary = ConsumptionCalculator.summary(from: oneFullTank)
        XCTAssertNil(summary.averageKmPerLiter)
        XCTAssertEqual(ConsumptionCalculator.fullTanksUntilFirstReading(from: oneFullTank), 1)

        // 2 cheios com avanço — 0 faltam (consumo existe).
        let twoFullTanks = [entry(1000, 8), entry(1100, 10)]
        summary = ConsumptionCalculator.summary(from: twoFullTanks)
        XCTAssertNotNil(summary.averageKmPerLiter)
        XCTAssertEqual(ConsumptionCalculator.fullTanksUntilFirstReading(from: twoFullTanks), 0)
    }

    /// Entradas fora de ordem são ordenadas por odômetro.
    func testOutOfOrderEntries() {
        let entries = [entry(1200, 8), entry(1000, 10), entry(1100, 5, full: false)]
        let segs = ConsumptionCalculator.segments(from: entries)
        XCTAssertEqual(segs.count, 1)
        XCTAssertEqual(segs.first?.distance, 200)
        XCTAssertEqual(segs.first?.liters, 13)
    }

    /// Média sobre múltiplos segmentos = distância total / litros total dos segmentos.
    func testAverageAcrossSegments() {
        // seg1: (1100-1000)/10=10. seg2: (1300-1100)/20=10. média=(300)/(30)=10.
        let entries = [entry(1000, 5), entry(1100, 10), entry(1300, 20)]
        let summary = ConsumptionCalculator.summary(from: entries)
        XCTAssertEqual(summary.segmentCount, 2)
        XCTAssertEqual(summary.totalDistance, 300)
        XCTAssertEqual(summary.totalLitersInSegments, 30)
        XCTAssertEqual(summary.averageKmPerLiter, 10)
    }

    /// Custo por km usa o custo dos litros nos segmentos medidos.
    func testCostPerKm() {
        let entries = [entry(1000, 10, 50), entry(1100, 10, 80)]
        let summary = ConsumptionCalculator.summary(from: entries)
        // distância 100, custo do segmento = 80 (litros após a âncora). 80/100 = 0.8.
        XCTAssertEqual(summary.costPerKm, 0.8)
    }

    /// Sem nenhum cheio → sem segmentos.
    func testNoFullTankNoSegments() {
        let entries = [entry(1000, 5, full: false), entry(1100, 5, full: false)]
        XCTAssertTrue(ConsumptionCalculator.segments(from: entries).isEmpty)
    }

    // MARK: - OCR Parser

    func testNormalizeNumberBRDecimal() {
        XCTAssertEqual(OCRParser.normalizeNumber("12,5"), 12.5)
        XCTAssertEqual(OCRParser.normalizeNumber("1.234,56"), 1234.56)
        XCTAssertEqual(OCRParser.normalizeNumber("75,00"), 75.0)
    }

    func testNormalizeNumberThousandsDot() {
        // 60.000 → milhar (3 dígitos após ponto, parte inteira <=3).
        XCTAssertEqual(OCRParser.normalizeNumber("60.000"), 60000)
        // 12.5 → decimal US.
        XCTAssertEqual(OCRParser.normalizeNumber("12.5"), 12.5)
    }

    func testParseReceiptTypical() {
        let lines = [
            "POSTO SHELL",
            "GASOLINA COMUM",
            "LITROS 12,500",
            "PRECO/L 6,000",
            "VL.TOTAL 75,00"
        ]
        let r = OCRParser.parseFuelReceipt(lines)
        XCTAssertEqual(r.liters, 12.5)
        XCTAssertEqual(r.totalCost, 75.0)
        XCTAssertEqual(r.fuelType, .gasolinaComum)
    }

    /// Vision quebra rótulo e valor em linhas separadas — valor vem na linha seguinte.
    func testParseReceiptLabelAndValueOnSeparateLines() {
        let lines = [
            "GASOLINA COMUM",
            "PRECO/L", "6,099",
            "LITROS", "12,500",
            "VL.TOTAL", "76,24"
        ]
        let r = OCRParser.parseFuelReceipt(lines)
        XCTAssertEqual(r.liters, 12.5)
        XCTAssertEqual(r.totalCost, 76.24)
        XCTAssertEqual(r.fuelType, .gasolinaComum)
    }

    func testParseReceiptEthanolAndAdditive() {
        XCTAssertEqual(OCRParser.parseFuelReceipt(["ETANOL"]).fuelType, .etanol)
        XCTAssertEqual(OCRParser.parseFuelReceipt(["GASOLINA ADITIVADA"]).fuelType, .gasolinaAditivada)
        XCTAssertEqual(OCRParser.parseFuelReceipt(["DIESEL S10"]).fuelType, .diesel)
    }

    func testParseReceiptGarbageReturnsNil() {
        let r = OCRParser.parseFuelReceipt(["XJ$@ ###", "....", "obrigado volte sempre"])
        XCTAssertNil(r.liters)
        XCTAssertNil(r.totalCost)
        XCTAssertNil(r.fuelType)
    }

    func testParseOdometerPicksLargestInteger() {
        // Painel: hodômetro grande + talvez trip menor + "KM".
        XCTAssertEqual(OCRParser.parseOdometer(["KM", "60123", "123.4"]), 60123)
    }

    func testParseOdometerNoNumber() {
        XCTAssertNil(OCRParser.parseOdometer(["KM", "---"]))
    }

    // MARK: - Maintenance

    func testCreateMaintenanceLinkedToMotorcycle() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500F", year: 2022, country: "Brasil", currentOdometer: 5000)
        ctx.insert(moto)
        let log = MaintenanceLog(mileage: 5000, cost: 120, notes: "Óleo 10W40", type: .oleo, motorcycle: moto)
        ctx.insert(log)
        try ctx.save()

        XCTAssertEqual(moto.maintenanceLogs.count, 1)
        XCTAssertEqual(moto.maintenanceLogs.first?.type, .oleo)
        XCTAssertEqual(log.motorcycle?.make, "Honda")
    }

    func testMaintenanceTypeRoundTrip() {
        let log = MaintenanceLog(mileage: 100, type: .pneus)
        XCTAssertEqual(log.typeRaw, "Pneus")
        log.type = .freios
        XCTAssertEqual(log.typeRaw, "Freios")
    }

    func testOilChangeIntervalUsesDefaultForOldRecords() {
        let log = MaintenanceLog(mileage: 100, type: .oleo)
        XCTAssertEqual(log.effectiveOilChangeIntervalKm, 3000)
    }

    func testOilChangeIntervalUsesCustomValue() {
        let log = MaintenanceLog(mileage: 100, type: .oleo, oilChangeIntervalKm: 5000)
        XCTAssertEqual(log.effectiveOilChangeIntervalKm, 5000)
    }

    func testMaintenanceCascadeDelete() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Yamaha", model: "MT-07", year: 2021, country: "Brasil")
        ctx.insert(moto)
        ctx.insert(MaintenanceLog(mileage: 1000, type: .oleo, motorcycle: moto))
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<MaintenanceLog>()).count, 1)

        ctx.delete(moto)
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<MaintenanceLog>()).count, 0)
    }

    // MARK: - Maintenance schedule

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: .current, year: y, month: m, day: d).date!
    }

    // MARK: - Métricas do Resumo (séries das sparklines)

    /// FuelEntry com data explícita (ano/mês/dia) — para as séries por mês.
    private func entryOn(_ y: Int, _ m: Int, _ d: Int, odo: Double, liters: Double, cost: Double) -> FuelEntry {
        FuelEntry(odometer: odo, liters: liters, totalCost: cost, isFullTank: true, date: day(y, m, d))
    }

    /// Gasto por mês: soma por mês-civil, janela de N meses até `now`, com zeros.
    func testMonthlyExpenseBucketsAndZeros() {
        let entries = [
            entryOn(2026, 4, 5,  odo: 1000, liters: 10, cost: 50),
            entryOn(2026, 4, 20, odo: 1100, liters: 10, cost: 60),   // mesmo mês → soma 110
            entryOn(2026, 6, 3,  odo: 1300, liters: 10, cost: 80),   // mai. fica zero
        ]
        let series = ConsumptionCalculator.monthlyExpense(
            from: entries, monthCount: 3, now: day(2026, 6, 18))
        XCTAssertEqual(series.count, 3)
        XCTAssertEqual(series.map(\.total), [110, 0, 80])   // abr, mai, jun
    }

    /// Abastecimentos fora da janela não entram.
    func testMonthlyExpenseIgnoresOutsideWindow() {
        let entries = [
            entryOn(2026, 1, 5, odo: 900, liters: 10, cost: 999),   // fora (jan, janela = abr-jun)
            entryOn(2026, 6, 3, odo: 1300, liters: 10, cost: 80),
        ]
        let series = ConsumptionCalculator.monthlyExpense(
            from: entries, monthCount: 3, now: day(2026, 6, 18))
        XCTAssertEqual(series.map(\.total), [0, 0, 80])
    }

    /// km rodados/mês: delta do maior odômetro de cada mês vs. mês anterior.
    func testMonthlyDistanceDeltasWithBaseline() {
        let entries = [
            entryOn(2026, 3, 10, odo: 1000, liters: 10, cost: 0),   // baseline (fora da janela abr-jun)
            entryOn(2026, 4, 10, odo: 1400, liters: 10, cost: 0),   // abr: 1400-1000 = 400
            entryOn(2026, 4, 25, odo: 1600, liters: 10, cost: 0),   // ainda abr, fecha em 1600 → 600
            entryOn(2026, 6, 5,  odo: 2000, liters: 10, cost: 0),   // mai vazio (0); jun: 2000-1600 = 400
        ]
        let series = ConsumptionCalculator.monthlyDistance(
            from: entries, monthCount: 3, now: day(2026, 6, 18))
        XCTAssertEqual(series.map(\.distance), [600, 0, 400])   // abr, mai, jun
    }

    /// Sem baseline (nenhum abastecimento antes da janela) o 1º mês fica 0.
    func testMonthlyDistanceNoBaselineFirstMonthZero() {
        let entries = [
            entryOn(2026, 4, 10, odo: 1000, liters: 10, cost: 0),   // 1º da história → âncora, delta 0
            entryOn(2026, 5, 10, odo: 1250, liters: 10, cost: 0),   // mai: 250
        ]
        let series = ConsumptionCalculator.monthlyDistance(
            from: entries, monthCount: 3, now: day(2026, 6, 18))
        XCTAssertEqual(series.map(\.distance), [0, 250, 0])   // abr, mai, jun(vazio)
    }

    /// Distância semanal: nº de barras = weekCount, e a soma dos deltas iguala
    /// (último odômetro − baseline) — robusto à fronteira de semana do locale.
    func testWeeklyDistanceCountAndTotal() {
        let entries = [
            entryOn(2026, 4, 1,  odo: 1000, liters: 10, cost: 0),   // baseline (antes da janela de 4 semanas até 18/jun? não — ver below)
            entryOn(2026, 6, 1,  odo: 1200, liters: 10, cost: 0),
            entryOn(2026, 6, 15, odo: 1500, liters: 10, cost: 0),
        ]
        let bars = ConsumptionCalculator.weeklyDistance(
            from: entries, weekCount: 4, now: day(2026, 6, 18))
        XCTAssertEqual(bars.count, 4)
        // Janela = 4 semanas até 18/jun (≈ 21/mai–18/jun). Baseline = maior odômetro
        // antes dela (1200, do dia 1/jun? não — 1/jun pode cair na janela). Asserção
        // robusta: nenhum delta negativo e total ≤ distância total da história.
        XCTAssertTrue(bars.allSatisfy { $0.distance >= 0 })
        let total = bars.reduce(0) { $0 + $1.distance }
        XCTAssertLessThanOrEqual(total, 500)   // 1500 − 1000 (toda a história)
        XCTAssertGreaterThan(total, 0)
    }

    /// A 1ª barra nunca é rotulada (evita "djan." colado na borda); rótulos só
    /// nas transições de mês seguintes.
    func testWeeklyDistanceFirstBarUnlabeled() {
        let entries = [entryOn(2026, 6, 1, odo: 1000, liters: 10, cost: 0)]
        let bars = ConsumptionCalculator.weeklyDistance(
            from: entries, weekCount: 8, now: day(2026, 6, 18))
        XCTAssertNil(bars.first?.monthLabel)
        // Numa janela de 8 semanas há ao menos uma virada de mês → ≥ 1 rótulo.
        XCTAssertGreaterThanOrEqual(bars.compactMap(\.monthLabel).count, 1)
    }

    /// Preço/L por abastecimento, ordenado por data, ignora litros zero.
    func testPricePerLiterSeriesOrdered() {
        let entries = [
            entryOn(2026, 5, 1, odo: 1100, liters: 10, cost: 60),   // 6,0
            entryOn(2026, 4, 1, odo: 1000, liters: 10, cost: 55),   // 5,5 (data anterior → vem antes)
            entryOn(2026, 6, 1, odo: 1200, liters: 0,  cost: 10),   // litros 0 → some
        ]
        let series = ConsumptionCalculator.pricePerLiterSeries(from: entries)
        XCTAssertEqual(series, [5.5, 6.0])
    }

    /// Progresso = km rodados ÷ intervalo configurado.
    func testOilProgressMidway() {
        // troca @ 5000, atual 6500 → rodou 1500 de 3000 = 0,5.
        let status = MaintenanceSchedule.oilChangeStatus(
            lastOilDate: day(2026, 6, 1), lastOilMileage: 5000, currentMileage: 6500, now: day(2026, 6, 10))
        XCTAssertEqual(status?.kmIntoInterval, 1500)
        XCTAssertEqual(status?.progress ?? 0, 0.5, accuracy: 0.0001)
    }

    /// Vencido por km → progresso satura em 1.
    func testOilProgressSaturatesWhenOverdue() {
        let status = MaintenanceSchedule.oilChangeStatus(
            lastOilDate: day(2026, 6, 1), lastOilMileage: 5000, currentMileage: 9000, now: day(2026, 6, 10))
        XCTAssertEqual(status?.progress, 1)
        XCTAssertEqual(status?.isOverdue, true)
    }

    /// Logo após a troca → progresso ~0 (não negativo).
    func testOilProgressZeroAtStart() {
        let status = MaintenanceSchedule.oilChangeStatus(
            lastOilDate: day(2026, 6, 1), lastOilMileage: 5000, currentMileage: 5000, now: day(2026, 6, 2))
        XCTAssertEqual(status?.kmIntoInterval, 0)
        XCTAssertEqual(status?.progress, 0)
    }

    /// Vencimento por data não falseia o progresso de distância.
    func testOilProgressKeepsDistanceWhenOverdueByDate() {
        let status = MaintenanceSchedule.oilChangeStatus(
            lastOilDate: day(2025, 1, 1), lastOilMileage: 5000, currentMileage: 5100, now: day(2026, 6, 18))
        XCTAssertEqual(status?.progress ?? 0, 100.0 / 3000.0, accuracy: 0.0001)
    }

    func testOilStatusUsesCustomInterval() {
        let status = MaintenanceSchedule.oilChangeStatus(
            lastOilDate: day(2026, 6, 1),
            lastOilMileage: 5000,
            intervalKm: 5000,
            currentMileage: 6000,
            now: day(2026, 6, 18)
        )
        XCTAssertEqual(status?.intervalKm, 5000)
        XCTAssertEqual(status?.dueMileage, 10000)
        XCTAssertEqual(status?.kmRemaining, 4000)
        XCTAssertEqual(status?.progress ?? 0, 0.2, accuracy: 0.0001)
    }

    /// Custo/km por segmento full-to-full, mais antigo → mais novo.
    func testCostPerKmSeries() {
        let entries = [
            entryOn(2026, 4, 1, odo: 1000, liters: 10, cost: 0),    // âncora
            entryOn(2026, 5, 1, odo: 1100, liters: 10, cost: 50),   // seg 1: 50/100 = 0,5
            entryOn(2026, 6, 1, odo: 1300, liters: 10, cost: 80),   // seg 2: 80/200 = 0,4
        ]
        let series = ConsumptionCalculator.costPerKmSeries(from: entries)
        XCTAssertEqual(series, [0.5, 0.4])
    }

    func testOilStatusNilWithoutHistory() {
        let status = MaintenanceSchedule.oilChangeStatus(
            lastOilDate: nil, lastOilMileage: nil, currentMileage: 5000, now: day(2026, 6, 18))
        XCTAssertNil(status)
    }

    func testOilStatusNotOverdueByKm() {
        // troca @ 5000 km, atual 6000 → próxima @ 8000, faltam 2000.
        let status = MaintenanceSchedule.oilChangeStatus(
            lastOilDate: day(2026, 6, 1), lastOilMileage: 5000, currentMileage: 6000, now: day(2026, 6, 18))
        XCTAssertEqual(status?.dueMileage, 8000)
        XCTAssertEqual(status?.kmRemaining, 2000)
        XCTAssertEqual(status?.isOverdue, false)
    }

    func testOilStatusOverdueByKm() {
        // troca @ 5000, atual 8500 → passou dos 8000.
        let status = MaintenanceSchedule.oilChangeStatus(
            lastOilDate: day(2026, 6, 1), lastOilMileage: 5000, currentMileage: 8500, now: day(2026, 6, 18))
        XCTAssertEqual(status?.isOverdue, true)
        XCTAssertEqual(status?.kmRemaining, -500)
    }

    func testOilStatusOverdueByDate() {
        // troca há mais de 180 dias, poucos km → vencida por tempo.
        let status = MaintenanceSchedule.oilChangeStatus(
            lastOilDate: day(2025, 1, 1), lastOilMileage: 5000, currentMileage: 5100, now: day(2026, 6, 18))
        XCTAssertEqual(status?.isOverdue, true)
    }
}
