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
        maintenance: Bool = false,
        fullTanks: Int = 0,
        beatsCategory: Bool = false,
        present: Set<MotorcycleCategory> = [],
        km: [MotorcycleCategory: Double] = [:],
        makes: Set<String> = [],
        ccClubs: Set<Int> = []
    ) -> BadgeFleetContext {
        BadgeFleetContext(
            hasMaintenanceLog: maintenance,
            fullTankCount: fullTanks,
            beatsCategoryAverage: beatsCategory,
            presentCategories: present,
            kmByCategory: km,
            presentMakes: makes,
            presentDisplacementClubs: ccClubs
        )
    }

    // MARK: Catálogo

    func testCatalogShape() {
        // Universais: 4 abastecimento + 1 manutenção + 1 melhor consumo + 1 Iron Butt = 7.
        // Marca: 10 (catálogo com logo). Cilindrada: 5 clubes.
        // Categorias: 5×3 + 3×1 = 18. Total 40.
        XCTAssertEqual(Badge.universais.count, 7)
        XCTAssertEqual(Badge.marca.count, 10)
        XCTAssertEqual(Badge.cilindrada.count, 5)
        XCTAssertEqual(Badge.categoria.count, 18)
        XCTAssertEqual(Badge.all.count, 40)
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

    func testNoFirstBikeBadge() {
        XCTAssertFalse(Badge.all.contains { $0.id == "first_bike" },
                       "'Primeira moto' foi substituído pelos badges de marca")
    }

    func testFuelMilestones() {
        let fuelTanks = Badge.universais.filter { $0.requiredFullTanks > 0 }.map(\.requiredFullTanks).sorted()
        XCTAssertEqual(fuelTanks, [1, 2, 3, 10])
    }

    func testMarcaBadgesUseBrandLogo() {
        for badge in Badge.marca {
            XCTAssertTrue(badge.usesBrandLogo, "\(badge.id) deveria usar o logo da marca")
            XCTAssertTrue(badge.assetName.hasPrefix("BrandLogos/"), "\(badge.id) com asset errado")
        }
    }

    // MARK: Iron Butt (modalidade futura)

    func testIronButtIsComingSoonAndAlwaysVisible() {
        let iron = Badge.all.first { $0.id == "iron_butt" }
        XCTAssertNotNil(iron)
        XCTAssertTrue(iron?.isComingSoon ?? false, "Iron Butt deveria ser 'em breve'")
        XCTAssertEqual(iron?.assetName, "ironButt")
        // Sempre visível (universal) mesmo sem nenhuma moto.
        XCTAssertTrue(BadgeEvaluator.visibleBadges(ctx()).contains { $0.id == "iron_butt" })
    }

    func testIronButtIsLastVisible() {
        // Com frota variada, Iron Butt fecha a grade (canto inferior direito).
        let c = ctx(present: [.scooter], makes: ["honda"], ccClubs: [125])
        XCTAssertEqual(BadgeEvaluator.visibleBadges(c).last?.id, "iron_butt")
        // E também quando só os universais aparecem (zero motos).
        XCTAssertEqual(BadgeEvaluator.visibleBadges(ctx()).last?.id, "iron_butt")
    }

    func testIronButtNeverUnlocks() {
        // Mesmo com a frota toda "no máximo", Iron Butt nunca entra nos unlocked.
        let c = ctx(maintenance: true, fullTanks: 99, beatsCategory: true,
                    present: [.sport], km: [.sport: 999_999])
        XCTAssertFalse(BadgeEvaluator.unlockedIDs(c).contains("iron_butt"),
                       "Iron Butt é modalidade futura — nunca desbloqueia ainda")
    }

    func testOnlyIronButtIsComingSoon() {
        XCTAssertEqual(Badge.all.filter(\.isComingSoon).map(\.id), ["iron_butt"])
    }

    // MARK: Níveis (número na medalha)

    func testMultiLevelCategoriesCarryLevelInfo() {
        // As 5 famílias de 3 níveis têm levelCount==3 e level 1/2/3 distintos.
        let families = ["scooter", "trail", "custom", "street", "sport"]
        for fam in families {
            let levels = Badge.categoria
                .filter { $0.id.hasPrefix("cat_\(fam)_") }
                .sorted { $0.level < $1.level }
            XCTAssertEqual(levels.map(\.level), [1, 2, 3], "\(fam) níveis errados")
            XCTAssertTrue(levels.allSatisfy { $0.levelCount == 3 }, "\(fam) levelCount errado")
        }
    }

    func testSingleLevelCategoriesHaveNoLevelNumber() {
        // touring/offroad/other têm nível único → levelCount==1 (sem número na UI).
        for id in ["cat_touring_1", "cat_offroad_1", "cat_other_1"] {
            let badge = Badge.categoria.first { $0.id == id }
            XCTAssertEqual(badge?.levelCount, 1, "\(id) não deveria mostrar número")
        }
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

    // MARK: Marca

    func testMakeBadgeVisibleAndUnlockedWhenPresent() {
        let c = ctx(makes: ["honda"])
        XCTAssertTrue(BadgeEvaluator.visibleBadges(c).contains { $0.id == "make_honda" })
        XCTAssertTrue(BadgeEvaluator.unlockedIDs(c).contains("make_honda"))
    }

    func testMakeBadgeHiddenWhenAbsent() {
        let c = ctx(makes: ["honda"])
        XCTAssertFalse(BadgeEvaluator.visibleBadges(c).contains { $0.id == "make_yamaha" })
        XCTAssertFalse(BadgeEvaluator.unlockedIDs(c).contains("make_yamaha"))
    }

    // MARK: Cilindrada — clube por faixa exclusiva

    func testDisplacementClubBoundaries() {
        XCTAssertNil(DisplacementClub.club(forCC: 0))
        XCTAssertEqual(DisplacementClub.club(forCC: 125), 125)
        XCTAssertEqual(DisplacementClub.club(forCC: 180), 125)
        XCTAssertEqual(DisplacementClub.club(forCC: 181), 250)
        XCTAssertEqual(DisplacementClub.club(forCC: 350), 250)
        XCTAssertEqual(DisplacementClub.club(forCC: 351), 500)
        XCTAssertEqual(DisplacementClub.club(forCC: 650), 500)
        XCTAssertEqual(DisplacementClub.club(forCC: 651), 800)
        XCTAssertEqual(DisplacementClub.club(forCC: 900), 800)
        XCTAssertEqual(DisplacementClub.club(forCC: 901), 1000)
        XCTAssertEqual(DisplacementClub.club(forCC: 1000), 1000)
        XCTAssertEqual(DisplacementClub.club(forCC: 1800), 1000, "Harley 1800 entra no clube dos litrões")
    }

    func testDisplacementClubExclusiveVisibilityAndUnlock() {
        // Faixa exclusiva: só o clube presente aparece + desbloqueia.
        let c = ctx(ccClubs: [500])
        let visible = Set(BadgeEvaluator.visibleBadges(c).compactMap { b -> String? in
            if case .cilindrada = b.group { return b.id }; return nil
        })
        XCTAssertEqual(visible, ["cc_500"])
        let unlocked = BadgeEvaluator.unlockedIDs(c)
        XCTAssertTrue(unlocked.contains("cc_500"))
        XCTAssertFalse(unlocked.contains("cc_250"))
        XCTAssertFalse(unlocked.contains("cc_1000"))
    }

    // MARK: Unlock — manutenção

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
