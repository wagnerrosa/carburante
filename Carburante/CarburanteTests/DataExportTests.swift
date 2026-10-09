//
//  DataExportTests.swift
//  CarburanteTests
//
//  "Exportar meus dados" (`DataExport`): formato da planilha brasileira,
//  só registros ativos, chave de tipo desconhecida preservada.
//

import XCTest
import SwiftData
@testable import Carburante

@MainActor
final class DataExportTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Motorcycle.self, FuelLog.self, MaintenanceLog.self,
                                           configurations: config)
        return ModelContext(container)
    }

    /// Linhas do CSV sem o BOM e sem a quebra final.
    private func lines(_ csv: String) -> [String] {
        csv.dropFirst().split(separator: "\r\n", omittingEmptySubsequences: true).map(String.init)
    }

    // MARK: - Formato

    func testFieldQuotesOnlyWhenNeeded() {
        XCTAssertEqual(DataExport.field("Honda"), "Honda")
        XCTAssertEqual(DataExport.field("a;b"), "\"a;b\"")
        XCTAssertEqual(DataExport.field("disse \"oi\""), "\"disse \"\"oi\"\"\"")
        XCTAssertEqual(DataExport.field("linha 1\nlinha 2"), "\"linha 1\nlinha 2\"")
    }

    func testNumbersUseCommaWithoutGrouping() {
        XCTAssertEqual(DataExport.number(12.5, max: 3), "12,5")
        XCTAssertEqual(DataExport.number(27434, max: 1), "27434")
        XCTAssertEqual(DataExport.number(1234.5, min: 2, max: 2), "1234,50")
    }

    func testCSVStartsWithBOMAndUsesSemicolonAndCRLF() {
        let csv = DataExport.csv([["A", "B"], ["1", "2"]])
        XCTAssertTrue(csv.hasPrefix("\u{FEFF}A;B\r\n1;2"))
        XCTAssertTrue(csv.hasSuffix("\r\n"))
    }

    // MARK: - Planilhas

    func testFuelLogsExcludeDeletedAndComeInDateOrder() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Harley-Davidson", model: "Iron 883", year: 2020, country: "Brasil")
        ctx.insert(moto)
        let later = FuelLog(date: Date(timeIntervalSince1970: 2_000_000), odometer: 1300, liters: 10,
                            totalCost: 62, fuelType: .gasolinaComum, motorcycle: moto)
        let earlier = FuelLog(date: Date(timeIntervalSince1970: 1_000_000), odometer: 1000, liters: 12.5,
                              totalCost: 75, fuelType: .gasolinaComum, motorcycle: moto)
        let deleted = FuelLog(date: Date(timeIntervalSince1970: 1_500_000), odometer: 1100, liters: 5,
                              totalCost: 30, fuelType: .gasolinaComum, motorcycle: moto)
        for log in [later, earlier, deleted] { ctx.insert(log) }
        deleted.deletedAt = Date()
        try ctx.save()

        let rows = lines(DataExport.fuelLogsCSV([moto]))
        XCTAssertEqual(rows.count, 3)  // cabeçalho + 2 ativos
        XCTAssertTrue(rows[0].hasPrefix("Moto;ID da moto;Data;Hodômetro (km);Litros"))
        XCTAssertTrue(rows[1].hasPrefix("Harley-Davidson Iron 883;\(moto.id.uuidString);"))
        XCTAssertTrue(rows[1].contains(";1000;12,5;75,00;6,000;"))  // km; litros; total; R$/L
        XCTAssertTrue(rows[2].contains(";1300;10;62,00;6,200;"))
    }

    func testUnknownFuelTypeKeyIsExportedRaw() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500F", year: 2022, country: "Brasil")
        ctx.insert(moto)
        let log = FuelLog(odometer: 500, liters: 10, totalCost: 60, fuelType: .gasolinaComum, motorcycle: moto)
        ctx.insert(log)
        log.fuelTypeRaw = "e10_europa"  // chave de um build mais novo
        try ctx.save()

        XCTAssertTrue(DataExport.fuelLogsCSV([moto]).contains(";e10_europa;"))
    }

    func testMaintenanceRowsExcludeDeleted() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Ducati", model: "Monster", year: 2023, country: "Brasil")
        ctx.insert(moto)
        let oil = MaintenanceLog(mileage: 3000, cost: 250, notes: "Motul; 10W40", type: .oleo, motorcycle: moto)
        let gone = MaintenanceLog(mileage: 2000, cost: 90, type: .outro, motorcycle: moto)
        for log in [oil, gone] { ctx.insert(log) }
        gone.deletedAt = Date()
        try ctx.save()

        let rows = lines(DataExport.maintenanceCSV([moto]))
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows[1].contains(";3000;250,00;"))
        XCTAssertTrue(rows[1].contains(";\"Motul; 10W40\";"))  // observação com ; vai entre aspas
    }

    func testFilesAreNamedByTypeAndDay() {
        let day = DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 10, day: 8, hour: 12).date!
        let names = DataExport.files(for: [], date: day).map(\.name)
        XCTAssertEqual(names, ["carburante-motos-2026-10-08.csv",
                               "carburante-abastecimentos-2026-10-08.csv",
                               "carburante-manutencoes-2026-10-08.csv"])
    }
}
