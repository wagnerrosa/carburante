//
//  PersistedEnumKeyTests.swift
//  CarburanteTests
//
//  Trava as chaves (`rawValue`) dos enums persistidos em SwiftData, Supabase e
//  PostHog. Renomear uma chave corrompe registros antigos em silêncio (o decode
//  cai no fallback). Se este teste quebrou porque um texto de tela mudou, a
//  mudança vai no `label`, não no `rawValue`.
//

import XCTest
@testable import Carburante

final class PersistedEnumKeyTests: XCTestCase {

    func testFuelTypeKeysAreFrozen() {
        XCTAssertEqual(FuelType.allCases.map(\.rawValue), [
            "Gasolina comum", "Gasolina aditivada", "Etanol", "Diesel", "GNV",
        ])
    }

    func testMaintenanceTypeKeysAreFrozen() {
        XCTAssertEqual(MaintenanceType.allCases.map(\.rawValue), [
            "Troca de óleo", "Filtros", "Pneus", "Relação / corrente", "Freios",
            "Revisão geral", "Outro",
        ])
    }

    func testMotorcycleStatusKeysAreFrozen() {
        XCTAssertEqual(MotorcycleStatus.allCases.map(\.rawValue), ["active", "for_sale", "sold"])
    }

    func testTirePositionKeysAreFrozen() {
        XCTAssertEqual(TirePosition.allCases.map(\.rawValue), ["Dianteiro", "Traseiro"])
    }

    func testMotorcycleCategoryKeysAreFrozen() {
        XCTAssertEqual(MotorcycleCategory.allCases.map(\.rawValue), [
            "street", "scooter", "trail", "sport", "custom", "touring", "offroad", "other",
        ])
    }

    /// Todo caso tem rótulo próprio e não-vazio (o `label` é o que se traduz).
    func testEveryCaseHasALabel() {
        let labels = FuelType.allCases.map(\.label)
            + MaintenanceType.allCases.map(\.label)
            + TirePosition.allCases.map(\.label)
            + MotorcycleCategory.allCases.map(\.label)
        XCTAssertFalse(labels.contains(where: \.isEmpty))
    }

    /// Pneu com posição usa o rótulo da posição; sem posição, o rótulo do tipo.
    func testDisplayNameUsesLabels() {
        XCTAssertEqual(MaintenanceType.displayName(.oleo, position: nil), MaintenanceType.oleo.label)
        XCTAssertEqual(MaintenanceType.displayName(.pneus, position: nil), MaintenanceType.pneus.label)
        XCTAssertEqual(MaintenanceType.displayName(.pneus, position: .traseiro), "Pneu traseiro")
    }
}
