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
        fuel: Bool = false,
        maintenance: Bool = false,
        bestConsumption: Bool = false,
        present: Set<MotorcycleCategory> = [],
        km: [MotorcycleCategory: Double] = [:]
    ) -> BadgeFleetContext {
        BadgeFleetContext(
            hasMotorcycle: hasBike,
            hasFuelLog: fuel,
            hasMaintenanceLog: maintenance,
            hasBestConsumption: bestConsumption,
            presentCategories: present,
            kmByCategory: km
        )
    }

    // MARK: Catálogo

    func testCatalogShape() {
        // 4 primeiros passos + 18 categorias (5×3 níveis + 3×1 nível).
        XCTAssertEqual(Badge.primeirosPassos.count, 4)
        XCTAssertEqual(Badge.categoria.count, 18)
        XCTAssertEqual(Badge.all.count, 22)
    }

    func testBadgeIDsAreUnique() {
        let ids = Badge.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "IDs de badge duplicados")
    }

    func testEveryCategoryHasAtLeastOneBadge() {
        for cat in MotorcycleCategory.allCases {
            let has = Badge.categoria.contains { badge in
                if case .categoria(let c) = badge.group { return c == cat }
                return false
            }
            XCTAssertTrue(has, "Categoria \(cat) sem badge")
        }
    }

    func testLeveledCategoriesHaveThreeBadges() {
        for cat in [MotorcycleCategory.scooter, .trail, .custom, .street, .sport] {
            let count = Badge.categoria.filter {
                if case .categoria(let c) = $0.group { return c == cat }
                return false
            }.count
            XCTAssertEqual(count, 3, "\(cat) deveria ter 3 níveis")
        }
    }

    func testSingleLevelCategoriesHaveOneBadge() {
        for cat in [MotorcycleCategory.touring, .offroad, .other] {
            let count = Badge.categoria.filter {
                if case .categoria(let c) = $0.group { return c == cat }
                return false
            }.count
            XCTAssertEqual(count, 1, "\(cat) deveria ter 1 nível")
        }
    }

    // MARK: Visibilidade

    func testPrimeirosPassosAlwaysVisible() {
        let visible = BadgeEvaluator.visibleBadges(ctx())
        for badge in Badge.primeirosPassos {
            XCTAssertTrue(visible.contains(badge), "\(badge.id) deveria estar visível sempre")
        }
    }

    func testUntouchedCategoryIsHidden() {
        // Só scooter presente → nenhuma badge de trail aparece.
        let visible = BadgeEvaluator.visibleBadges(ctx(present: [.scooter]))
        let trailVisible = visible.contains { badge in
            if case .categoria(.trail) = badge.group { return true }
            return false
        }
        XCTAssertFalse(trailVisible, "Trail nunca cadastrada não deveria aparecer")
    }

    func testTouchedCategoryShowsAllItsLevels() {
        // Scooter presente → vê os 3 níveis dela (mesmo bloqueados).
        let visible = BadgeEvaluator.visibleBadges(ctx(present: [.scooter]))
        let scooterIDs = visible.compactMap { badge -> String? in
            if case .categoria(.scooter) = badge.group { return badge.id }
            return nil
        }
        XCTAssertEqual(Set(scooterIDs), ["cat_scooter_1", "cat_scooter_2", "cat_scooter_3"])
    }

    // MARK: Unlock — primeiros passos

    func testFirstBikeUnlockedWhenFleetNonEmpty() {
        XCTAssertTrue(BadgeEvaluator.unlockedIDs(ctx()).contains("first_bike"))
        XCTAssertFalse(BadgeEvaluator.unlockedIDs(ctx(hasBike: false)).contains("first_bike"))
    }

    func testFirstFuelMaintenanceBest() {
        XCTAssertTrue(BadgeEvaluator.unlockedIDs(ctx(fuel: true)).contains("first_fuel"))
        XCTAssertTrue(BadgeEvaluator.unlockedIDs(ctx(maintenance: true)).contains("first_maintenance"))
        XCTAssertTrue(BadgeEvaluator.unlockedIDs(ctx(bestConsumption: true)).contains("best_consumption"))
        let empty = BadgeEvaluator.unlockedIDs(ctx())
        XCTAssertFalse(empty.contains("first_fuel"))
        XCTAssertFalse(empty.contains("first_maintenance"))
        XCTAssertFalse(empty.contains("best_consumption"))
    }

    // MARK: Unlock — níveis por km

    func testLevelOneUnlocksOnRegistration() {
        // Categoria presente, 0 km → só nível I.
        let ids = BadgeEvaluator.unlockedIDs(ctx(present: [.scooter], km: [.scooter: 0]))
        XCTAssertTrue(ids.contains("cat_scooter_1"))
        XCTAssertFalse(ids.contains("cat_scooter_2"))
        XCTAssertFalse(ids.contains("cat_scooter_3"))
    }

    func testLevelTwoUnlocksAt5000km() {
        let ids = BadgeEvaluator.unlockedIDs(ctx(present: [.scooter], km: [.scooter: 5_000]))
        XCTAssertTrue(ids.contains("cat_scooter_1"))
        XCTAssertTrue(ids.contains("cat_scooter_2"))
        XCTAssertFalse(ids.contains("cat_scooter_3"))
    }

    func testLevelThreeUnlocksAt20000km() {
        let ids = BadgeEvaluator.unlockedIDs(ctx(present: [.sport], km: [.sport: 25_000]))
        XCTAssertTrue(ids.isSuperset(of: ["cat_sport_1", "cat_sport_2", "cat_sport_3"]))
    }

    func testKmInOneCategoryDoesNotUnlockAnother() {
        // 25.000 km de scooter não desbloqueia nada de sport (nem visível).
        let ids = BadgeEvaluator.unlockedIDs(ctx(present: [.scooter], km: [.scooter: 25_000]))
        XCTAssertFalse(ids.contains("cat_sport_1"))
    }

    func testCategoryNotPresentNeverUnlocks() {
        // km registrado mas categoria não marcada como presente → nada.
        let ids = BadgeEvaluator.unlockedIDs(ctx(present: [], km: [.scooter: 99_999]))
        XCTAssertFalse(ids.contains("cat_scooter_1"))
    }

    func testSingleLevelCategoryUnlocksOnRegistration() {
        let ids = BadgeEvaluator.unlockedIDs(ctx(present: [.touring], km: [.touring: 0]))
        XCTAssertTrue(ids.contains("cat_touring_1"))
    }
}
