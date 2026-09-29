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

    func testSoftDeleteHidesMotorcycleAndCascadesToLogs() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CG 160", year: 2024, country: "Brasil")
        let fuel = FuelLog(date: Date(), odometer: 100, liters: 10, totalCost: 60, fuelType: .gasolinaComum)
        let maint = MaintenanceLog(mileage: 100, cost: 50, type: .oleo)
        ctx.insert(moto)
        fuel.motorcycle = moto
        maint.motorcycle = moto
        try ctx.save()

        let deletedAt = Date(timeIntervalSince1970: 1_000)
        moto.softDelete(now: deletedAt)
        try ctx.save()

        // Linha continua no store (o sync precisa propagar), mas some da leitura.
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Motorcycle>()).count, 1)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Motorcycle>(predicate: Motorcycle.activePredicate)).count, 0)
        XCTAssertEqual(moto.deletedAt, deletedAt)
        XCTAssertEqual(fuel.deletedAt, deletedAt)
        XCTAssertEqual(fuel.updatedAt, deletedAt)
        XCTAssertEqual(maint.deletedAt, deletedAt)

        // Idempotente: não re-carimba.
        moto.softDelete(now: Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(moto.deletedAt, deletedAt)
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

    // MARK: - Reconciliação de hodômetro (bug: exclusão do último abastecimento)

    /// Helper: insere a moto + abastecimentos cheios nos odômetros dados.
    private func motoWithLogs(baseline: Double, odometers: [Double], in ctx: ModelContext) throws -> Motorcycle {
        let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022, country: "Brasil", currentOdometer: baseline)
        ctx.insert(moto)
        for (i, odo) in odometers.enumerated() {
            let date = DateComponents(calendar: .current, year: 2026, month: 1, day: i + 1).date!
            ctx.insert(FuelLog(date: date, odometer: odo, liters: 10, totalCost: 60, fuelType: .gasolinaComum, motorcycle: moto))
            moto.reconcileOdometer(latestEntry: odo)
        }
        try ctx.save()
        return moto
    }

    /// Excluir o abastecimento MAIS RECENTE → hodômetro cai para o próximo maior.
    func testReconcile_deleteNewestFallsToPrevious() throws {
        let ctx = try makeContext()
        let moto = try motoWithLogs(baseline: 1000, odometers: [1200, 1500, 1800], in: ctx)
        XCTAssertEqual(moto.currentOdometer, 1800)

        // Exclui o registro de 1800 (o mais recente / maior).
        let newest = moto.fuelLogs.max { $0.odometer < $1.odometer }!
        ctx.delete(newest)
        try ctx.save()
        moto.reconcileOdometer()

        XCTAssertEqual(moto.currentOdometer, 1500, "deve cair para o próximo maior")
    }

    /// Excluir um abastecimento INTERMEDIÁRIO não mexe no hodômetro (o maior continua).
    func testReconcile_deleteMiddleKeepsMax() throws {
        let ctx = try makeContext()
        let moto = try motoWithLogs(baseline: 1000, odometers: [1200, 1500, 1800], in: ctx)

        let middle = moto.fuelLogs.first { $0.odometer == 1500 }!
        ctx.delete(middle)
        try ctx.save()
        moto.reconcileOdometer()

        XCTAssertEqual(moto.currentOdometer, 1800, "o maior (1800) permanece")
    }

    /// Excluir o ÚNICO abastecimento → cai para o baseline manual, nunca zera.
    func testReconcile_deleteOnlyLogFallsToBaseline() throws {
        let ctx = try makeContext()
        let moto = try motoWithLogs(baseline: 1000, odometers: [1200], in: ctx)
        XCTAssertEqual(moto.currentOdometer, 1200)

        let only = moto.fuelLogs.first!
        ctx.delete(only)
        try ctx.save()
        moto.reconcileOdometer()

        XCTAssertEqual(moto.currentOdometer, 1000, "volta ao baseline de cadastro, não a zero")
    }

    /// Editar o maior abastecimento PARA BAIXO reconcilia o hodômetro p/ baixo.
    func testReconcile_editNewestDownLowersOdometer() throws {
        let ctx = try makeContext()
        let moto = try motoWithLogs(baseline: 1000, odometers: [1200, 1800], in: ctx)
        XCTAssertEqual(moto.currentOdometer, 1800)

        let newest = moto.fuelLogs.first { $0.odometer == 1800 }!
        newest.odometer = 1400          // correção manual p/ baixo
        moto.reconcileOdometer(latestEntry: 1400)
        try ctx.save()

        XCTAssertEqual(moto.currentOdometer, 1400, "1400 ainda > 1200 e > baseline 1000")
    }

    /// Migração preguiçosa: moto antiga (baseline 0) com hodômetro manual acima
    /// dos logs não é zerada ao excluir o único abastecimento.
    func testReconcile_legacyBaselineZeroNotWiped() throws {
        let ctx = try makeContext()
        // Simula store antigo: baseline 0, currentOdometer manual alto, 1 log abaixo.
        let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022, country: "Brasil")
        moto.odometerBaseline = 0          // como viria de um registro pré-campo
        moto.currentOdometer = 20_000      // leitura manual de cadastro
        ctx.insert(moto)
        let log = FuelLog(odometer: 20_500, liters: 10, totalCost: 60, fuelType: .gasolinaComum, motorcycle: moto)
        ctx.insert(log)
        moto.reconcileOdometer(latestEntry: 20_500)   // currentOdometer = 20500
        try ctx.save()

        ctx.delete(log)
        try ctx.save()
        moto.reconcileOdometer()

        XCTAssertGreaterThan(moto.currentOdometer, 0, "nunca zera uma moto legada")
        XCTAssertEqual(moto.currentOdometer, 20_500, "preserva o maior valor conhecido como baseline")
    }

    // MARK: - Lembretes locais de ausência

    private func day(_ d: Int) -> Date {
        DateComponents(calendar: .current, year: 2026, month: 3, day: d, hour: 12).date!
    }

    /// Logo após abastecer (mesmo dia): os 3 marcos 7/14/21 estão no futuro.
    func testAbsence_allFutureRightAfterFueling() {
        let last = day(1)
        let pending = AbsenceReminder.pendingFireDates(lastFuelDate: last, now: last)
        XCTAssertEqual(pending.map(\.day), [7, 14, 21])
    }

    /// 10 dias depois: o marco de 7 já passou; restam 14 e 21.
    func testAbsence_dropsPastMilestones() {
        let last = day(1)
        let pending = AbsenceReminder.pendingFireDates(lastFuelDate: last, now: day(11))
        XCTAssertEqual(pending.map(\.day), [14, 21])
    }

    /// Passados todos os marcos: nada a agendar.
    func testAbsence_noneAfterAllMilestones() {
        let last = day(1)
        let pending = AbsenceReminder.pendingFireDates(lastFuelDate: last, now: day(30))
        XCTAssertTrue(pending.isEmpty)
    }

    /// As datas de disparo são exatamente último + N dias.
    func testAbsence_fireDatesAreOffsetFromLast() {
        let last = day(1)
        let pending = AbsenceReminder.pendingFireDates(lastFuelDate: last, now: last)
        let cal = Calendar.current
        XCTAssertEqual(pending.first { $0.day == 7 }?.fireDate, cal.date(byAdding: .day, value: 7, to: last))
        XCTAssertEqual(pending.first { $0.day == 21 }?.fireDate, cal.date(byAdding: .day, value: 21, to: last))
    }

    // MARK: - Lembretes de manutenção (genéricos + coalescência)

    private func mStatus(
        type: MaintenanceType = .oleo,
        intervalKm: Double? = 3000,
        intervalMonths: Int? = 6,
        dueMileage: Double? = 13000,
        dueDate: Date? = nil,
        kmRemaining: Double? = 2900,
        daysRemaining: Int? = nil,
        progress: Double = 0.03,
        overdue: Bool = false
    ) -> MaintenanceStatus {
        MaintenanceStatus(
            type: type, intervalKm: intervalKm, intervalMonths: intervalMonths,
            lastMileage: 10000, lastDate: day(1), dueMileage: dueMileage, dueDate: dueDate,
            kmRemaining: kmRemaining, daysRemaining: daysRemaining,
            progress: progress, isOverdue: overdue)
    }

    /// Sem status → nenhum lembrete.
    func testMaint_noStatusNoPlans() {
        XCTAssertTrue(MaintenanceReminder.plans(for: [], now: day(1)).isEmpty)
    }

    /// Longe do prazo: planos por data (pré + no prazo), nada reativo (<80%).
    func testMaint_farFromDueOnlyDatePlans() {
        let now = day(1)
        let due = Calendar.current.date(byAdding: .day, value: 100, to: now)!
        let status = mStatus(dueDate: due, kmRemaining: 2900, progress: 0.03)
        let plans = MaintenanceReminder.plans(for: [status], now: now)
        let ids = Set(plans.map(\.idSuffix))
        XCTAssertTrue(ids.contains("oleo-date-pre"))
        XCTAssertTrue(ids.contains("oleo-date-due"))
        XCTAssertFalse(plans.contains { $0.idSuffix.hasSuffix("-km") }, "progresso < 80% não dispara reativo")
    }

    /// Aviso por data só entra se a antecedência (7 dias) ainda é futura.
    func testMaint_preWarningSkippedWhenPast() {
        let now = day(20)
        let due = day(25)   // faltam 5 dias < 7 → pré não entra
        let status = mStatus(dueDate: due, kmRemaining: 1000, progress: 0.6)
        let ids = Set(MaintenanceReminder.plans(for: [status], now: now).map(\.idSuffix))
        XCTAssertFalse(ids.contains("oleo-date-pre"))
        XCTAssertTrue(ids.contains("oleo-date-due"))
    }

    /// isAttention: ≥80% ou vencido é atenção; abaixo não.
    func testMaint_isAttentionThreshold() {
        XCTAssertFalse(MaintenanceReminder.isAttention(mStatus(progress: 0.5)))
        XCTAssertTrue(MaintenanceReminder.isAttention(mStatus(progress: 0.8)))
        XCTAssertTrue(MaintenanceReminder.isAttention(mStatus(progress: 0.1, overdue: true)))
    }

    /// Coalescência: 0 em atenção → nil.
    func testReactive_noneNil() {
        XCTAssertNil(MaintenanceReminder.reactivePlan(attention: [], morning: day(2)))
    }

    /// 1 em atenção → lembrete específico do tipo (id `<tipo>-km`).
    func testReactive_oneSpecific() {
        let plan = MaintenanceReminder.reactivePlan(
            attention: [mStatus(type: .pneus, progress: 0.9)], morning: day(2))
        XCTAssertEqual(plan?.idSuffix, "pneus-km")
        XCTAssertEqual(plan?.title, "Pneus: próxima")
    }

    /// ≥2 em atenção → uma só notificação resumo (anti-spam).
    func testReactive_manyCoalesceToSummary() {
        let plan = MaintenanceReminder.reactivePlan(
            attention: [mStatus(type: .oleo, overdue: true),
                        mStatus(type: .pneus, progress: 0.85)],
            morning: day(2))
        XCTAssertEqual(plan?.idSuffix, "summary-km")
        XCTAssertEqual(plan?.title, "Manutenções pendentes")
        XCTAssertTrue(plan?.body.contains("2 itens") ?? false)
    }

    /// Vencido: sem planos de data (passados); o reativo entra como "vencida".
    func testMaint_overdueNoDatePlansReactiveOnly() {
        let now = day(10)
        let status = mStatus(dueDate: day(1), kmRemaining: -50, progress: 1, overdue: true)
        let plans = MaintenanceReminder.plans(for: [status], now: now)
        XCTAssertFalse(plans.contains { $0.idSuffix.contains("date") }, "datas passadas não se agendam")
        let reactive = plans.first { $0.idSuffix == "oleo-km" }
        XCTAssertEqual(reactive?.title, "Troca de óleo: vencida")
    }

    // MARK: - Cadastro mínimo (categoria/cilindrada/país opcionais)

    /// Moto registrada só com marca/modelo (sem categoria/cilindrada): válida,
    /// e a referência de categoria fica nil (card de comparação só não aparece).
    func testMinimalRegistration_noCategoryNoReference() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022, country: "Brasil")
        ctx.insert(moto)
        try ctx.save()

        XCTAssertNil(moto.categoryEnum)
        XCTAssertNil(moto.displacementCC)
        XCTAssertNil(moto.categoryReferenceKmPerLiter, "sem categoria/cc → sem referência, sem crash")
        XCTAssertEqual(moto.displayName, "Honda CB 500 (2022)")
    }

    /// Completar categoria + cilindrada depois habilita a referência.
    func testMinimalRegistration_fillingDetailsEnablesReference() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022, country: "Brasil")
        ctx.insert(moto)
        moto.categoryEnum = .street
        moto.displacementCC = 500
        try ctx.save()

        XCTAssertNotNil(moto.categoryReferenceKmPerLiter, "categoria + cc → referência disponível")
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

    func testIntervalUsesDefaultForOldRecords() {
        let log = MaintenanceLog(mileage: 100, type: .oleo)
        XCTAssertEqual(log.effectiveIntervalKm, 3000)
        XCTAssertEqual(log.effectiveIntervalMonths, 6)
    }

    func testIntervalUsesCustomValue() {
        let log = MaintenanceLog(mileage: 100, type: .oleo, intervalKm: 5000, intervalMonths: 12)
        XCTAssertEqual(log.effectiveIntervalKm, 5000)
        XCTAssertEqual(log.effectiveIntervalMonths, 12)
    }

    /// Defaults por tipo: todo tipo (menos "Outro") sugere km e meses.
    func testIntervalDefaultsPerType() {
        XCTAssertEqual(MaintenanceLog(mileage: 1, type: .pneus).effectiveIntervalKm, 12000)
        XCTAssertEqual(MaintenanceLog(mileage: 1, type: .pneus).effectiveIntervalMonths, 60)
        XCTAssertEqual(MaintenanceLog(mileage: 1, type: .relacao).effectiveIntervalKm, 20000)
        XCTAssertNil(MaintenanceLog(mileage: 1, type: .outro).effectiveIntervalKm)
        XCTAssertNil(MaintenanceLog(mileage: 1, type: .outro).effectiveIntervalMonths)
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

    /// Atalho p/ status de óleo (defaults 3000 km / 6 meses, salvo override).
    private func oilSchedule(
        lastDate: Date?, lastMileage: Double?,
        intervalKm: Double? = 3000, intervalMonths: Int? = 6,
        current: Double, now: Date
    ) -> MaintenanceStatus? {
        MaintenanceSchedule.status(
            for: .oleo, lastDate: lastDate, lastMileage: lastMileage,
            intervalKm: intervalKm, intervalMonths: intervalMonths,
            currentMileage: current, now: now)
    }

    /// Progresso = km rodados ÷ intervalo configurado (km é o eixo vinculante aqui).
    func testOilProgressMidway() {
        // troca @ 5000, atual 6500 → rodou 1500 de 3000 = 0,5; poucos dias → tempo < km.
        let status = oilSchedule(
            lastDate: day(2026, 6, 1), lastMileage: 5000, current: 6500, now: day(2026, 6, 10))
        XCTAssertEqual(status?.kmIntoInterval, 1500)
        XCTAssertEqual(status?.progress ?? 0, 0.5, accuracy: 0.0001)
    }

    /// Vencido por km → progresso satura em 1.
    func testOilProgressSaturatesWhenOverdue() {
        let status = oilSchedule(
            lastDate: day(2026, 6, 1), lastMileage: 5000, current: 9000, now: day(2026, 6, 10))
        XCTAssertEqual(status?.progress, 1)
        XCTAssertEqual(status?.isOverdue, true)
    }

    /// No exato momento da troca (mesmo dia) → progresso 0 nos dois eixos.
    func testOilProgressZeroAtStart() {
        let status = oilSchedule(
            lastDate: day(2026, 6, 1), lastMileage: 5000, current: 5000, now: day(2026, 6, 1))
        XCTAssertEqual(status?.kmIntoInterval, 0)
        XCTAssertEqual(status?.progress, 0)
    }

    /// Vencido por DATA com poucos km → progresso satura em 1 (eixo tempo é o
    /// vinculante; `progress = max(km, tempo)`).
    func testProgressBindingAxisTimeOverdue() {
        let status = oilSchedule(
            lastDate: day(2025, 1, 1), lastMileage: 5000, current: 5100, now: day(2026, 6, 18))
        XCTAssertEqual(status?.progress, 1)
        XCTAssertEqual(status?.isOverdue, true)
    }

    func testOilStatusUsesCustomInterval() {
        let status = oilSchedule(
            lastDate: day(2026, 6, 1), lastMileage: 5000,
            intervalKm: 5000, current: 6000, now: day(2026, 6, 18))
        XCTAssertEqual(status?.intervalKm, 5000)
        XCTAssertEqual(status?.dueMileage, 10000)
        XCTAssertEqual(status?.kmRemaining, 4000)
        XCTAssertEqual(status?.progress ?? 0, 0.2, accuracy: 0.0001)
    }

    // MARK: - Agendamento genérico (km / tempo / o que vier primeiro)

    /// Só eixo km (sem tempo): sem dueDate/daysRemaining; vence por km.
    func testKmOnlyInterval() {
        let status = MaintenanceSchedule.status(
            for: .pneus, lastDate: day(2026, 1, 1), lastMileage: 10000,
            intervalKm: 12000, intervalMonths: nil, currentMileage: 23000, now: day(2026, 6, 18))
        XCTAssertEqual(status?.dueMileage, 22000)
        XCTAssertNil(status?.dueDate)
        XCTAssertNil(status?.daysRemaining)
        XCTAssertEqual(status?.isOverdue, true, "passou dos 22000")
    }

    /// Só eixo tempo (sem km): sem dueMileage/kmRemaining; vence por data.
    func testTimeOnlyInterval() {
        let status = MaintenanceSchedule.status(
            for: .freios, lastDate: day(2025, 1, 1), lastMileage: 10000,
            intervalKm: nil, intervalMonths: 12, currentMileage: 10500, now: day(2026, 6, 18))
        XCTAssertNil(status?.dueMileage)
        XCTAssertNil(status?.kmRemaining)
        XCTAssertNotNil(status?.dueDate)
        XCTAssertEqual(status?.isOverdue, true, "passou de 12 meses")
    }

    /// Nenhum eixo configurado → nil (nada a prever).
    func testNoAxisNoStatus() {
        let status = MaintenanceSchedule.status(
            for: .outro, lastDate: day(2026, 1, 1), lastMileage: 10000,
            intervalKm: nil, intervalMonths: nil, currentMileage: 20000, now: day(2026, 6, 18))
        XCTAssertNil(status)
    }

    /// O que vier primeiro — tempo vence antes do km.
    func testWhatFirst_timeBeforeKm() {
        // km longe (rodou pouco), mas 18 meses passados > 6 → vencido por tempo.
        let status = MaintenanceSchedule.status(
            for: .oleo, lastDate: day(2025, 1, 1), lastMileage: 5000,
            intervalKm: 3000, intervalMonths: 6, currentMileage: 5200, now: day(2026, 6, 18))
        XCTAssertEqual(status?.isOverdue, true)
        XCTAssertGreaterThan(status?.kmRemaining ?? 0, 0, "km ainda não venceu")
    }

    /// O que vier primeiro — km vence antes do tempo.
    func testWhatFirst_kmBeforeTime() {
        // tempo longe (poucos dias), mas rodou além do intervalo → vencido por km.
        let status = MaintenanceSchedule.status(
            for: .oleo, lastDate: day(2026, 6, 1), lastMileage: 5000,
            intervalKm: 3000, intervalMonths: 6, currentMileage: 8500, now: day(2026, 6, 10))
        XCTAssertEqual(status?.isOverdue, true)
        XCTAssertNotNil(status?.daysRemaining)
        XCTAssertGreaterThan(status?.daysRemaining ?? 0, 0, "tempo ainda não venceu")
    }

    /// Histórico: última manutenção, km e meses desde, e ordenação por urgência.
    func testHistoryAccessorsAndUrgencySort() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022,
                              country: "Brasil", currentOdometer: 30000)
        ctx.insert(moto)
        // Óleo vencido por km (troca @ 5000, intervalo 3000, atual 30000).
        ctx.insert(MaintenanceLog(date: day(2026, 1, 1), mileage: 5000, type: .oleo, motorcycle: moto))
        // Pneus recém-trocados (atual 30000, intervalo 12000).
        ctx.insert(MaintenanceLog(date: day(2026, 6, 1), mileage: 29500, type: .pneus, motorcycle: moto))
        try ctx.save()

        XCTAssertEqual(moto.lastService(of: .oleo)?.mileage, 5000)
        XCTAssertEqual(moto.kmSinceLastService(of: .pneus), 500)
        XCTAssertNil(moto.kmSinceLastService(of: .freios), "nunca registrado")

        let statuses = moto.maintenanceStatuses(now: day(2026, 6, 18))
        XCTAssertEqual(statuses.count, 2)
        XCTAssertEqual(statuses.first?.type, .oleo, "vencido vem primeiro")
        XCTAssertEqual(moto.nextDueMaintenance(now: day(2026, 6, 18))?.type, .oleo)
    }

    /// Retro-registro (data antiga, km menor) não rouba a âncora do próximo
    /// vencimento — a última continua sendo a mais recente por data.
    func testLastServiceBackfillOlderDateKeepsAnchor() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022,
                              country: "Brasil", currentOdometer: 21000)
        ctx.insert(moto)
        ctx.insert(MaintenanceLog(date: day(2026, 6, 1), mileage: 20000, type: .oleo, motorcycle: moto))
        try ctx.save()
        // Backfill inserido DEPOIS, com data e km antigos.
        ctx.insert(MaintenanceLog(date: day(2026, 1, 1), mileage: 5000, type: .oleo, motorcycle: moto))
        try ctx.save()

        XCTAssertEqual(moto.lastService(of: .oleo)?.mileage, 20000)
    }

    /// Mesmo DIA decide pelo maior km, mesmo com horas diferentes — o form
    /// carimba a hora de abertura, então um retro-registro digitado à tarde
    /// (km menor) "parecia" mais novo que o registro real da manhã e roubava
    /// a âncora do próximo vencimento.
    func testLastServiceSameDayTieBreaksByMileage() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022,
                              country: "Brasil", currentOdometer: 21000)
        ctx.insert(moto)
        // Registro real: 1º de junho às 9h, 20.000 km.
        ctx.insert(MaintenanceLog(date: day(2026, 6, 1).addingTimeInterval(9 * 3600),
                                  mileage: 20000, type: .oleo, motorcycle: moto))
        try ctx.save()
        // Retro-registro digitado às 14h do MESMO dia, com km antigo.
        ctx.insert(MaintenanceLog(date: day(2026, 6, 1).addingTimeInterval(14 * 3600),
                                  mileage: 5000, type: .oleo, motorcycle: moto))
        try ctx.save()

        XCTAssertEqual(moto.lastService(of: .oleo)?.mileage, 20000)
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
        let status = oilSchedule(lastDate: nil, lastMileage: nil, current: 5000, now: day(2026, 6, 18))
        XCTAssertNil(status)
    }

    func testOilStatusNotOverdueByKm() {
        // troca @ 5000 km, atual 6000 → próxima @ 8000, faltam 2000; 17 dias < 6 meses.
        let status = oilSchedule(
            lastDate: day(2026, 6, 1), lastMileage: 5000, current: 6000, now: day(2026, 6, 18))
        XCTAssertEqual(status?.dueMileage, 8000)
        XCTAssertEqual(status?.kmRemaining, 2000)
        XCTAssertEqual(status?.isOverdue, false)
    }

    func testOilStatusOverdueByKm() {
        // troca @ 5000, atual 8500 → passou dos 8000.
        let status = oilSchedule(
            lastDate: day(2026, 6, 1), lastMileage: 5000, current: 8500, now: day(2026, 6, 18))
        XCTAssertEqual(status?.isOverdue, true)
        XCTAssertEqual(status?.kmRemaining, -500)
    }

    func testOilStatusOverdueByDate() {
        // troca há mais de 6 meses, poucos km → vencida por tempo.
        let status = oilSchedule(
            lastDate: day(2025, 1, 1), lastMileage: 5000, current: 5100, now: day(2026, 6, 18))
        XCTAssertEqual(status?.isOverdue, true)
    }

    // MARK: - Combo Revisão Geral (Fase B)

    /// Plano de combo: tudo novo → cria todos os marcados, preservando a ordem
    /// de `revisaoComboTypes`.
    func testRevisaoComboPlan_new() {
        let plan = RevisaoCombo.plan(selected: [.oleo, .relacao], existing: [])
        XCTAssertEqual(plan.toCreate, [.oleo, .relacao])
        XCTAssertTrue(plan.toDelete.isEmpty)
        XCTAssertTrue(plan.toKeep.isEmpty)
    }

    /// Desmarcar um item existente → entra em toDelete; o mantido em toKeep.
    func testRevisaoComboPlan_toggleOffDeletes() {
        let plan = RevisaoCombo.plan(selected: [.oleo], existing: [.oleo, .filtros])
        XCTAssertEqual(plan.toKeep, [.oleo])
        XCTAssertEqual(plan.toDelete, [.filtros])
        XCTAssertTrue(plan.toCreate.isEmpty)
    }

    /// Marcar um novo item mantendo os antigos → toCreate só o novo.
    func testRevisaoComboPlan_toggleOnAdds() {
        let plan = RevisaoCombo.plan(selected: [.oleo, .pneus], existing: [.oleo])
        XCTAssertEqual(plan.toCreate, [.pneus])
        XCTAssertEqual(plan.toKeep, [.oleo])
        XCTAssertTrue(plan.toDelete.isEmpty)
    }

    /// Itens-filhos: ligação por partOfMaintenanceID, rótulo de inclusos e custo 0.
    func testRevisaoChildrenLinkLabelAndCost() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022,
                              country: "Brasil", currentOdometer: 30000)
        ctx.insert(moto)
        let parent = MaintenanceLog(date: day(2026, 6, 1), mileage: 30000, cost: 820,
                                    type: .revisao, motorcycle: moto)
        ctx.insert(parent)
        for t in [MaintenanceType.oleo, .filtros] {
            ctx.insert(MaintenanceLog(date: day(2026, 6, 1), mileage: 30000, cost: 0,
                                      type: t, partOfMaintenanceID: parent.id, motorcycle: moto))
        }
        try ctx.save()

        XCTAssertEqual(parent.children.count, 2)
        XCTAssertEqual(parent.includedItemsLabel, "filtros, troca de óleo")  // ordenado por rawValue
        XCTAssertTrue(parent.children.allSatisfy { $0.cost == 0 }, "custo da visita fica no pai")
        XCTAssertTrue(parent.children.allSatisfy(\.isPartOfRevisao))
        XCTAssertFalse(parent.isPartOfRevisao)
    }

    /// Um item gerado pela revisão reinicia o contador do seu tipo: o óleo
    /// vencido (troca antiga) deixa de estar vencido após a revisão recente.
    func testRevisaoChildResetsSchedule() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022,
                              country: "Brasil", currentOdometer: 30000)
        ctx.insert(moto)
        // Troca de óleo antiga e vencida (km e tempo).
        ctx.insert(MaintenanceLog(date: day(2025, 1, 1), mileage: 5000, type: .oleo, motorcycle: moto))
        XCTAssertEqual(moto.maintenanceStatus(for: .oleo, now: day(2026, 6, 10))?.isOverdue, true)

        // Revisão recente que inclui óleo (filho @ 30000).
        let parent = MaintenanceLog(date: day(2026, 6, 1), mileage: 30000, type: .revisao, motorcycle: moto)
        ctx.insert(parent)
        ctx.insert(MaintenanceLog(date: day(2026, 6, 1), mileage: 30000, cost: 0,
                                  type: .oleo, partOfMaintenanceID: parent.id, motorcycle: moto))
        try ctx.save()

        XCTAssertEqual(moto.lastService(of: .oleo)?.mileage, 30000, "o filho mais recente é a âncora")
        let status = moto.maintenanceStatus(for: .oleo, now: day(2026, 6, 10))
        XCTAssertEqual(status?.isOverdue, false, "contador reiniciado pela revisão")
        XCTAssertEqual(status?.kmRemaining, 3000)
    }

    /// `.revisao` é ação de registro, não meta: NÃO aparece em Programadas
    /// (`maintenanceStatuses`) nem como herói do Resumo, mesmo com um pai logado.
    /// Guarda de regressão da causa do nível-misto.
    func testRevisaoNotSchedulable() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022,
                              country: "Brasil", currentOdometer: 30000)
        ctx.insert(moto)
        // Revisão logada que inclui óleo (pai .revisao + filho .oleo).
        let parent = MaintenanceLog(date: day(2026, 6, 1), mileage: 30000, type: .revisao, motorcycle: moto)
        ctx.insert(parent)
        ctx.insert(MaintenanceLog(date: day(2026, 6, 1), mileage: 30000, cost: 0,
                                  type: .oleo, partOfMaintenanceID: parent.id, motorcycle: moto))
        try ctx.save()

        let statuses = moto.maintenanceStatuses(now: day(2026, 6, 10))
        XCTAssertFalse(statuses.contains { $0.type == .revisao },
                       "revisão não é meta agendável")
        XCTAssertTrue(statuses.contains { $0.type == .oleo },
                      "o item reiniciado pela revisão aparece por conta própria")
        XCTAssertNotEqual(moto.nextDueMaintenance(now: day(2026, 6, 10))?.type, .revisao)
        XCTAssertFalse(MaintenanceType.revisao.isSchedulable)
        XCTAssertFalse(MaintenanceType.outro.isSchedulable)
        XCTAssertTrue(MaintenanceType.oleo.isSchedulable)
    }

    // MARK: - Pneus: posição dianteiro/traseiro com contadores próprios

    /// Dianteiro e traseiro são acompanhados de forma independente: trocar só o
    /// traseiro não reinicia o contador do dianteiro.
    func testTirePositionsAreIndependent() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022,
                              country: "Brasil", currentOdometer: 40000)
        ctx.insert(moto)
        // Dianteiro trocado há muito (vencido por km: @ 20000, intervalo 12000).
        ctx.insert(MaintenanceLog(date: day(2025, 6, 1), mileage: 20000,
                                  type: .pneus, tirePosition: .dianteiro, motorcycle: moto))
        // Traseiro recém-trocado.
        ctx.insert(MaintenanceLog(date: day(2026, 6, 1), mileage: 39000,
                                  type: .pneus, tirePosition: .traseiro, motorcycle: moto))
        try ctx.save()

        XCTAssertEqual(moto.lastService(of: .pneus, position: .dianteiro)?.mileage, 20000)
        XCTAssertEqual(moto.lastService(of: .pneus, position: .traseiro)?.mileage, 39000)

        let front = moto.maintenanceStatus(for: .pneus, position: .dianteiro, now: day(2026, 6, 18))
        let rear = moto.maintenanceStatus(for: .pneus, position: .traseiro, now: day(2026, 6, 18))
        XCTAssertEqual(front?.isOverdue, true, "dianteiro vencido")
        XCTAssertEqual(rear?.isOverdue, false, "traseiro em dia")
        XCTAssertEqual(rear?.kmRemaining, 11000)
    }

    /// `maintenanceStatuses` gera uma linha "Programadas" por posição registrada,
    /// com rótulo e id distintos (dianteiro/traseiro).
    func testTireStatusesOneRowPerPosition() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022,
                              country: "Brasil", currentOdometer: 40000)
        ctx.insert(moto)
        ctx.insert(MaintenanceLog(date: day(2026, 1, 1), mileage: 30000,
                                  type: .pneus, tirePosition: .dianteiro, motorcycle: moto))
        ctx.insert(MaintenanceLog(date: day(2026, 1, 1), mileage: 30000,
                                  type: .pneus, tirePosition: .traseiro, motorcycle: moto))
        try ctx.save()

        let tire = moto.maintenanceStatuses(now: day(2026, 6, 18)).filter { $0.type == .pneus }
        XCTAssertEqual(tire.count, 2, "uma linha por posição")
        XCTAssertEqual(Set(tire.map(\.position)), [.dianteiro, .traseiro])
        XCTAssertEqual(Set(tire.map(\.displayName)), ["Pneu dianteiro", "Pneu traseiro"])
        XCTAssertEqual(Set(tire.map(\.id)).count, 2, "ids distintos p/ sheet/ForEach")
        XCTAssertEqual(Set(tire.map(\.identifierKey)).count, 2, "notificações separadas")
    }

    /// Registro de pneu antigo (sem posição) não some: vira sua própria linha.
    func testLegacyTireWithoutPositionStillTracked() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022,
                              country: "Brasil", currentOdometer: 40000)
        ctx.insert(moto)
        ctx.insert(MaintenanceLog(date: day(2026, 1, 1), mileage: 30000,
                                  type: .pneus, motorcycle: moto))  // sem posição
        try ctx.save()

        let tire = moto.maintenanceStatuses(now: day(2026, 6, 18)).filter { $0.type == .pneus }
        XCTAssertEqual(tire.count, 1)
        XCTAssertNil(tire.first?.position)
        XCTAssertEqual(tire.first?.displayName, "Pneus", "sem posição usa o nome do tipo")
    }

    /// Rótulo é a fonte única (tipo + posição). Não-pneu ignora posição.
    func testDisplayNameComposition() {
        XCTAssertEqual(MaintenanceType.displayName(.pneus, position: .dianteiro), "Pneu dianteiro")
        XCTAssertEqual(MaintenanceType.displayName(.pneus, position: .traseiro), "Pneu traseiro")
        XCTAssertEqual(MaintenanceType.displayName(.pneus, position: nil), "Pneus")
        XCTAssertEqual(MaintenanceType.displayName(.oleo, position: .dianteiro), "Troca de óleo")
    }

    /// Revisão que troca só um eixo do pneu reinicia apenas aquele contador.
    func testRevisaoTireSinglePositionResetsOnlyThatAxis() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022,
                              country: "Brasil", currentOdometer: 40000)
        ctx.insert(moto)
        // Ambos os pneus vencidos por km (@ 20000, intervalo 12000).
        ctx.insert(MaintenanceLog(date: day(2025, 6, 1), mileage: 20000,
                                  type: .pneus, tirePosition: .dianteiro, motorcycle: moto))
        ctx.insert(MaintenanceLog(date: day(2025, 6, 1), mileage: 20000,
                                  type: .pneus, tirePosition: .traseiro, motorcycle: moto))
        // Revisão recente que troca só o traseiro (filho @ 39000).
        let parent = MaintenanceLog(date: day(2026, 6, 1), mileage: 39000,
                                    type: .revisao, motorcycle: moto)
        ctx.insert(parent)
        ctx.insert(MaintenanceLog(date: day(2026, 6, 1), mileage: 39000, cost: 0,
                                  type: .pneus, tirePosition: .traseiro,
                                  partOfMaintenanceID: parent.id, motorcycle: moto))
        try ctx.save()

        let front = moto.maintenanceStatus(for: .pneus, position: .dianteiro, now: day(2026, 6, 18))
        let rear = moto.maintenanceStatus(for: .pneus, position: .traseiro, now: day(2026, 6, 18))
        XCTAssertEqual(front?.isOverdue, true, "dianteiro segue vencido")
        XCTAssertEqual(rear?.isOverdue, false, "traseiro reiniciado pela revisão")
    }

    // MARK: - Garagem: recordes (PRs)

    /// Melhor km/l pega o maior segmento; maior trecho idem.
    /// seg1: (1100-1000)/10 = 10 km/l, 100 km. seg2: (1400-1100)/10 = 30 km/l, 300 km.
    func testRecordsBestConsumptionAndLongestSegment() {
        let entries = [entry(1000, 8), entry(1100, 10), entry(1400, 10)]
        let r = ConsumptionCalculator.records(from: entries)
        XCTAssertEqual(r.bestKmPerLiter, 30)
        XCTAssertEqual(r.longestSegment, 300)
    }

    /// Litro mais barato = menor preço/litro; ignora litros 0 (sem divisão por zero).
    func testRecordsCheapestPriceIgnoresZeroLiters() {
        let entries = [
            entry(1000, 10, 60),   // 6,00/L
            entry(1100, 10, 49),   // 4,90/L  ← mais barato
            entry(1200, 0, 0),     // litros 0 → ignorado
        ]
        let r = ConsumptionCalculator.records(from: entries)
        XCTAssertEqual(r.cheapestPricePerLiter, 4.9)
    }

    /// Sem dois cheios medíveis: km/l e trecho nil. Preço/litro ainda sai do único log.
    func testRecordsNilWithoutMeasurableSegment() {
        let r = ConsumptionCalculator.records(from: [entry(1000, 10, 50)])
        XCTAssertNil(r.bestKmPerLiter)
        XCTAssertNil(r.longestSegment)
        XCTAssertEqual(r.cheapestPricePerLiter, 5)
    }

    /// Tudo nil sem nenhum abastecimento.
    func testRecordsAllNilWhenEmpty() {
        let r = ConsumptionCalculator.records(from: [])
        XCTAssertNil(r.bestKmPerLiter)
        XCTAssertNil(r.longestSegment)
        XCTAssertNil(r.cheapestPricePerLiter)
    }

    // MARK: - Garagem: totais vitalícios

    /// Litros/gasto vitalícios somam todos os logs, mesmo parciais (independem de cheio).
    func testLifetimeTotalsSumAllLogsIncludingPartials() {
        let moto = Motorcycle(make: "Honda", model: "CB", year: 2024, country: "BR")
        moto.fuelLogs = [
            FuelLog(date: day(2026, 1, 1), odometer: 1000, liters: 10, totalCost: 50,
                    fuelType: .gasolinaComum, isFullTank: true),
            FuelLog(date: day(2026, 1, 5), odometer: 1100, liters: 5, totalCost: 25,
                    fuelType: .gasolinaComum, isFullTank: false),
        ]
        XCTAssertEqual(moto.totalLitersEver, 15)
        XCTAssertEqual(moto.totalCostEver, 75)
        XCTAssertEqual(moto.fuelLogCount, 2)
    }

    // MARK: - Garagem: agregados da FROTA

    /// Recordes da frota = o extremo entre as motos, não a soma. Moto A tem o
    /// melhor km/l e maior trecho; moto B tem o litro mais barato.
    func testFleetRecordsTakeExtremesAcrossBikes() {
        // Moto A: seg (1400-1100)/10 = 30 km/l, 300 km; litro a 6,00.
        let a = Motorcycle(make: "Honda", model: "CB", year: 2024, country: "BR")
        a.fuelLogs = [
            FuelLog(odometer: 1000, liters: 8, totalCost: 48, fuelType: .gasolinaComum, isFullTank: true),
            FuelLog(odometer: 1100, liters: 10, totalCost: 60, fuelType: .gasolinaComum, isFullTank: true),
            FuelLog(odometer: 1400, liters: 10, totalCost: 60, fuelType: .gasolinaComum, isFullTank: true),
        ]
        // Moto B: seg (2100-2000)/10 = 10 km/l, 100 km; litro a 4,90 (mais barato).
        let b = Motorcycle(make: "Yamaha", model: "MT", year: 2024, country: "BR")
        b.fuelLogs = [
            FuelLog(odometer: 2000, liters: 10, totalCost: 49, fuelType: .gasolinaComum, isFullTank: true),
            FuelLog(odometer: 2100, liters: 10, totalCost: 49, fuelType: .gasolinaComum, isFullTank: true),
        ]
        let r = [a, b].fleetRecords
        XCTAssertEqual(r.bestKmPerLiter, 30)            // melhor da frota (moto A)
        XCTAssertEqual(r.longestSegment, 300)           // maior trecho (moto A)
        XCTAssertEqual(r.cheapestPricePerLiter, 4.9)    // mais barato (moto B)
    }

    /// Totais somam as duas motos; abastecimentos/litros/gasto incluem parciais.
    func testFleetTotalsSumAllBikes() {
        let a = Motorcycle(make: "Honda", model: "CB", year: 2024, country: "BR")
        a.fuelLogs = [
            FuelLog(odometer: 1000, liters: 10, totalCost: 60, fuelType: .gasolinaComum, isFullTank: true),
            FuelLog(odometer: 1100, liters: 10, totalCost: 60, fuelType: .gasolinaComum, isFullTank: true),
        ]
        let b = Motorcycle(make: "Yamaha", model: "MT", year: 2024, country: "BR")
        b.fuelLogs = [
            FuelLog(odometer: 2000, liters: 5, totalCost: 25, fuelType: .gasolinaComum, isFullTank: false),
        ]
        let fleet = [a, b]
        XCTAssertEqual(fleet.fleetFuelLogCount, 3)
        XCTAssertEqual(fleet.fleetTotalLitersEver, 25)
        XCTAssertEqual(fleet.fleetTotalCostEver, 145)
        // Só A tem segmento medível: 100 km / 10 L.
        XCTAssertEqual(fleet.fleetSummary.totalDistance, 100)
    }

    /// Média da frota sai do POOL (Σdist ÷ Σlitros), nunca média das médias.
    /// Moto A: 200 km / 5 L = 40 km/l. Moto B: 100 km / 20 L = 5 km/l.
    /// Média-das-médias daria (40+5)/2 = 22,5 (errado).
    /// Pool: 300 km / 25 L = 12 km/l (certo).
    func testFleetAverageIsPooledNotMeanOfMeans() {
        let a = Motorcycle(make: "Honda", model: "CB", year: 2024, country: "BR")
        a.fuelLogs = [
            FuelLog(odometer: 1000, liters: 5, totalCost: 30, fuelType: .gasolinaComum, isFullTank: true),
            FuelLog(odometer: 1200, liters: 5, totalCost: 30, fuelType: .gasolinaComum, isFullTank: true),
        ]
        let b = Motorcycle(make: "Yamaha", model: "MT", year: 2024, country: "BR")
        b.fuelLogs = [
            FuelLog(odometer: 2000, liters: 20, totalCost: 120, fuelType: .gasolinaComum, isFullTank: true),
            FuelLog(odometer: 2100, liters: 20, totalCost: 120, fuelType: .gasolinaComum, isFullTank: true),
        ]
        let summary = [a, b].fleetSummary
        XCTAssertEqual(summary.totalDistance, 300)
        XCTAssertEqual(summary.totalLitersInSegments, 25)
        XCTAssertEqual(summary.averageKmPerLiter, 12)               // pool, não 22,5
        XCTAssertEqual(summary.costPerKm.map { ($0 * 100).rounded() }, 50)  // 150/300 = 0,50/km
    }

    /// Garagem vazia → tudo nil/zero, sem crash.
    func testFleetAggregatesEmpty() {
        let fleet: [Motorcycle] = []
        XCTAssertNil(fleet.fleetRecords.bestKmPerLiter)
        XCTAssertNil(fleet.fleetSummary.averageKmPerLiter)
        XCTAssertEqual(fleet.fleetFuelLogCount, 0)
        XCTAssertEqual(fleet.fleetTotalCostEver, 0)
    }

    // MARK: - Soft Revision (Fase 1 — updated_at / revision / deleted_at)

    /// Criar não incrementa revisão; updatedAt = createdAt.
    func testSoftRevision_createStartsAtZero() {
        let created = DateComponents(calendar: .current, year: 2026, month: 1, day: 1).date!
        let log = FuelLog(odometer: 100, liters: 10, totalCost: 60,
                          fuelType: .gasolinaComum, createdAt: created)
        XCTAssertEqual(log.revision, 0)
        XCTAssertNil(log.deletedAt)
        XCTAssertEqual(log.updatedAt, created, "updatedAt nasce igual a createdAt")
    }

    /// markUpdated incrementa revisão e avança updatedAt.
    func testSoftRevision_editBumpsRevisionAndTimestamp() {
        let created = DateComponents(calendar: .current, year: 2026, month: 1, day: 1).date!
        let log = FuelLog(odometer: 100, liters: 10, totalCost: 60,
                          fuelType: .gasolinaComum, createdAt: created)
        let editAt = created.addingTimeInterval(3600)
        log.markUpdated(now: editAt)
        XCTAssertEqual(log.revision, 1)
        XCTAssertEqual(log.updatedAt, editAt)
        log.markUpdated(now: editAt.addingTimeInterval(60))
        XCTAssertEqual(log.revision, 2)
    }

    /// softDelete carimba deletedAt e updatedAt; é idempotente.
    func testSoftRevision_softDeleteIsIdempotent() {
        let log = FuelLog(odometer: 100, liters: 10, totalCost: 60, fuelType: .gasolinaComum)
        let at = DateComponents(calendar: .current, year: 2026, month: 2, day: 1).date!
        log.softDelete(now: at)
        XCTAssertEqual(log.deletedAt, at)
        XCTAssertEqual(log.updatedAt, at)
        // Segunda chamada não re-carimba (não sobrescreve deletedAt).
        log.softDelete(now: at.addingTimeInterval(9999))
        XCTAssertEqual(log.deletedAt, at, "idempotente — mantém o 1º carimbo")
    }

    /// activeFuelLogs exclui os soft-deletados; fuelLogs cru os mantém.
    func testActiveFuelLogs_excludesSoftDeleted() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022, country: "Brasil")
        ctx.insert(moto)
        let a = FuelLog(odometer: 100, liters: 10, totalCost: 60, fuelType: .gasolinaComum, motorcycle: moto)
        let b = FuelLog(odometer: 400, liters: 10, totalCost: 60, fuelType: .gasolinaComum, motorcycle: moto)
        ctx.insert(a); ctx.insert(b)
        try ctx.save()
        XCTAssertEqual(moto.activeFuelLogs.count, 2)

        b.softDelete()
        try ctx.save()
        XCTAssertEqual(moto.activeFuelLogs.count, 1, "o deletado some da leitura")
        XCTAssertEqual(moto.fuelLogs.count, 2, "mas persiste no array cru (p/ o sync)")
        XCTAssertEqual(moto.activeFuelLogs.first?.odometer, 100)
    }

    /// Soft-deletar o abastecimento mais recente recua o hodômetro (como o
    /// delete físico antigo) — reconcileOdometer usa activeFuelLogs.
    func testSoftDelete_newestRecalculatesOdometer() throws {
        let ctx = try makeContext()
        let moto = try motoWithLogs(baseline: 1000, odometers: [1200, 1500, 1800], in: ctx)
        XCTAssertEqual(moto.currentOdometer, 1800)

        let newest = moto.activeFuelLogs.max { $0.odometer < $1.odometer }!
        newest.softDelete()
        moto.reconcileOdometer()
        try ctx.save()
        XCTAssertEqual(moto.currentOdometer, 1500, "cai para o próximo maior VIVO")
    }

    /// Consumo ignora abastecimentos soft-deletados (usa activeFuelLogs).
    func testConsumption_ignoresSoftDeleted() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022, country: "Brasil")
        ctx.insert(moto)
        // Dois cheios: 1000→1300 (300 km) com 20 L no 2º = 15 km/l. createdAt =
        // data do evento (registrados na hora — senão viram histórico e saem do consumo).
        let d1 = DateComponents(calendar: .current, year: 2026, month: 1, day: 1).date!
        let d2 = DateComponents(calendar: .current, year: 2026, month: 1, day: 5).date!
        let d3 = DateComponents(calendar: .current, year: 2026, month: 1, day: 9).date!
        ctx.insert(FuelLog(date: d1, odometer: 1000, liters: 10, totalCost: 60, fuelType: .gasolinaComum, isFullTank: true, motorcycle: moto, createdAt: d1))
        ctx.insert(FuelLog(date: d2, odometer: 1300, liters: 20, totalCost: 120, fuelType: .gasolinaComum, isFullTank: true, motorcycle: moto, createdAt: d2))
        // Terceiro cheio (será deletado) — não deve entrar na média.
        let bogus = FuelLog(date: d3, odometer: 9999, liters: 5, totalCost: 30, fuelType: .gasolinaComum, isFullTank: true, motorcycle: moto, createdAt: d3)
        ctx.insert(bogus)
        try ctx.save()

        bogus.softDelete()
        try ctx.save()
        let avg = moto.consumptionSummary.averageKmPerLiter
        XCTAssertEqual(avg ?? 0, 15, accuracy: 0.01, "300 km ÷ 20 L; o log deletado é ignorado")
    }

    /// children filtra filhos soft-deletados de uma Revisão Geral.
    func testChildren_excludesSoftDeleted() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022, country: "Brasil")
        ctx.insert(moto)
        let parent = MaintenanceLog(mileage: 5000, type: .revisao, motorcycle: moto)
        ctx.insert(parent)
        let child1 = MaintenanceLog(mileage: 5000, type: .oleo, partOfMaintenanceID: parent.id, motorcycle: moto)
        let child2 = MaintenanceLog(mileage: 5000, type: .filtros, partOfMaintenanceID: parent.id, motorcycle: moto)
        ctx.insert(child1); ctx.insert(child2)
        try ctx.save()
        XCTAssertEqual(parent.children.count, 2)

        child2.softDelete()
        try ctx.save()
        XCTAssertEqual(parent.children.count, 1, "filho deletado some")
        XCTAssertEqual(parent.children.first?.type, .oleo)
    }

    /// Manutenção soft-deletada não conta para lastService / statuses.
    func testMaintenanceSchedule_ignoresSoftDeleted() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022, country: "Brasil", currentOdometer: 6000)
        ctx.insert(moto)
        let oil = MaintenanceLog(mileage: 5000, type: .oleo, motorcycle: moto)
        ctx.insert(oil)
        try ctx.save()
        XCTAssertNotNil(moto.lastService(of: .oleo))

        oil.softDelete()
        try ctx.save()
        XCTAssertNil(moto.lastService(of: .oleo), "manutenção deletada não é a última")
    }

    // MARK: - Registro retroativo (histórico vs na hora — PLAN/registro-retroativo.md)

    /// Abastecimento com data/createdAt explícitos (createdAt depois de `ruleStart`).
    private func fuelLog(_ odo: Double, _ liters: Double, date: Date, created: Date,
                         full: Bool = true) -> FuelLog {
        FuelLog(date: date, odometer: odo, liters: liters, totalCost: liters * 6,
                fuelType: .gasolinaComum, isFullTank: full, createdAt: created)
    }

    /// Limite em dias de calendário: 7 dias depois ainda é na hora; 8 é histórico.
    func testProvenance_boundaryInCalendarDays() {
        let created = day(2026, 10, 20)
        XCTAssertFalse(EventProvenance.isHistorical(date: day(2026, 10, 13), createdAt: created), "7 dias = na hora")
        XCTAssertTrue(EventProvenance.isHistorical(date: day(2026, 10, 12), createdAt: created), "8 dias = histórico")
        XCTAssertFalse(EventProvenance.isHistorical(date: created, createdAt: created))
    }

    /// Horário dentro do dia não muda a classificação (compara dias, não segundos).
    func testProvenance_timeOfDayIgnored() {
        let cal = Calendar.current
        let created = cal.date(bySettingHour: 23, minute: 55, second: 0, of: day(2026, 10, 20))!
        let date = cal.date(bySettingHour: 0, minute: 5, second: 0, of: day(2026, 10, 13))!
        XCTAssertFalse(EventProvenance.isHistorical(date: date, createdAt: created),
                       "7 dias de calendário, mesmo com ~8×24h de diferença")
    }

    /// Registro criado antes da regra existir nunca é histórico (regra vale daqui
    /// pra frente; `createdAt` antigo não é confiável).
    func testProvenance_beforeRuleStartNeverHistorical() {
        let created = EventProvenance.ruleStart.addingTimeInterval(-60)
        XCTAssertFalse(EventProvenance.isHistorical(date: day(2020, 1, 1), createdAt: created))
        XCTAssertTrue(EventProvenance.isHistorical(date: day(2020, 1, 1),
                                                   createdAt: EventProvenance.ruleStart))
    }

    /// Passado da moto (histórico ANTES do 1º registro na hora) fica fora do
    /// consumo: o buraco 15.000→20.000 inventaria ~450 km/l.
    func testConsumption_excludesHistoryBeforeLiveEra() {
        let moto = Motorcycle(make: "Honda", model: "CG", year: 2020, country: "Brasil")
        moto.fuelLogs = [
            fuelLog(15_000, 10, date: day(2026, 3, 1), created: day(2026, 10, 20)),   // histórico
            fuelLog(20_000, 11, date: day(2026, 10, 1), created: day(2026, 10, 1)),   // na hora
            fuelLog(20_400, 10, date: day(2026, 10, 10), created: day(2026, 10, 10)), // na hora
        ]
        XCTAssertEqual(moto.consumptionFuelLogs.count, 2)
        let summary = moto.consumptionSummary
        XCTAssertEqual(summary.segmentCount, 1)
        XCTAssertEqual(summary.averageKmPerLiter ?? 0, 40, accuracy: 0.001)
        XCTAssertEqual(moto.records.bestKmPerLiter ?? 0, 40, accuracy: 0.001, "recorde ignora o passado")
    }

    /// Histórico INTERCALADO (abastecimento real lançado com atraso) fica dentro:
    /// tirá-lo abriria buraco no trecho e inflaria o km/l dos registros na hora.
    func testConsumption_keepsInterleavedHistory() {
        let moto = Motorcycle(make: "Honda", model: "CG", year: 2020, country: "Brasil")
        let late = fuelLog(20_400, 10, date: day(2026, 10, 5), created: day(2026, 10, 20))  // lançado 15 dias depois
        moto.fuelLogs = [
            fuelLog(20_000, 10, date: day(2026, 10, 1), created: day(2026, 10, 1)),
            late,
            fuelLog(20_800, 10, date: day(2026, 10, 19), created: day(2026, 10, 19)),
        ]
        XCTAssertTrue(late.isHistorical)
        XCTAssertEqual(moto.consumptionFuelLogs.count, 3)
        XCTAssertEqual(moto.consumptionSummary.segmentCount, 2)
        XCTAssertEqual(moto.consumptionSummary.averageKmPerLiter ?? 0, 40, accuracy: 0.001)
    }

    /// Só histórico → nada de consumo (e faltam 2 cheios na hora para o 1º km/l).
    func testConsumption_onlyHistoryIsEmpty() {
        let moto = Motorcycle(make: "Honda", model: "CG", year: 2020, country: "Brasil")
        moto.fuelLogs = [
            fuelLog(10_000, 10, date: day(2026, 1, 1), created: day(2026, 10, 20)),
            fuelLog(10_400, 10, date: day(2026, 1, 10), created: day(2026, 10, 20)),
        ]
        XCTAssertTrue(moto.consumptionFuelLogs.isEmpty)
        XCTAssertEqual(moto.consumptionSummary.segmentCount, 0)
        XCTAssertNil(moto.records.bestKmPerLiter)
        XCTAssertEqual(moto.fullTanksUntilConsumption, 2)
        XCTAssertEqual(moto.fuelLogCount, 2, "histórico continua na lista e nos totais")
    }

    /// Sem histórico nenhum, o consumo é idêntico ao de antes da regra.
    func testConsumption_withoutHistoryUnchanged() {
        let moto = Motorcycle(make: "Honda", model: "CG", year: 2020, country: "Brasil")
        moto.fuelLogs = [
            fuelLog(1_000, 8, date: day(2026, 10, 1), created: day(2026, 10, 1)),
            fuelLog(1_300, 10, date: day(2026, 10, 5), created: day(2026, 10, 5)),
            fuelLog(1_500, 5, date: day(2026, 10, 7), created: day(2026, 10, 7), full: false),
            fuelLog(1_800, 5, date: day(2026, 10, 9), created: day(2026, 10, 9)),
        ]
        let before = ConsumptionCalculator.summary(from: moto.activeFuelLogs.map(\.asFuelEntry))
        XCTAssertEqual(moto.consumptionSummary, before)
    }

    /// Conquistas: manutenção e cheios HISTÓRICOS não contam; os na hora sim.
    func testBadgeContext_ignoresHistory() {
        let moto = Motorcycle(make: "Honda", model: "CG", year: 2020, country: "Brasil")
        moto.maintenanceLogs = [
            MaintenanceLog(date: day(2025, 6, 1), mileage: 8_000, type: .oleo, createdAt: day(2026, 10, 20)),
        ]
        moto.fuelLogs = [
            fuelLog(9_000, 10, date: day(2025, 7, 1), created: day(2026, 10, 20)),
            fuelLog(10_000, 10, date: day(2026, 10, 18), created: day(2026, 10, 18)),
        ]
        var ctx = [moto].badgeFleetContext
        XCTAssertFalse(ctx.hasMaintenanceLog, "só manutenção histórica → não conta")
        XCTAssertEqual(ctx.fullTankCount, 1, "cheio histórico não conta")

        moto.maintenanceLogs.append(
            MaintenanceLog(date: day(2026, 10, 19), mileage: 10_100, type: .oleo, createdAt: day(2026, 10, 19)))
        ctx = [moto].badgeFleetContext
        XCTAssertTrue(ctx.hasMaintenanceLog, "manutenção na hora conta")
    }

    /// Convite de histórico: moto rodada (≥ 1.000 km na 1ª leitura) sem histórico.
    func testHistoryInvite_looksUsedAndHistory() {
        let zero = Motorcycle(make: "Honda", model: "CG", year: 2026, country: "Brasil")
        XCTAssertFalse(zero.looksUsed, "moto zero sem leitura")
        let used = Motorcycle(make: "Honda", model: "CG", year: 2020, country: "Brasil",
                              currentOdometer: 25_000)
        used.odometerBaseline = 25_000
        XCTAssertTrue(used.looksUsed)
        XCTAssertFalse(used.hasHistoricalRecords)
        used.maintenanceLogs = [
            MaintenanceLog(date: day(2025, 6, 1), mileage: 20_000, type: .pneus, createdAt: day(2026, 10, 20)),
        ]
        XCTAssertTrue(used.hasHistoricalRecords, "1º histórico registrado → convite some")
    }

    // MARK: - Abastecimento antigo — limites do hodômetro por data

    private let boundsLogs: [(date: Date, odometer: Double)] = [
        (DateComponents(calendar: .current, year: 2026, month: 3, day: 1).date!, 10_000),
        (DateComponents(calendar: .current, year: 2026, month: 5, day: 1).date!, 12_000),
        (DateComponents(calendar: .current, year: 2026, month: 10, day: 10).date!, 15_000),
    ]

    /// Caso de todo dia (hoje, depois do último): piso global de sempre, sem teto.
    func testBounds_notBackdatedKeepsGlobalFloor() {
        let b = OdometerBounds.forEntry(on: day(2026, 10, 12), logs: boundsLogs,
                                        currentOdometer: 15_200, now: day(2026, 10, 12))
        XCTAssertFalse(b.isBackdated)
        XCTAssertEqual(b.floor, 15_200, "inclui a leitura do cadastro/hodômetro atual")
        XCTAssertNil(b.ceiling)
    }

    /// Entre dois abastecimentos: piso = anterior, teto = seguinte.
    func testBounds_betweenTwoLogs() {
        let b = OdometerBounds.forEntry(on: day(2026, 4, 1), logs: boundsLogs,
                                        currentOdometer: 15_200, now: day(2026, 10, 12))
        XCTAssertTrue(b.isBackdated)
        XCTAssertEqual(b.floor, 10_000)
        XCTAssertEqual(b.ceiling, 12_000)
        XCTAssertEqual(b.floorDate, boundsLogs[0].date)
        XCTAssertEqual(b.ceilingDate, boundsLogs[1].date)
    }

    /// Antes do 1º abastecimento: sem piso, teto = 1º log.
    func testBounds_beforeFirstLog() {
        let b = OdometerBounds.forEntry(on: day(2025, 12, 1), logs: boundsLogs,
                                        currentOdometer: 15_200, now: day(2026, 10, 12))
        XCTAssertNil(b.floor)
        XCTAssertEqual(b.ceiling, 10_000)
    }

    /// Só a leitura do cadastro (sem logs): data antiga não tem limites — a
    /// leitura não tem data.
    func testBounds_onlyBaselineHasNoLimits() {
        let b = OdometerBounds.forEntry(on: day(2025, 6, 1), logs: [],
                                        currentOdometer: 25_000, now: day(2026, 10, 12))
        XCTAssertTrue(b.isBackdated)
        XCTAssertNil(b.floor)
        XCTAssertNil(b.ceiling)
    }

    /// Log do mesmo dia não entra nos limites (não dá para ordenar dentro do dia).
    func testBounds_sameDayLogIgnored() {
        let b = OdometerBounds.forEntry(on: day(2026, 5, 1), logs: boundsLogs,
                                        currentOdometer: 15_200, now: day(2026, 10, 12))
        XCTAssertEqual(b.floor, 10_000, "o log de 01/05 (12.000) não vira piso")
        XCTAssertEqual(b.ceiling, 15_000)
    }

    /// Antes do cadastro da moto conta como retroativo mesmo sem logs posteriores.
    func testBounds_beforeRegistrationIsBackdated() {
        let b = OdometerBounds.forEntry(on: day(2026, 10, 8), logs: [],
                                        currentOdometer: 25_000,
                                        registeredAt: day(2026, 10, 10), now: day(2026, 10, 12))
        XCTAssertTrue(b.isBackdated)
        XCTAssertNil(b.floor, "leitura do cadastro não vale para antes do cadastro")
    }

    // MARK: - Manutenção antiga — aviso de km incoerente (não bloqueia)

    private func maintenanceIssue(
        on date: Date, km: Double, logs: [(date: Date, odometer: Double)], current: Double
    ) -> OdometerIssue? {
        OdometerBounds.forEntry(on: date, logs: logs, currentOdometer: current, now: day(2026, 10, 12))
            .maintenanceIssue(km: km, currentOdometer: current)
    }

    /// Caso da dúvida: troca antiga a 1.000 numa moto em 10.000 é coerente — o
    /// vencimento conta os 9.000 rodados, sem aviso.
    func testMaintenanceIssue_oldLowKmIsFine() {
        XCTAssertNil(maintenanceIssue(on: day(2024, 6, 1), km: 1_000, logs: [], current: 10_000))
    }

    /// Typo: 100.000 numa moto em 10.000 → passado maior que o presente.
    func testMaintenanceIssue_aboveCurrent() {
        XCTAssertEqual(maintenanceIssue(on: day(2024, 6, 1), km: 100_000, logs: [], current: 10_000),
                       .aboveCurrent(km: 10_000))
    }

    /// Menor que um abastecimento de data anterior.
    func testMaintenanceIssue_belowEarlierLog() {
        XCTAssertEqual(maintenanceIssue(on: day(2026, 4, 1), km: 1_000, logs: boundsLogs, current: 15_200),
                       .belowEarlier(km: 10_000, date: boundsLogs[0].date))
    }

    /// Maior que um abastecimento de data posterior.
    func testMaintenanceIssue_aboveLaterLog() {
        XCTAssertEqual(maintenanceIssue(on: day(2026, 4, 1), km: 13_000, logs: boundsLogs, current: 15_200),
                       .aboveLater(km: 12_000, date: boundsLogs[1].date))
        XCTAssertNil(maintenanceIssue(on: day(2026, 4, 1), km: 11_000, logs: boundsLogs, current: 15_200),
                     "entre os vizinhos = coerente")
    }

    /// Na hora não avisa: acima = a moto andou; abaixo = mesmo dia do abastecimento.
    func testMaintenanceIssue_notBackdatedNeverWarns() {
        XCTAssertNil(maintenanceIssue(on: day(2026, 10, 12), km: 16_000, logs: boundsLogs, current: 15_200))
        XCTAssertNil(maintenanceIssue(on: day(2026, 10, 12), km: 15_100, logs: boundsLogs, current: 15_200))
    }

    /// Teto bloqueia: hodômetro não anda para trás.
    func testValidationRejectsAboveNext() {
        let errors = FuelLogValidator.validate(odometer: 12_500, liters: 10, totalCost: 60,
                                               lastOdometer: 10_000, nextOdometer: 12_000)
        XCTAssertEqual(errors, [.odometerAboveNext(next: 12_000)])
        XCTAssertEqual(errors.first?.analyticsKey, "odometer_above_next")
        XCTAssertTrue(FuelLogValidator.validate(odometer: 11_000, liters: 10, totalCost: 60,
                                                lastOdometer: 10_000, nextOdometer: 12_000).isEmpty)
    }

    // MARK: - Edição da moto preserva a leitura de referência

    /// Editar nome/ano sem mexer no hodômetro não regrava a baseline (antes,
    /// toda edição fazia baseline = currentOdometer e zerava o km das medalhas).
    func testEditedOdometerUnchangedKeepsBaseline() throws {
        let ctx = try makeContext()
        let moto = try motoWithLogs(baseline: 1000, odometers: [1500, 3000], in: ctx)
        XCTAssertEqual(moto.distanceSinceBaseline, 2000)
        moto.applyEditedOdometer(3000, loaded: 3000)
        XCTAssertEqual(moto.odometerBaseline, 1000, "campo intocado → baseline intacta")
        XCTAssertEqual(moto.distanceSinceBaseline, 2000)
    }

    /// Mudar o hodômetro no form regrava a baseline e reconcilia (nunca abaixo
    /// dos abastecimentos).
    func testEditedOdometerChangedUpdatesBaseline() throws {
        let ctx = try makeContext()
        let moto = try motoWithLogs(baseline: 1000, odometers: [1500, 3000], in: ctx)
        moto.applyEditedOdometer(800, loaded: 3000)
        XCTAssertEqual(moto.odometerBaseline, 800)
        XCTAssertEqual(moto.currentOdometer, 3000, "não cai abaixo do maior abastecimento")
        moto.applyEditedOdometer(4000, loaded: 3000)
        XCTAssertEqual(moto.currentOdometer, 4000)
    }

    /// Item desmarcado de uma Revisão vira exclusão LÓGICA: some de `children`
    /// e do cálculo, mas a linha fica para o sync propagar o `deleted_at` (delete
    /// físico nunca chegava ao servidor e o pull o ressuscitava).
    func testRevisaoChildSoftDeleteLeavesRowForSync() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022, country: "Brasil", currentOdometer: 6000)
        ctx.insert(moto)
        let parent = MaintenanceLog(mileage: 5000, type: .revisao, motorcycle: moto)
        ctx.insert(parent)
        let oil = MaintenanceLog(mileage: 5000, type: .oleo, partOfMaintenanceID: parent.id, motorcycle: moto)
        ctx.insert(oil)
        try ctx.save()
        XCTAssertEqual(parent.children.count, 1)

        oil.softDelete()
        try ctx.save()
        XCTAssertTrue(parent.children.isEmpty, "desmarcado some da revisão")
        XCTAssertNil(moto.lastService(of: .oleo), "e não reinicia o contador do óleo")
        XCTAssertEqual(moto.maintenanceLogs.count, 2, "a linha continua para o sync propagar")
    }
}
