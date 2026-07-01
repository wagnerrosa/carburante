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
    /// A última sincronização no launch falhou ou estourou o timeout? A UI mostra
    /// um aviso discreto ("modo offline") para o usuário não achar que os dados
    /// subiram quando não subiram. O app continua funcional (offline-first).
    private(set) var syncDegraded = false

    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.publishableKey
        )
    }

    /// Sincronização de launch: pull (aditivo) seguido de push, com um teto de
    /// tempo. Numa rede ruim as requisições do Supabase podem demorar o timeout
    /// padrão do URLSession (~60s), o que congelaria a percepção de "sincronizando"
    /// — aqui limitamos a `timeout` segundos e, se estourar, marcamos degradação e
    /// seguimos (offline-first: os dados locais já estão salvos). Chamado do
    /// RootTabView no launch.
    func syncAtLaunch(into context: ModelContext, timeout: Duration = .seconds(20)) async {
        syncDegraded = false
        let ok = await withTimeout(timeout) { [weak self] in
            guard let self else { return }
            await self.pullAll(into: context)
            await self.pushAll(from: context)
        }
        // Estourou o teto OU alguma etapa registrou erro → estado degradado.
        if !ok || lastError != nil {
            syncDegraded = true
        }
    }

    /// Roda `operation` com um teto de tempo. Retorna true se completou dentro do
    /// prazo, false se estourou (a operação é cancelada). Genérico e sem valor de
    /// retorno — as etapas de sync já gravam o resultado em `lastError`. Tudo
    /// isolado no MainActor (o serviço é @MainActor), então o `ModelContext`
    /// capturado não cruza fronteira de ator — sem @Sendable no closure.
    private func withTimeout(_ timeout: Duration, operation: @escaping () async -> Void) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask { @MainActor in await operation(); return true }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return false
            }
            // Primeiro a terminar decide; cancela o outro.
            let finished = await group.next() ?? false
            group.cancelAll()
            return finished
        }
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
            // O segredo Apple do Supabase (JWT ES256) expira a cada ~6 meses; se
            // estiver vencido/mal configurado o link falha com erro do provedor.
            // Distinguimos isso de rede/credencial para o log ficar acionável e a
            // mensagem ao usuário não sugerir problema no aparelho dele.
            let desc = error.localizedDescription.lowercased()
            let providerConfigIssue =
                desc.contains("provider") || desc.contains("client") ||
                desc.contains("secret") || desc.contains("invalid_grant") ||
                desc.contains("invalid_client") || desc.contains("unauthorized")
            if providerConfigIssue {
                lastError = "Login com Apple indisponível no momento. Tente mais tarde."
                Analytics.syncFailed(stage: "apple_link_provider", errorCode: Self.errorCode(error))
            } else {
                lastError = "Falha ao entrar com Apple: \(error.localizedDescription)"
                Analytics.syncFailed(stage: "apple_link", errorCode: Self.errorCode(error))
            }
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

    /// Apaga permanentemente a conta do usuário e TODOS os seus dados (exigência
    /// da App Store — Guideline 5.1.1(v), para qualquer app com criação de conta).
    /// Chama a função Postgres `delete_current_user()` (SECURITY DEFINER) que
    /// remove a linha do próprio usuário em `auth.users`; o ON DELETE CASCADE das
    /// tabelas apaga motos/abastecimentos/manutenções/badges/ownerships no
    /// servidor. Depois limpa o SwiftData local e volta a uma sessão anônima nova.
    /// Retorna true em sucesso. Ver supabase/schema.sql (delete_current_user).
    @discardableResult
    func deleteAccount(context: ModelContext) async -> Bool {
        guard await ensureSession() != nil else {
            lastError = "Sem sessão para excluir a conta."
            return false
        }
        do {
            try await client.rpc("delete_current_user").execute()
        } catch {
            lastError = "Falha ao excluir a conta: \(error.localizedDescription)"
            Analytics.syncFailed(stage: "delete_account", errorCode: Self.errorCode(error))
            return false
        }
        // Servidor limpo → apaga o espelho local para não ressincronizar dados de
        // uma conta que não existe mais.
        Self.wipeLocalData(context)
        // Encerra a sessão (o usuário no servidor já não existe) e abre uma anônima
        // nova, deixando o app pronto para um recomeço limpo.
        try? await client.auth.signOut()
        userID = nil
        isAnonymous = true
        accountEmail = nil
        await ensureSession()
        lastError = nil
        return true
    }

    /// Remove todas as linhas locais de todos os @Model do app. Usado após excluir
    /// a conta no servidor.
    private static func wipeLocalData(_ context: ModelContext) {
        do {
            try context.delete(model: FuelLog.self)
            try context.delete(model: MaintenanceLog.self)
            try context.delete(model: BadgeAward.self)
            try context.delete(model: MotorcycleOwnership.self)
            try context.delete(model: Motorcycle.self)
            try context.save()
        } catch {
            // Falha ao limpar o local não desfaz a exclusão no servidor; só loga.
            Analytics.syncFailed(stage: "delete_account_local", errorCode: SyncService.errorCode(error))
        }
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
            let localFuel = try context.fetch(FetchDescriptor<FuelLog>())
            let fuelByID = Dictionary(uniqueKeysWithValues: localFuel.map { ($0.id, $0) })
            for dto in remoteFuel {
                if let existing = fuelByID[dto.id] {
                    // Linha já existe local → last-write-wins por `updated_at`:
                    // só a versão remota MAIS NOVA sobrescreve (resolve o gap de
                    // edição/exclusão da mesma linha em dois devices). Empate ou
                    // local mais novo → mantém local (o push envia o local depois).
                    if dto.updated_at > existing.updatedAt {
                        applyFuel(dto, to: existing)
                    }
                    continue
                }
                guard let moto = motoByID[dto.motorcycle_id] else { continue }
                let log = FuelLog(
                    date: dto.date, odometer: dto.odometer, liters: dto.liters,
                    totalCost: dto.total_cost,
                    fuelType: FuelType(rawValue: dto.fuel_type) ?? .gasolinaComum,
                    isFullTank: dto.is_full_tank, motorcycle: moto,
                    ocrProcessed: dto.ocr_processed
                )
                log.id = dto.id
                log.motorcycle = moto
                applyFuel(dto, to: log)
                context.insert(log)
            }

            // --- Manutenções ---
            let remoteMaint: [MaintenanceLogDTO] = try await client
                .from("maintenance_logs").select().execute().value
            let localMaint = try context.fetch(FetchDescriptor<MaintenanceLog>())
            let maintByID = Dictionary(uniqueKeysWithValues: localMaint.map { ($0.id, $0) })
            for dto in remoteMaint {
                if let existing = maintByID[dto.id] {
                    // Last-write-wins por `updated_at` (idem abastecimentos).
                    if dto.updated_at > existing.updatedAt {
                        applyMaint(dto, to: existing)
                    }
                    continue
                }
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
                applyMaint(dto, to: log)
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

            // --- Propriedades (moto↔usuário; referência solta por UUID) ---
            let remoteOwnerships: [MotorcycleOwnershipDTO] = try await client
                .from("motorcycle_ownerships").select().execute().value
            let localOwnershipIDs = Set(try context.fetch(FetchDescriptor<MotorcycleOwnership>()).map(\.id))
            for dto in remoteOwnerships where !localOwnershipIDs.contains(dto.id) {
                let ownership = MotorcycleOwnership(
                    motorcycleID: dto.motorcycle_id, userID: dto.user_id,
                    startedAt: dto.started_at, endedAt: dto.ended_at,
                    createdAt: dto.created_at
                )
                ownership.id = dto.id
                ownership.isActive = dto.is_active
                context.insert(ownership)
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

    /// Aplica os campos de um `FuelLogDTO` a um `FuelLog` (novo ou já existente).
    /// Usado no pull tanto para inserir quanto para o last-write-wins (sobrescrita
    /// da linha local quando a remota é mais nova). Não mexe em `id`/`motorcycle`.
    private func applyFuel(_ dto: FuelLogDTO, to log: FuelLog) {
        log.date = dto.date
        log.odometer = dto.odometer
        log.liters = dto.liters
        log.totalCost = dto.total_cost
        log.fuelType = FuelType(rawValue: dto.fuel_type) ?? .gasolinaComum
        log.isFullTank = dto.is_full_tank
        log.latitude = dto.latitude; log.longitude = dto.longitude
        log.city = dto.city; log.state = dto.state; log.country = dto.country
        log.temperatureC = dto.temperature_c
        log.receiptImageURL = dto.receipt_image_url
        log.odometerPhotoURL = dto.odometer_photo_url
        log.ocrProcessed = dto.ocr_processed
        log.ocrConfidence = dto.ocr_confidence
        log.dateWasEdited = dto.date_was_edited
        log.locationWasEdited = dto.location_was_edited
        log.updatedAt = dto.updated_at
        log.revision = dto.revision
        log.deletedAt = dto.deleted_at
    }

    /// Aplica os campos de um `MaintenanceLogDTO` a um `MaintenanceLog`.
    private func applyMaint(_ dto: MaintenanceLogDTO, to log: MaintenanceLog) {
        log.date = dto.date
        log.mileage = dto.mileage
        log.cost = dto.cost
        log.notes = dto.notes
        log.type = MaintenanceType(rawValue: dto.type) ?? .outro
        log.tirePosition = dto.tire_position.flatMap(TirePosition.init(rawValue:))
        log.intervalKm = dto.interval_km
        log.intervalMonths = dto.interval_months
        log.partOfMaintenanceID = dto.part_of_maintenance_id
        log.updatedAt = dto.updated_at
        log.revision = dto.revision
        log.deletedAt = dto.deleted_at
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

            // Push usa os arrays CRUS (`fuelLogs`/`maintenanceLogs`, não os
            // `active*`): linhas soft-deletadas PRECISAM subir para propagar o
            // `deleted_at` aos outros devices.
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
                        date_was_edited: f.dateWasEdited, location_was_edited: f.locationWasEdited,
                        updated_at: f.updatedAt, revision: f.revision, deleted_at: f.deletedAt
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
                        tire_position: mt.tirePositionRaw,
                        updated_at: mt.updatedAt, revision: mt.revision, deleted_at: mt.deletedAt
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

            // Propriedade (fonte de verdade de quem é o dono). Backfill primeiro:
            // motos sem linha ativa (criadas antes desta feature, ou salvas sem
            // sessão) ganham uma agora, atribuída à sessão atual — migração sem
            // ação do usuário, idempotente. Depois faz upsert de todas.
            if MotorcycleOwnership.backfillActive(for: motorcycles, userID: uid, in: context) {
                // Persiste as linhas novas: sem salvar, o próximo push não as veria
                // e criaria outras (UUIDs novos) → linhas ativas duplicadas no
                // Postgres. Salvar mantém o backfill idempotente entre execuções.
                try context.save()
            }
            let ownerships = try context.fetch(FetchDescriptor<MotorcycleOwnership>())
            let ownershipDTOs = ownerships.map { o in
                MotorcycleOwnershipDTO(
                    id: o.id, motorcycle_id: o.motorcycleID, user_id: o.userID,
                    started_at: o.startedAt, ended_at: o.endedAt,
                    is_active: o.isActive, created_at: o.createdAt
                )
            }
            if !ownershipDTOs.isEmpty {
                try await client.from("motorcycle_ownerships").upsert(ownershipDTOs).execute()
            }

            lastError = nil
        } catch {
            lastError = "Falha ao sincronizar: \(error.localizedDescription)"
            Analytics.syncFailed(stage: "push", errorCode: Self.errorCode(error))
        }
    }
}
