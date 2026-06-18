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
    let category: String?
    let manufacturer_consumption: Double?
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
    let ocr_processed: Bool
    let ocr_confidence: Double?
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
}
