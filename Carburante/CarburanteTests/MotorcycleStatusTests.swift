//
//  MotorcycleStatusTests.swift
//  CarburanteTests
//
//  Situação da moto (na garagem / à venda / vendida): carimbo da mudança,
//  chave desconhecida preservada, filtro da garagem e last-write-wins do sync.
//

import XCTest
import SwiftData
@testable import Carburante

@MainActor
final class MotorcycleStatusTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Motorcycle.self, FuelLog.self, MaintenanceLog.self,
                                           configurations: config)
        return ModelContext(container)
    }

    func testNewBikeIsInTheGarageWithoutDate() {
        let moto = Motorcycle(make: "Honda", model: "CB 500F", year: 2022, country: "Brasil")
        XCTAssertEqual(moto.status, .active)
        XCTAssertNil(moto.status.label)  // na garagem não tem rótulo
        XCTAssertNil(moto.statusChangedAt)
    }

    func testSetStatusStampsDateAndIgnoresSameStatus() {
        let moto = Motorcycle(make: "Honda", model: "CB 500F", year: 2022, country: "Brasil")
        let first = Date(timeIntervalSince1970: 1_800_000_000)
        moto.setStatus(.forSale, now: first)
        XCTAssertEqual(moto.statusRaw, "for_sale")
        XCTAssertEqual(moto.statusChangedAt, first)

        moto.setStatus(.forSale, now: first.addingTimeInterval(60))
        XCTAssertEqual(moto.statusChangedAt, first)  // mesma situação não recarimba
    }

    func testUnknownKeyReadsAsGarageButIsKept() {
        let moto = Motorcycle(make: "Honda", model: "CB 500F", year: 2022, country: "Brasil")
        moto.statusRaw = "lent"  // chave de um build mais novo
        XCTAssertEqual(moto.status, .active)
        XCTAssertFalse(moto.isSold)
        XCTAssertEqual(moto.statusRaw, "lent")
    }

    func testGaragePredicateDropsSoldAndDeleted() throws {
        let ctx = try makeContext()
        let garage = Motorcycle(make: "Honda", model: "NC 750X", year: 2022, country: "Brasil")
        let forSale = Motorcycle(make: "Yamaha", model: "MT-07", year: 2021, country: "Brasil")
        let sold = Motorcycle(make: "Honda", model: "PCX", year: 2020, country: "Brasil")
        let deleted = Motorcycle(make: "Suzuki", model: "V-Strom", year: 2019, country: "Brasil")
        for m in [garage, forSale, sold, deleted] { ctx.insert(m) }
        forSale.setStatus(.forSale)
        sold.setStatus(.sold)
        deleted.softDelete()
        try ctx.save()

        let inGarage = try ctx.fetch(FetchDescriptor<Motorcycle>(predicate: Motorcycle.garagePredicate))
        XCTAssertEqual(Set(inGarage.map(\.model)), ["NC 750X", "MT-07"])
        let alive = try ctx.fetch(FetchDescriptor<Motorcycle>(predicate: Motorcycle.activePredicate))
        XCTAssertEqual(alive.count, 3)  // a Garagem ainda vê a vendida (vitalício)
    }

    // MARK: - Sync (last-write-wins por status_changed_at)

    private let t = Date(timeIntervalSince1970: 1_800_000_000)

    func testRemoteWithoutDateNeverWins() {
        XCTAssertFalse(SyncService.remoteStatusWins(localAt: nil, remoteAt: nil))
        XCTAssertFalse(SyncService.remoteStatusWins(localAt: t, remoteAt: nil))
    }

    func testRemoteWinsOverLocalThatNeverChanged() {
        XCTAssertTrue(SyncService.remoteStatusWins(localAt: nil, remoteAt: t))
    }

    func testNewerSideWins() {
        XCTAssertTrue(SyncService.remoteStatusWins(localAt: t, remoteAt: t.addingTimeInterval(3_600)))
        XCTAssertFalse(SyncService.remoteStatusWins(localAt: t.addingTimeInterval(3_600), remoteAt: t))
        XCTAssertFalse(SyncService.remoteStatusWins(localAt: t, remoteAt: t.addingTimeInterval(0.5)))
    }
}
