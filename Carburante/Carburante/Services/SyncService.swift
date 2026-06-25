//
//  SyncService.swift
//  Carburante
//
//  Camada de sincronização (offline-first). SwiftData continua sendo a fonte
//  local; este serviço garante uma sessão anônima do Supabase (dá o user_id)
//  e faz push (upsert) dos dados locais para o Postgres, respeitando RLS.
//
//  MVP: push-only (local → remoto). Pull/merge bidirecional é backlog — exigiria
//  resolução de conflito. O teste de aceitação da Fase 9 é justamente "os dados
//  gravam no Supabase com user_id correto e o RLS isola por usuário".
//

import Foundation
import SwiftData
import Supabase

@MainActor
@Observable
final class SyncService {
    static let shared = SyncService()

    let client: SupabaseClient
    private(set) var userID: UUID?
    private(set) var lastError: String?
    private(set) var isSyncing = false

    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.publishableKey
        )
    }

    /// Garante uma sessão (anônima se ainda não houver). Retorna o user_id.
    @discardableResult
    func ensureSession() async -> UUID? {
        if let session = try? await client.auth.session {
            userID = session.user.id
            return userID
        }
        do {
            let session = try await client.auth.signInAnonymously()
            userID = session.user.id
            return userID
        } catch {
            lastError = "Falha ao autenticar: \(error.localizedDescription)"
            Analytics.syncFailed(stage: "auth", errorCode: Self.errorCode(error))
            return nil
        }
    }

    /// Classe do erro para analytics — NUNCA a mensagem crua (pode conter
    /// user_id, URL, payload). Erros do Supabase/Postgrest expõem um código.
    static func errorCode(_ error: Error) -> String {
        let ns = error as NSError
        return "\(ns.domain)#\(ns.code)"
    }

    /// Faz push de todas as motos do usuário (e seus filhos) para o Supabase.
    func pushAll(from context: ModelContext) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        guard let uid = await ensureSession() else { return }

        do {
            let motorcycles = try context.fetch(FetchDescriptor<Motorcycle>())

            let motoDTOs = motorcycles.map { m in
                MotorcycleDTO(
                    id: m.id, user_id: uid, make: m.make, model: m.model, year: m.year,
                    country: m.country, current_odometer: m.currentOdometer,
                    odometer_baseline: m.odometerBaseline,
                    category: m.category, displacement_cc: m.displacementCC,
                    manufacturer_consumption: m.manufacturerConsumption
                )
            }
            if !motoDTOs.isEmpty {
                try await client.from("motorcycles").upsert(motoDTOs).execute()
            }

            let fuelDTOs = motorcycles.flatMap { m in
                m.fuelLogs.map { f in
                    FuelLogDTO(
                        id: f.id, motorcycle_id: m.id, user_id: uid, date: f.date,
                        odometer: f.odometer, liters: f.liters, total_cost: f.totalCost,
                        fuel_type: f.fuelTypeRaw, is_full_tank: f.isFullTank,
                        latitude: f.latitude, longitude: f.longitude, city: f.city,
                        state: f.state, country: f.country, temperature_c: f.temperatureC,
                        receipt_image_url: f.receiptImageURL, odometer_photo_url: f.odometerPhotoURL,
                        ocr_processed: f.ocrProcessed, ocr_confidence: f.ocrConfidence,
                        date_was_edited: f.dateWasEdited, location_was_edited: f.locationWasEdited
                    )
                }
            }
            if !fuelDTOs.isEmpty {
                try await client.from("fuel_logs").upsert(fuelDTOs).execute()
            }

            let maintDTOs = motorcycles.flatMap { m in
                m.maintenanceLogs.map { mt in
                    MaintenanceLogDTO(
                        id: mt.id, motorcycle_id: m.id, user_id: uid, type: mt.typeRaw,
                        date: mt.date, mileage: mt.mileage, cost: mt.cost, notes: mt.notes,
                        interval_km: mt.intervalKm, interval_months: mt.intervalMonths,
                        part_of_maintenance_id: mt.partOfMaintenanceID
                    )
                }
            }
            if !maintDTOs.isEmpty {
                try await client.from("maintenance_logs").upsert(maintDTOs).execute()
            }

            lastError = nil
        } catch {
            lastError = "Falha ao sincronizar: \(error.localizedDescription)"
            Analytics.syncFailed(stage: "push", errorCode: Self.errorCode(error))
        }
    }
}
