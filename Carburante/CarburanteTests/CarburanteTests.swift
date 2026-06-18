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
        let container = try ModelContainer(for: Motorcycle.self, FuelLog.self, configurations: config)
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
}
