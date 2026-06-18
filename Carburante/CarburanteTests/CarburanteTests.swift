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
}
