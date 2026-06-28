//
//  BadgeTests.swift
//  CarburanteTests
//
//  Regras de unlock + visibilidade das medalhas (motor puro `BadgeEvaluator` —
//  ver Badge.swift). Testa o contexto da frota, sem SwiftData.
//

import XCTest
@testable import Carburante

final class BadgeTests: XCTestCase {

    private func ctx(
        hasBike: Bool = true,
        maintenance: Bool = false,
        fullTanks: Int = 0,
        beatsCategory: Bool = false,
        present: Set<MotorcycleCategory> = [],
        km: [MotorcycleCategory: Double] = [:]
    ) -> BadgeFleetContext {
        BadgeFleetContext(
            hasMotorcycle: hasBike,
            hasMaintenanceLog: maintenance,
            fullTankCount: fullTanks,
            beatsCategoryAverage: beatsCategory,
            presentCategories: present,
            kmByCategory: km
        )
    }

    // MARK: Catálogo

    func testCatalogShape() {
        // Universais: 1 moto + 4 abastecimento + 1 manutenção + 1 melhor consumo = 7.
        // Categorias: 5×3 + 3×1 = 18. Total 25.
        XCTAssertEqual(Badge.universais.count, 7)
        XCTAssertEqual(Badge.categoria.count, 18)
        XCTAssertEqual(Badge.all.count, 25)
    }

    func testBadgeIDsAreUnique() {
        let ids = Badge.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "IDs duplicados")
    }

    func testEveryBadgeHasDetailText() {
        for badge in Badge.all {
            XCTAssertFalse(badge.detail.isEmpty, "\(badge.id) sem texto explicativo")
        }
    }

    func testFuelMilestones() {
        let fuelTanks = Badge.universais.filter { $0.requiredFullTanks > 0 }.map(\.requiredFullTanks).sorted()
        XCTAssertEqual(fuelTanks, [1, 2, 3, 10])
    }

    // MARK: Visibilidade

    func testUniversalsAlwaysVisible() {
        let visible = BadgeEvaluator.visibleBadges(ctx())
        for badge in Badge.universais {
            XCTAssertTrue(visible.contains(badge), "\(badge.id) deveria estar sempre visível")
        }
    }

    func testUntouchedCategoryHidden() {
        let visible = BadgeEvaluator.visibleBadges(ctx(present: [.scooter]))
        let trailVisible = visible.contains { if case .categoria(.trail) = $0.group { return true }; return false }
        XCTAssertFalse(trailVisible)
    }

    func testTouchedCategoryShowsAllLevels() {
        let visible = BadgeEvaluator.visibleBadges(ctx(present: [.scooter]))
        let ids = Set(visible.compactMap { b -> String? in
            if case .categoria(.scooter) = b.group { return b.id }; return nil
        })
        XCTAssertEqual(ids, ["cat_scooter_1", "cat_scooter_2", "cat_scooter_3"])
    }

    // MARK: Unlock — primeira moto / manutenção

    func testFirstBike() {
        XCTAssertTrue(BadgeEvaluator.unlockedIDs(ctx()).contains("first_bike"))
        XCTAssertFalse(BadgeEvaluator.unlockedIDs(ctx(hasBike: false)).contains("first_bike"))
    }

    func testFirstMaintenance() {
        XCTAssertTrue(BadgeEvaluator.unlockedIDs(ctx(maintenance: true)).contains("first_maintenance"))
        XCTAssertFalse(BadgeEvaluator.unlockedIDs(ctx()).contains("first_maintenance"))
    }

    // MARK: Unlock — abastecimentos por tanque cheio

    func testFuelMilestonesUnlockByFullTankCount() {
        XCTAssertEqual(BadgeEvaluator.unlockedIDs(ctx(fullTanks: 0)).intersection(["fuel_1", "fuel_2", "fuel_3", "fuel_10"]), [])

        let one = BadgeEvaluator.unlockedIDs(ctx(fullTanks: 1))
        XCTAssertTrue(one.contains("fuel_1"))
        XCTAssertFalse(one.contains("fuel_2"))

        let two = BadgeEvaluator.unlockedIDs(ctx(fullTanks: 2))
        XCTAssertTrue(two.isSuperset(of: ["fuel_1", "fuel_2"]))
        XCTAssertFalse(two.contains("fuel_3"))

        let three = BadgeEvaluator.unlockedIDs(ctx(fullTanks: 3))
        XCTAssertTrue(three.isSuperset(of: ["fuel_1", "fuel_2", "fuel_3"]))
        XCTAssertFalse(three.contains("fuel_10"))

        let ten = BadgeEvaluator.unlockedIDs(ctx(fullTanks: 10))
        XCTAssertTrue(ten.isSuperset(of: ["fuel_1", "fuel_2", "fuel_3", "fuel_10"]))
    }

    // MARK: Unlock — melhor consumo vs categoria

    func testBestConsumptionUnlocksOnlyWhenBeatsCategory() {
        XCTAssertFalse(BadgeEvaluator.unlockedIDs(ctx(beatsCategory: false)).contains("best_consumption"))
        XCTAssertTrue(BadgeEvaluator.unlockedIDs(ctx(beatsCategory: true)).contains("best_consumption"))
    }

    // MARK: Unlock — níveis por km

    func testLevelProgressionByKm() {
        let zero = BadgeEvaluator.unlockedIDs(ctx(present: [.scooter], km: [.scooter: 0]))
        XCTAssertEqual(zero.intersection(["cat_scooter_1", "cat_scooter_2", "cat_scooter_3"]), ["cat_scooter_1"])

        let mid = BadgeEvaluator.unlockedIDs(ctx(present: [.scooter], km: [.scooter: 5_000]))
        XCTAssertTrue(mid.isSuperset(of: ["cat_scooter_1", "cat_scooter_2"]))
        XCTAssertFalse(mid.contains("cat_scooter_3"))

        let high = BadgeEvaluator.unlockedIDs(ctx(present: [.sport], km: [.sport: 25_000]))
        XCTAssertTrue(high.isSuperset(of: ["cat_sport_1", "cat_sport_2", "cat_sport_3"]))
    }

    func testKmInOneCategoryDoesNotLeak() {
        let ids = BadgeEvaluator.unlockedIDs(ctx(present: [.scooter], km: [.scooter: 25_000]))
        XCTAssertFalse(ids.contains("cat_sport_1"))
    }

    func testCategoryNotPresentNeverUnlocks() {
        let ids = BadgeEvaluator.unlockedIDs(ctx(present: [], km: [.scooter: 99_999]))
        XCTAssertFalse(ids.contains("cat_scooter_1"))
    }

    func testSingleLevelCategory() {
        XCTAssertTrue(BadgeEvaluator.unlockedIDs(ctx(present: [.touring])).contains("cat_touring_1"))
    }
}
