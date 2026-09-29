//
//  SyncDTOs.swift
//  Carburante
//
//  DTOs Codable que espelham as tabelas do Supabase (snake_case via CodingKeys).
//  Convertem os @Model do SwiftData em payloads para upsert.
//

import Foundation

struct MotorcycleDTO: Codable {
    let id: UUID
    let user_id: UUID
    let make: String
    let model: String
    let year: Int
    let country: String?
    let current_odometer: Double
    let odometer_baseline: Double
    let category: String?
    let displacement_cc: Int?
    let manufacturer_consumption: Double?
    /// Exclusão lógica da moto (nil = viva). nil é omitido no JSON; o upsert em
    /// lote do SDK manda `columns` = união das chaves, então num lote misto as
    /// vivas vão como null e build antigo (sem o campo) nunca toca a coluna.
    var deleted_at: Date? = nil
}

struct FuelLogDTO: Codable {
    let id: UUID
    let motorcycle_id: UUID
    let user_id: UUID
    let date: Date
    let odometer: Double
    let liters: Double
    let total_cost: Double
    let fuel_type: String
    let is_full_tank: Bool
    let latitude: Double?
    let longitude: Double?
    let city: String?
    let state: String?
    let country: String?
    let temperature_c: Double?
    let receipt_image_url: String?
    let odometer_photo_url: String?
    let ocr_processed: Bool
    let ocr_confidence: Double?
    let date_was_edited: Bool
    let location_was_edited: Bool
    // Soft Revision (Fase 1). `deleted_at` propaga a exclusão lógica; `updated_at`
    // é a base do last-write-wins no pull.
    let updated_at: Date
    let revision: Int
    let deleted_at: Date?
    /// Quando o registro entrou no app. Base da regra "histórico vs na hora"
    /// (`EventProvenance`) — sem sincronizar, um reinstall recriava o log com
    /// `Date()` e tudo virava histórico. NÃO-opcional: o upsert em lote manda a
    /// união das chaves, e nil viraria NULL numa coluna NOT NULL. O servidor só
    /// aceita valor MENOR (trigger `keep_earliest_created_at`).
    let created_at: Date
    /// Lacuna antes deste registro (PLAN/lacuna-abastecimento.md). Build antigo
    /// não manda a chave → o upsert não toca a coluna (flag nunca é zerada).
    var missed_previous: Bool = false
}

struct MaintenanceLogDTO: Codable {
    let id: UUID
    let motorcycle_id: UUID
    let user_id: UUID
    let type: String
    let date: Date
    let mileage: Double
    let cost: Double
    let notes: String
    let interval_km: Double?
    let interval_months: Int?
    let part_of_maintenance_id: UUID?
    /// Posição do pneu (rawValue de `TirePosition`) — só p/ logs de pneu; nil no
    /// resto e em registros antigos.
    let tire_position: String?
    // Soft Revision (Fase 1) — mesma tripla do FuelLogDTO.
    let updated_at: Date
    let revision: Int
    let deleted_at: Date?
    /// Ver `FuelLogDTO.created_at`.
    let created_at: Date
}

struct BadgeAwardDTO: Codable {
    let id: UUID
    let user_id: UUID
    let badge_id: String
    let earned_at: Date
}

/// Propriedade moto↔usuário (fonte de verdade de quem é o dono). `ended_at` nulo
/// = linha ativa (dono atual). Ver `MotorcycleOwnership`.
struct MotorcycleOwnershipDTO: Codable {
    let id: UUID
    let motorcycle_id: UUID
    let user_id: UUID
    let started_at: Date
    let ended_at: Date?
    let is_active: Bool
    let created_at: Date
}
