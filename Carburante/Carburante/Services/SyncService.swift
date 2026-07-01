//
//  SyncService.swift
//  Carburante
//
//  Camada de sincronização (offline-first). SwiftData continua sendo a fonte
//  local; este serviço garante uma sessão anônima do Supabase (dá o user_id)
//  e faz push (upsert) dos dados locais para o Postgres, respeitando RLS.
//
//  Sincronização bidirecional: PUSH (local → remoto, upsert) + PULL (remoto →
//  local, ADITIVO). O pull traz linhas que ainda não existem localmente (dados
//  de outro device do mesmo usuário) e NUNCA sobrescreve uma linha local — assim
//  uma edição offline ainda não enviada nunca é perdida. Convergência: pull
//  insere o que falta, push manda o local; os dois lados acabam iguais. Edição
//  da MESMA linha em dois devices não é resolvida (sem `updated_at` no MVP) —
//  caso raro para um usuário solo; backlog se virar problema real.
//
//  Ordem no launch: ensureSession → pullAll (preenche o que falta) → pushAll
//  (envia o local). FK exige motos antes de fuel/maintenance no pull.
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
    /// Sessão atual é anônima? true até promover via Sign in with Apple. A UI da
    /// conta mostra o botão de login quando anônimo, o estado logado quando não.
    private(set) var isAnonymous = true
    /// E-mail da conta logada (Apple), se houver. Anônimo → nil.
    private(set) var accountEmail: String?

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
            applySession(session)
            return userID
        }
        do {
            let session = try await client.auth.signInAnonymously()
            applySession(session)
            return userID
        } catch {
            lastError = "Falha ao autenticar: \(error.localizedDescription)"
            Analytics.syncFailed(stage: "auth", errorCode: Self.errorCode(error))
            return nil
        }
    }

    /// Reflete o estado da sessão nas propriedades observáveis. `isAnonymous`
    /// vem do flag do usuário (Supabase marca usuários anônimos); um usuário
    /// com identidade Apple vinculada deixa de ser anônimo e ganha e-mail.
    private func applySession(_ session: Session) {
        userID = session.user.id
        isAnonymous = session.user.isAnonymous
        accountEmail = session.user.email
    }

    /// Promove a sessão anônima atual a uma conta Apple, VINCULANDO a identidade
    /// (mantém o mesmo `user_id` → zero migração de dados). Depois puxa o que o
    /// usuário já tinha em outros devices. Recebe o `idToken` da Apple e o nonce
    /// CRU usado para gerá-lo (ver `AppleSignInNonce`).
    @discardableResult
    func linkApple(idToken: String, nonce: String, context: ModelContext?) async -> Bool {
        do {
            let session = try await client.auth.linkIdentityWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
            applySession(session)
            lastError = nil
            // Conta real → traz dados de outros devices do mesmo usuário.
            if let context { await pullAll(into: context) }
            return true
        } catch {
            lastError = "Falha ao entrar com Apple: \(error.localizedDescription)"
            Analytics.syncFailed(stage: "apple_link", errorCode: Self.errorCode(error))
            return false
        }
    }

    /// Sai da conta. Volta a uma sessão anônima nova (user_id diferente) para o
    /// app continuar gravando local→remoto. NÃO apaga dados locais.
    func signOut() async {
        try? await client.auth.signOut()
        userID = nil
        isAnonymous = true
        accountEmail = nil
        await ensureSession()
    }

    /// Classe do erro para analytics — NUNCA a mensagem crua (pode conter
    /// user_id, URL, payload). Erros do Supabase/Postgrest expõem um código.
    static func errorCode(_ error: Error) -> String {
        let ns = error as NSError
        return "\(ns.domain)#\(ns.code)"
    }

    /// Puxa do Supabase as linhas do usuário que ainda NÃO existem localmente e
    /// as insere no SwiftData. Aditivo: linhas locais existentes ficam intactas
    /// (uma edição offline não enviada nunca é sobrescrita). Roda no launch antes
    /// do push. RLS já restringe ao `user_id` da sessão — não filtramos por mão.
    func pullAll(into context: ModelContext) async {
        guard await ensureSession() != nil else { return }

        do {
            // --- Motos primeiro (FK: fuel/maintenance dependem delas) ---
            let remoteMotos: [MotorcycleDTO] = try await client
                .from("motorcycles").select().execute().value
            let localMotos = try context.fetch(FetchDescriptor<Motorcycle>())
            var motoByID = Dictionary(uniqueKeysWithValues: localMotos.map { ($0.id, $0) })

            for dto in remoteMotos where motoByID[dto.id] == nil {
                let moto = Motorcycle(
                    make: dto.make, model: dto.model, year: dto.year,
                    country: dto.country ?? "", currentOdometer: dto.current_odometer,
                    category: dto.category, displacementCC: dto.displacement_cc,
                    manufacturerConsumption: dto.manufacturer_consumption
                )
                moto.id = dto.id
                moto.odometerBaseline = dto.odometer_baseline
                context.insert(moto)
                motoByID[dto.id] = moto
            }

            // --- Abastecimentos ---
            let remoteFuel: [FuelLogDTO] = try await client
                .from("fuel_logs").select().execute().value
            let localFuelIDs = Set(try context.fetch(FetchDescriptor<FuelLog>()).map(\.id))
            for dto in remoteFuel where !localFuelIDs.contains(dto.id) {
                guard let moto = motoByID[dto.motorcycle_id] else { continue }
                let log = FuelLog(
                    date: dto.date, odometer: dto.odometer, liters: dto.liters,
                    totalCost: dto.total_cost,
                    fuelType: FuelType(rawValue: dto.fuel_type) ?? .gasolinaComum,
                    isFullTank: dto.is_full_tank, motorcycle: moto,
                    ocrProcessed: dto.ocr_processed
                )
                log.id = dto.id
                log.latitude = dto.latitude; log.longitude = dto.longitude
                log.city = dto.city; log.state = dto.state; log.country = dto.country
                log.temperatureC = dto.temperature_c
                log.receiptImageURL = dto.receipt_image_url
                log.odometerPhotoURL = dto.odometer_photo_url
                log.ocrConfidence = dto.ocr_confidence
                log.dateWasEdited = dto.date_was_edited
                log.locationWasEdited = dto.location_was_edited
                context.insert(log)
            }

            // --- Manutenções ---
            let remoteMaint: [MaintenanceLogDTO] = try await client
                .from("maintenance_logs").select().execute().value
            let localMaintIDs = Set(try context.fetch(FetchDescriptor<MaintenanceLog>()).map(\.id))
            for dto in remoteMaint where !localMaintIDs.contains(dto.id) {
                guard let moto = motoByID[dto.motorcycle_id] else { continue }
                let log = MaintenanceLog(
                    date: dto.date, mileage: dto.mileage, cost: dto.cost,
                    notes: dto.notes,
                    type: MaintenanceType(rawValue: dto.type) ?? .outro,
                    tirePosition: dto.tire_position.flatMap(TirePosition.init(rawValue:)),
                    intervalKm: dto.interval_km, intervalMonths: dto.interval_months,
                    partOfMaintenanceID: dto.part_of_maintenance_id,
                    motorcycle: moto
                )
                log.id = dto.id
                context.insert(log)
            }

            // --- Badges conquistadas (sem moto; só user_id) ---
            let remoteAwards: [BadgeAwardDTO] = try await client
                .from("badge_awards").select().execute().value
            let localBadgeIDs = Set(try context.fetch(FetchDescriptor<BadgeAward>()).map(\.badgeID))
            for dto in remoteAwards where !localBadgeIDs.contains(dto.badge_id) {
                let award = BadgeAward(badgeID: dto.badge_id, earnedAt: dto.earned_at, id: dto.id)
                context.insert(award)
            }

            // Hodômetro pode ter avançado por dados puxados de outro device.
            for moto in motoByID.values { moto.reconcileOdometer() }

            try context.save()
            lastError = nil
        } catch {
            lastError = "Falha ao baixar dados: \(error.localizedDescription)"
            Analytics.syncFailed(stage: "pull", errorCode: Self.errorCode(error))
        }
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
                        part_of_maintenance_id: mt.partOfMaintenanceID,
                        tire_position: mt.tirePositionRaw
                    )
                }
            }
            if !maintDTOs.isEmpty {
                try await client.from("maintenance_logs").upsert(maintDTOs).execute()
            }

            // Badges conquistadas (data carimbada, estilo Garmin) — não têm moto;
            // pendem só do user_id. Upsert por PK (id estável por award).
            let awards = try context.fetch(FetchDescriptor<BadgeAward>())
            let awardDTOs = awards.map { a in
                BadgeAwardDTO(id: a.id, user_id: uid, badge_id: a.badgeID, earned_at: a.earnedAt)
            }
            if !awardDTOs.isEmpty {
                try await client.from("badge_awards").upsert(awardDTOs).execute()
            }

            lastError = nil
        } catch {
            lastError = "Falha ao sincronizar: \(error.localizedDescription)"
            Analytics.syncFailed(stage: "push", errorCode: Self.errorCode(error))
        }
    }
}
