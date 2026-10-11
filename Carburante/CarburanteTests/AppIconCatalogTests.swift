//
//  AppIconCatalogTests.swift
//  CarburanteTests
//
//  Ícones de conquista (`AppIconCatalog`): que medalha libera qual ícone, e
//  que o catálogo bate com os ícones que o build compilou.
//

import XCTest
@testable import Carburante

@MainActor
final class AppIconCatalogTests: XCTestCase {

    func testDefaultComesFirstThenOneIconPerArt() {
        XCTAssertEqual(AppIconCatalog.options.first, AppIconCatalog.defaultOption)
        XCTAssertEqual(AppIconCatalog.options.count, AppIconCatalog.arts.count + 1)
        XCTAssertEqual(Set(AppIconCatalog.arts).count, AppIconCatalog.arts.count)
    }

    func testEveryIconArtBelongsToARealNonBrandBadge() {
        let badgeArts = Set(Badge.all.filter { !$0.usesBrandLogo }.map(\.assetName))
        for art in AppIconCatalog.arts {
            XCTAssertTrue(badgeArts.contains(art), "\(art) não é arte de nenhuma medalha")
        }
        XCTAssertFalse(AppIconCatalog.arts.contains("ironButt"))  // "em breve"
        XCTAssertFalse(AppIconCatalog.arts.contains("firstBike"))  // nenhuma medalha usa
    }

    func testCatalogMatchesTheIconsTheBuildCompiled() throws {
        let icons = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any])
        let alternates = try XCTUnwrap(icons["CFBundleAlternateIcons"] as? [String: Any])
        XCTAssertEqual(Set(alternates.keys), Set(AppIconCatalog.arts.map(AppIconCatalog.iconName(for:))))
    }

    func testUnlockedBadgesFreeTheirArtButBrandLogosDont() {
        let brand = Badge.all.first { $0.usesBrandLogo }
        var ids: Set<String> = ["fuel_1", "cat_trail_2"]
        if let brand { ids.insert(brand.id) }
        let arts = AppIconCatalog.unlockedArts(unlockedBadgeIDs: ids)
        XCTAssertEqual(arts, ["firstFuel", "trail"])

        let trail = try! XCTUnwrap(AppIconCatalog.option(forArt: "trail"))
        XCTAssertTrue(AppIconCatalog.isUnlocked(trail, unlockedArts: arts))
        let sport = try! XCTUnwrap(AppIconCatalog.option(forArt: "sport"))
        XCTAssertFalse(AppIconCatalog.isUnlocked(sport, unlockedArts: arts))
        XCTAssertTrue(AppIconCatalog.isUnlocked(AppIconCatalog.defaultOption, unlockedArts: []))
    }

    func testTitlesAndLookups() {
        XCTAssertEqual(AppIconCatalog.title(for: "piston"), "Clube de cilindrada")
        XCTAssertEqual(AppIconCatalog.title(for: "firstFuel"), "1º Abastecimento")
        XCTAssertEqual(AppIconCatalog.option(forIconName: "conquista-sport").art, "sport")
        XCTAssertEqual(AppIconCatalog.option(forIconName: "algo-que-sumiu"), AppIconCatalog.defaultOption)
        XCTAssertNil(AppIconCatalog.option(forArt: "ironButt"))
    }
}
