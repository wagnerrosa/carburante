//
//  FuelLog.swift
//  Carburante
//
//  Abastecimento. Relação Motorcycle 1—N FuelLog.
//  Campos de localização e metadados OCR ficam nulos no MVP (Fases 6/7).
//  `temperatureC` nulo no MVP — backfill por API depois (lat/long + data).
//

import Foundation
import SwiftData

/// Tipos de combustível comuns no Brasil. `.rawValue` é persistido (String),
/// não o índice — adicionar casos no futuro não corrompe dados existentes.
enum FuelType: String, CaseIterable, Codable, Identifiable {
    case gasolinaComum = "Gasolina comum"
    case gasolinaAditivada = "Gasolina aditivada"
    case etanol = "Etanol"
    case diesel = "Diesel"
    case gnv = "GNV"

    var id: String { rawValue }
}

@Model
final class FuelLog {
    var date: Date
    var odometer: Double
    var liters: Double
    var totalCost: Double
    /// Persistido como String (rawValue de `FuelType`) via `fuelType`.
    var fuelTypeRaw: String
    /// Encheu o tanque? Consumo só é calculado entre dois abastecimentos
    /// cheios (litros de parciais intermediários são somados). Ver `ConsumptionCalculator`.
    /// Default na declaração permite migração leve de stores antigos.
    var isFullTank: Bool = true

    // Contexto — nulo no MVP (Fase 7 GPS preenche).
    var latitude: Double?
    var longitude: Double?
    var city: String?
    var state: String?
    var country: String?

    /// Nulo no MVP — backfill por API (OpenWeather Time Machine) depois.
    var temperatureC: Double?

    // Metadados OCR — nulo no MVP (Fase 6).
    var receiptImageURL: String?
    var ocrProcessed: Bool
    var ocrConfidence: Double?

    var createdAt: Date

    /// Relação inversa: cada abastecimento pertence a uma moto.
    var motorcycle: Motorcycle?

    init(
        date: Date = Date(),
        odometer: Double,
        liters: Double,
        totalCost: Double,
        fuelType: FuelType,
        isFullTank: Bool = true,
        motorcycle: Motorcycle? = nil,
        ocrProcessed: Bool = false,
        createdAt: Date = Date()
    ) {
        self.date = date
        self.odometer = odometer
        self.liters = liters
        self.totalCost = totalCost
        self.fuelTypeRaw = fuelType.rawValue
        self.isFullTank = isFullTank
        self.motorcycle = motorcycle
        self.ocrProcessed = ocrProcessed
        self.createdAt = createdAt
    }
}

extension FuelLog {
    var fuelType: FuelType {
        get { FuelType(rawValue: fuelTypeRaw) ?? .gasolinaComum }
        set { fuelTypeRaw = newValue.rawValue }
    }

    /// Preço por litro — derivado, não armazenado.
    var pricePerLiter: Double? {
        guard liters > 0 else { return nil }
        return totalCost / liters
    }

    /// Rótulo curto de localização, ex.: "São Paulo, SP". nil se não capturado.
    var placeLabel: String? {
        let parts = [city, state].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
