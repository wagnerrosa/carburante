//
//  BadgeAwardTests.swift
//  CarburanteTests
//
//  Reconciliação da data de conquista (estilo Garmin). Estado unlock continua
//  no motor puro `BadgeEvaluator`; aqui testa só o carimbo: cria 1x, idempotente,
//  não reescreve data antiga, mapa id→data.
//

import XCTest
import SwiftData
@testable import Carburante

@MainActor
final class BadgeAwardTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: BadgeAward.self, configurations: config)
        return ModelContext(container)
    }

    private func awards(in ctx: ModelContext) -> [BadgeAward] {
        (try? ctx.fetch(FetchDescriptor<BadgeAward>())) ?? []
    }

    func testReconcileCreatesAwardsForUnlockedIDs() throws {
        let ctx = try makeContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let didInsert = BadgeAward.reconcile(unlockedIDs: ["make_honda", "fuel_1"], now: now, in: ctx)
        XCTAssertTrue(didInsert)
        let all = awards(in: ctx)
        XCTAssertEqual(Set(all.map(\.badgeID)), ["make_honda", "fuel_1"])
        XCTAssertTrue(all.allSatisfy { $0.earnedAt == now })
    }

    func testReconcileIsIdempotent() throws {
        let ctx = try makeContext()
        let t1 = Date(timeIntervalSince1970: 1_700_000_000)
        BadgeAward.reconcile(unlockedIDs: ["make_honda"], now: t1, in: ctx)
        // Mesma chamada de novo (data mais nova) não duplica nem reescreve.
        let t2 = Date(timeIntervalSince1970: 1_800_000_000)
        let didInsert = BadgeAward.reconcile(unlockedIDs: ["make_honda"], now: t2, in: ctx)
        XCTAssertFalse(didInsert)
        let all = awards(in: ctx)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.earnedAt, t1, "Data original preservada")
    }

    func testReconcileAddsOnlyNewIDs() throws {
        let ctx = try makeContext()
        let t1 = Date(timeIntervalSince1970: 1_700_000_000)
        BadgeAward.reconcile(unlockedIDs: ["make_honda"], now: t1, in: ctx)
        let t2 = Date(timeIntervalSince1970: 1_800_000_000)
        let didInsert = BadgeAward.reconcile(unlockedIDs: ["make_honda", "fuel_1"], now: t2, in: ctx)
        XCTAssertTrue(didInsert)
        let byID = Dictionary(awards(in: ctx).map { ($0.badgeID, $0.earnedAt) }, uniquingKeysWith: min)
        XCTAssertEqual(byID["make_honda"], t1, "Existente mantém data original")
        XCTAssertEqual(byID["fuel_1"], t2, "Novo carimba com 'now'")
    }

    func testReconcileEmptyIsNoOp() throws {
        let ctx = try makeContext()
        let didInsert = BadgeAward.reconcile(unlockedIDs: [], now: Date(), in: ctx)
        XCTAssertFalse(didInsert)
        XCTAssertTrue(awards(in: ctx).isEmpty)
    }

    func testEarnedDatesMap() throws {
        let ctx = try makeContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        BadgeAward.reconcile(unlockedIDs: ["make_honda", "fuel_1"], now: now, in: ctx)
        let map = BadgeAward.earnedDates(in: ctx)
        XCTAssertEqual(map["make_honda"], now)
        XCTAssertEqual(map["fuel_1"], now)
        XCTAssertNil(map["nonexistent"])
    }
}
