//
//  LocalWipeTests.swift
//  CarburanteTests
//
//  Sair e apagar conta limpam o aparelho (`SyncService.eraseLocalData`). Store
//  em disco, como no app: o delete em lote falhava só ali (134050, "mandatory
//  OTO nullify inverse on FuelLog/motorcycle") e não apagava nada.
//

import XCTest
import SwiftData
@testable import Carburante

@MainActor
final class LocalWipeTests: XCTestCase {

    private var storeDir: URL!

    override func tearDown() {
        if let storeDir { try? FileManager.default.removeItem(at: storeDir) }
        super.tearDown()
    }

    private func makeOnDiskContext() throws -> ModelContext {
        storeDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        let schema = Schema([Motorcycle.self, FuelLog.self, MaintenanceLog.self,
                             BadgeAward.self, MotorcycleOwnership.self])
        let config = ModelConfiguration(schema: schema, url: storeDir.appendingPathComponent("wipe.store"))
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    func testEraseRemovesEveryModelFromDiskStore() throws {
        let ctx = try makeOnDiskContext()
        let moto = Motorcycle(make: "Honda", model: "CB 500F", year: 2022, country: "Brasil")
        ctx.insert(moto)
        for i in 0..<3 {
            ctx.insert(FuelLog(odometer: Double(1000 + i * 100), liters: 10, totalCost: 60,
                               fuelType: .gasolinaComum, motorcycle: moto))
        }
        ctx.insert(MaintenanceLog(mileage: 1100, type: .oleo, motorcycle: moto))
        ctx.insert(FuelLog(odometer: 500, liters: 8, totalCost: 48, fuelType: .gasolinaComum))  // órfão
        ctx.insert(BadgeAward(badgeID: "first_fuel", earnedAt: Date()))
        ctx.insert(MotorcycleOwnership(motorcycleID: moto.id, userID: UUID()))
        try ctx.save()
        // Como nas telas: relacionamentos já carregados na memória.
        XCTAssertEqual(moto.fuelLogs.count, 3)
        XCTAssertEqual(moto.maintenanceLogs.count, 1)

        try SyncService.eraseLocalData(in: ctx)

        // Contexto novo: lê o que ficou gravado no disco, não a memória.
        let disk = ModelContext(ctx.container)
        XCTAssertEqual(try disk.fetchCount(FetchDescriptor<Motorcycle>()), 0)
        XCTAssertEqual(try disk.fetchCount(FetchDescriptor<FuelLog>()), 0)
        XCTAssertEqual(try disk.fetchCount(FetchDescriptor<MaintenanceLog>()), 0)
        XCTAssertEqual(try disk.fetchCount(FetchDescriptor<BadgeAward>()), 0)
        XCTAssertEqual(try disk.fetchCount(FetchDescriptor<MotorcycleOwnership>()), 0)
    }

    func testEraseOnEmptyStoreIsNoOp() throws {
        let ctx = try makeOnDiskContext()
        XCTAssertNoThrow(try SyncService.eraseLocalData(in: ctx))
    }
}
