//
//  Motorcycle.swift
//  Carburante
//
//  Modelo da moto. Campos `make`/`model`/`year` separados para derivar
//  categoria e comparar consumo real vs. fabricante no futuro (ver PLAN/).
//  `category` e `manufacturerConsumption` ficam nulos no MVP (backfill depois).
//

import Foundation
import SwiftData

@Model
final class Motorcycle {
    /// ID estável (gerado no app) usado como PK no Supabase — casa o sync sem round-trip.
    var id: UUID = UUID()
    var make: String
    var model: String
    var year: Int
    /// País onde a moto foi vendida/registrada — fonte de verdade do catálogo
    /// de specs do modelo. Não confundir com país do usuário ou do abastecimento.
    var country: String
    var currentOdometer: Double
    /// Nulo no MVP — derivado depois de um banco de modelos por país.
    var category: String?
    /// Consumo informado pelo fabricante (km/l). Nulo no MVP — backfill depois.
    var manufacturerConsumption: Double?
    var createdAt: Date

    /// Abastecimentos da moto. Apagar a moto apaga seus abastecimentos.
    @Relationship(deleteRule: .cascade, inverse: \FuelLog.motorcycle)
    var fuelLogs: [FuelLog] = []

    /// Manutenções da moto. Apagar a moto apaga suas manutenções.
    @Relationship(deleteRule: .cascade, inverse: \MaintenanceLog.motorcycle)
    var maintenanceLogs: [MaintenanceLog] = []

    init(
        make: String,
        model: String,
        year: Int,
        country: String,
        currentOdometer: Double = 0,
        category: String? = nil,
        manufacturerConsumption: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.make = make
        self.model = model
        self.year = year
        self.country = country
        self.currentOdometer = currentOdometer
        self.category = category
        self.manufacturerConsumption = manufacturerConsumption
        self.createdAt = createdAt
    }
}

extension Motorcycle {
    /// Rótulo curto para listas/títulos: "Honda CB 500 (2022)".
    var displayName: String {
        "\(make) \(model) (\(year))"
    }
}
