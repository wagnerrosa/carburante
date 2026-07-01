//
//  MotorcycleOwnershipTests.swift
//  CarburanteTests
//
//  Propriedade moto↔usuário como entidade à parte. Cobre o invariante do MVP
//  (exatamente uma linha ATIVA por moto) e o backfill idempotente que migra
//  motos anteriores à feature. Ver `MotorcycleOwnership`.
//

import XCTest
import SwiftData
@testable import Carburante

@MainActor
final class MotorcycleOwnershipTests: XCTestCase {

    /// Container in-memory com os tipos usados por estes testes.
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Motorcycle.self, MotorcycleOwnership.self, configurations: config
        )
        return ModelContext(container)
    }

    // MARK: - Init / invariante isActive

    func testInitActiveWhenNoEndDate() {
        let o = MotorcycleOwnership(motorcycleID: UUID(), userID: UUID())
        XCTAssertNil(o.endedAt)
        XCTAssertTrue(o.isActive)
    }

    func testInitInactiveWhenEndDatePresent() {
        let o = MotorcycleOwnership(
            motorcycleID: UUID(), userID: UUID(),
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 100)
        )
        XCTAssertNotNil(o.endedAt)
        XCTAssertFalse(o.isActive)
    }

    func testEndClosesOwnership() {
        let o = MotorcycleOwnership(motorcycleID: UUID(), userID: UUID())
        o.end(at: Date(timeIntervalSince1970: 50))
        XCTAssertFalse(o.isActive)
        XCTAssertEqual(o.endedAt, Date(timeIntervalSince1970: 50))
    }

    // MARK: - Backfill

    func testBackfillCreatesOneActiveRowPerBike() throws {
        let ctx = try makeContext()
        let uid = UUID()
        let created = Date(timeIntervalSince1970: 1000)
        let moto = Motorcycle(make: "Honda", model: "CB 500F", year: 2022, country: "Brasil", createdAt: created)
        ctx.insert(moto)
        try ctx.save()

        let didCreate = MotorcycleOwnership.backfillActive(for: [moto], userID: uid, in: ctx)
        try ctx.save()

        XCTAssertTrue(didCreate)
        let rows = try ctx.fetch(FetchDescriptor<MotorcycleOwnership>())
        XCTAssertEqual(rows.count, 1)
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.motorcycleID, moto.id)
        XCTAssertEqual(row.userID, uid)
        XCTAssertNil(row.endedAt)
        XCTAssertTrue(row.isActive)
        // startedAt = createdAt da moto (melhor verdade de quando a posse começou).
        XCTAssertEqual(row.startedAt, created)
    }

    func testBackfillIsIdempotent() throws {
        let ctx = try makeContext()
        let uid = UUID()
        let moto = Motorcycle(make: "Yamaha", model: "MT-07", year: 2021, country: "Brasil")
        ctx.insert(moto)
        try ctx.save()

        XCTAssertTrue(MotorcycleOwnership.backfillActive(for: [moto], userID: uid, in: ctx))
        try ctx.save()
        // 2ª passada: moto já tem linha ativa → nada a criar.
        XCTAssertFalse(MotorcycleOwnership.backfillActive(for: [moto], userID: uid, in: ctx))
        try ctx.save()

        let rows = try ctx.fetch(FetchDescriptor<MotorcycleOwnership>())
        XCTAssertEqual(rows.count, 1, "backfill não deve duplicar a linha ativa")
    }

    func testBackfillSkipsBikeWithActiveButFillsOthers() throws {
        let ctx = try makeContext()
        let uid = UUID()
        let motoA = Motorcycle(make: "Honda", model: "CB 500F", year: 2022, country: "Brasil")
        let motoB = Motorcycle(make: "Kawasaki", model: "Z400", year: 2023, country: "Brasil")
        ctx.insert(motoA); ctx.insert(motoB)
        // motoA já tem uma linha ativa pré-existente.
        ctx.insert(MotorcycleOwnership(motorcycleID: motoA.id, userID: uid))
        try ctx.save()

        let didCreate = MotorcycleOwnership.backfillActive(for: [motoA, motoB], userID: uid, in: ctx)
        try ctx.save()

        XCTAssertTrue(didCreate)
        let rows = try ctx.fetch(FetchDescriptor<MotorcycleOwnership>())
        XCTAssertEqual(rows.count, 2, "só a motoB ganha linha nova")
        let activeForA = rows.filter { $0.motorcycleID == motoA.id && $0.endedAt == nil }
        let activeForB = rows.filter { $0.motorcycleID == motoB.id && $0.endedAt == nil }
        XCTAssertEqual(activeForA.count, 1)
        XCTAssertEqual(activeForB.count, 1)
    }

    /// Uma moto vendida (linha fechada) e sem linha ativa deve receber uma nova
    /// no backfill — o histórico antigo (endedAt != nil) permanece intacto.
    func testBackfillFillsBikeWhoseOnlyOwnershipIsClosed() throws {
        let ctx = try makeContext()
        let uid = UUID()
        let moto = Motorcycle(make: "Suzuki", model: "GSX-S750", year: 2020, country: "Brasil")
        ctx.insert(moto)
        let closed = MotorcycleOwnership(
            motorcycleID: moto.id, userID: UUID(),
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 100)
        )
        ctx.insert(closed)
        try ctx.save()

        XCTAssertTrue(MotorcycleOwnership.backfillActive(for: [moto], userID: uid, in: ctx))
        try ctx.save()

        let rows = try ctx.fetch(FetchDescriptor<MotorcycleOwnership>())
        XCTAssertEqual(rows.count, 2, "linha fechada preservada + nova ativa")
        XCTAssertEqual(rows.filter { $0.endedAt == nil }.count, 1)
        XCTAssertEqual(rows.filter { $0.endedAt != nil }.count, 1)
    }

    func testBackfillNoBikesIsNoop() throws {
        let ctx = try makeContext()
        XCTAssertFalse(MotorcycleOwnership.backfillActive(for: [], userID: UUID(), in: ctx))
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<MotorcycleOwnership>()).count, 0)
    }
}
