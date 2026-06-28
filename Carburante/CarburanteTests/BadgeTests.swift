//
//  BadgeTests.swift
//  CarburanteTests
//
//  Regras de unlock das medalhas (motor puro `BadgeEvaluator` — ver Badge.swift).
//  Testa o contexto puro, sem SwiftData, mesmo padrão de ConsumptionTests.
//

import XCTest
@testable import Carburante

final class BadgeTests: XCTestCase {

    /// Contexto base "vazio": só tem a moto cadastrada.
    private func ctx(
        fuel: Bool = false,
        maintenance: Bool = false,
        bestConsumption: Bool = false,
        category: MotorcycleCategory? = nil
    ) -> BadgeUnlockContext {
        BadgeUnlockContext(
            hasMotorcycle: true,
            hasFuelLog: fuel,
            hasMaintenanceLog: maintenance,
            hasBestConsumption: bestConsumption,
            category: category
        )
    }

    // MARK: Catálogo

    func testCatalogHasTwelveBadges() {
        // 1º corte = 4 primeiros passos + 8 categorias.
        XCTAssertEqual(Badge.all.count, 12)
        XCTAssertEqual(Badge.primeirosPassos.count, 4)
        XCTAssertEqual(Badge.categoria.count, 8)
    }

    func testEveryCategoryMapsToExactlyOneBadge() {
        // Garante que o mapa categoria→id cobre todos os casos e bate com o catálogo.
        let catalogIDs = Set(Badge.categoria.map(\.id))
        for category in MotorcycleCategory.allCases {
            XCTAssertTrue(catalogIDs.contains(Badge.id(for: category)),
                          "Categoria \(category) sem badge no catálogo")
        }
    }

    func testBadgeIDsAreUnique() {
        let ids = Badge.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "IDs de badge duplicados")
    }

    // MARK: Primeiros passos

    func testFirstBikeAlwaysUnlockedWhenMotorcycleExists() {
        // Existe a moto (hasMotorcycle = true) → "Primeira moto" sempre conquistada.
        XCTAssertTrue(BadgeEvaluator.unlockedIDs(ctx()).contains("first_bike"))
    }

    func testFirstFuelLocksUntilFuelLog() {
        XCTAssertFalse(BadgeEvaluator.unlockedIDs(ctx(fuel: false)).contains("first_fuel"))
        XCTAssertTrue(BadgeEvaluator.unlockedIDs(ctx(fuel: true)).contains("first_fuel"))
    }

    func testFirstMaintenanceLocksUntilMaintenanceLog() {
        XCTAssertFalse(BadgeEvaluator.unlockedIDs(ctx(maintenance: false)).contains("first_maintenance"))
        XCTAssertTrue(BadgeEvaluator.unlockedIDs(ctx(maintenance: true)).contains("first_maintenance"))
    }

    func testBestConsumptionLocksUntilReadingExists() {
        XCTAssertFalse(BadgeEvaluator.unlockedIDs(ctx(bestConsumption: false)).contains("best_consumption"))
        XCTAssertTrue(BadgeEvaluator.unlockedIDs(ctx(bestConsumption: true)).contains("best_consumption"))
    }

    // MARK: Categoria

    func testCategoryUnlocksOnlyMatchingBadge() {
        let ids = BadgeEvaluator.unlockedIDs(ctx(category: .scooter))
        XCTAssertTrue(ids.contains("cat_scooter"))
        // Nenhuma OUTRA badge de categoria desbloqueada.
        let otherCategoryIDs = Badge.categoria.map(\.id).filter { $0 != "cat_scooter" }
        for id in otherCategoryIDs {
            XCTAssertFalse(ids.contains(id), "\(id) não deveria estar conquistada")
        }
    }

    func testNoCategoryUnlocksNoCategoryBadge() {
        let ids = BadgeEvaluator.unlockedIDs(ctx(category: nil))
        for badge in Badge.categoria {
            XCTAssertFalse(ids.contains(badge.id))
        }
    }

    func testEachCategoryUnlocksItsBadge() {
        for category in MotorcycleCategory.allCases {
            let ids = BadgeEvaluator.unlockedIDs(ctx(category: category))
            XCTAssertTrue(ids.contains(Badge.id(for: category)),
                          "Categoria \(category) não desbloqueou seu badge")
        }
    }

    // MARK: Combinação completa

    func testFullyLoadedContextUnlocksFirstStepsAndOneCategory() {
        let ids = BadgeEvaluator.unlockedIDs(
            ctx(fuel: true, maintenance: true, bestConsumption: true, category: .sport)
        )
        // 4 primeiros passos + 1 categoria = 5.
        XCTAssertEqual(ids.count, 5)
        XCTAssertTrue(ids.isSuperset(of: ["first_bike", "first_fuel", "first_maintenance", "best_consumption", "cat_sport"]))
    }
}
