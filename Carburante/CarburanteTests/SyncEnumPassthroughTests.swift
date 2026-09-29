//
//  SyncEnumPassthroughTests.swift
//  CarburanteTests
//
//  Compatibilidade para frente do pull: um build mais novo pode gravar um tipo
//  que este build não conhece (ex.: combustível de outro país). O pull guarda a
//  chave crua — a tela mostra o fallback, mas o push seguinte reenvia a chave
//  original em vez de sobrescrever o Supabase com o fallback.
//

import XCTest
@testable import Carburante

@MainActor
final class SyncEnumPassthroughTests: XCTestCase {

    private let now = Date()

    private func fuelDTO(fuelType: String) -> FuelLogDTO {
        FuelLogDTO(
            id: UUID(), motorcycle_id: UUID(), user_id: UUID(),
            date: now, odometer: 1_000, liters: 10, total_cost: 60,
            fuel_type: fuelType, is_full_tank: true,
            latitude: nil, longitude: nil, city: nil, state: nil, country: nil,
            temperature_c: nil, receipt_image_url: nil, odometer_photo_url: nil,
            ocr_processed: false, ocr_confidence: nil,
            date_was_edited: false, location_was_edited: false,
            updated_at: now, revision: 1, deleted_at: nil, created_at: now
        )
    }

    private func maintDTO(type: String, tirePosition: String?) -> MaintenanceLogDTO {
        MaintenanceLogDTO(
            id: UUID(), motorcycle_id: UUID(), user_id: UUID(),
            type: type, date: now, mileage: 1_000, cost: 0, notes: "",
            interval_km: nil, interval_months: nil, part_of_maintenance_id: nil,
            tire_position: tirePosition,
            updated_at: now, revision: 1, deleted_at: nil, created_at: now
        )
    }

    func testUnknownFuelTypeKeySurvivesPull() {
        let log = FuelLog(odometer: 1_000, liters: 10, totalCost: 60, fuelType: .etanol)
        SyncService.applyFuel(fuelDTO(fuelType: "E10"), to: log)

        XCTAssertEqual(log.fuelTypeRaw, "E10", "chave desconhecida não pode virar o fallback")
        XCTAssertEqual(log.fuelType, .gasolinaComum, "a tela usa o fallback")
    }

    func testKnownFuelTypeKeyStillDecodes() {
        let log = FuelLog(odometer: 1_000, liters: 10, totalCost: 60, fuelType: .gasolinaComum)
        SyncService.applyFuel(fuelDTO(fuelType: FuelType.etanol.rawValue), to: log)

        XCTAssertEqual(log.fuelType, .etanol)
    }

    func testUnknownMaintenanceKeysSurvivePull() {
        let log = MaintenanceLog(mileage: 1_000, type: .oleo)
        SyncService.applyMaint(maintDTO(type: "Embreagem", tirePosition: "Sidecar"), to: log)

        XCTAssertEqual(log.typeRaw, "Embreagem")
        XCTAssertEqual(log.tirePositionRaw, "Sidecar")
        XCTAssertEqual(log.type, .outro, "a tela usa o fallback")
    }

    func testKnownMaintenanceKeysStillDecode() {
        let log = MaintenanceLog(mileage: 1_000, type: .oleo)
        SyncService.applyMaint(
            maintDTO(type: MaintenanceType.pneus.rawValue,
                     tirePosition: TirePosition.traseiro.rawValue),
            to: log
        )

        XCTAssertEqual(log.type, .pneus)
        XCTAssertEqual(log.tirePosition, .traseiro)
    }
}
