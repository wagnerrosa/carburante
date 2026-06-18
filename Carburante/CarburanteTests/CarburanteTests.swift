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
        let container = try ModelContainer(for: Motorcycle.self, configurations: config)
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
}
