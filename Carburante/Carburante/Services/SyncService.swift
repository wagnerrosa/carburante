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
import UIKit

@MainActor
@Observable
final class SyncService {
    static let shared = SyncService()

    let client: SupabaseClient
    private(set) var userID: UUID?
    private(set) var lastError: String?
    private(set) var isSyncing = false
    /// Pedido de push que chegou com outro em voo → roda mais uma passada.
    @ObservationIgnored private var pushPending = false
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
        guard let uid = await ensureSession() else {
            lastError = "Sem sessão para excluir a conta."
            return false
        }
        do {
            // Fotos antes do usuário: depois do RPC ninguém mais consegue apagá-las.
            try await deleteRemotePhotos(userID: uid)
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
            PhotoStorage.deleteAllLocal()
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

            // Exclusão lógica vinda de outro device: aplica na moto local viva.
            // Só a moto — os logs filhos trazem o próprio `deleted_at` (LWW abaixo).
            for dto in remoteMotos {
                if let deletedAt = dto.deleted_at, let local = motoByID[dto.id], local.deletedAt == nil {
                    local.deletedAt = deletedAt
                }
            }

            // Moto remota ausente local → insere (mesmo excluída: mantém a FK dos
            // logs e o histórico; a leitura já a esconde via `activePredicate`).
            for dto in remoteMotos where motoByID[dto.id] == nil {
                let moto = Motorcycle(
                    make: dto.make, model: dto.model, year: dto.year,
                    country: dto.country ?? "", currentOdometer: dto.current_odometer,
                    category: dto.category, displacementCC: dto.displacement_cc,
                    manufacturerConsumption: dto.manufacturer_consumption
                )
                moto.id = dto.id
                moto.odometerBaseline = dto.odometer_baseline
                moto.deletedAt = dto.deleted_at
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
                        Self.applyFuel(dto, to: existing)
                    }
                    healCreatedAt(&existing.createdAt, remote: dto.created_at)
                    // Foto fora do LWW: o upload muda a referência sem mexer em
                    // `updated_at`, então só o merge entrega o path a este device.
                    existing.odometerPhotoURL = PhotoReference.merge(
                        local: existing.odometerPhotoURL, remote: dto.odometer_photo_url
                    )
                    continue
                }
                guard let moto = motoByID[dto.motorcycle_id] else { continue }
                let log = FuelLog(
                    date: dto.date, odometer: dto.odometer, liters: dto.liters,
                    totalCost: dto.total_cost,
                    fuelType: FuelType(rawValue: dto.fuel_type) ?? .gasolinaComum,
                    isFullTank: dto.is_full_tank, motorcycle: moto,
                    ocrProcessed: dto.ocr_processed,
                    createdAt: dto.created_at
                )
                log.id = dto.id
                log.motorcycle = moto
                Self.applyFuel(dto, to: log)
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
                        Self.applyMaint(dto, to: existing)
                    }
                    healCreatedAt(&existing.createdAt, remote: dto.created_at)
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
                    motorcycle: moto,
                    createdAt: dto.created_at
                )
                log.id = dto.id
                Self.applyMaint(dto, to: log)
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

    /// `createdAt` é um fato imutável (quando o registro entrou no app): vale o
    /// MENOR entre local e remoto, independente do last-write-wins. Cura devices
    /// que puxaram o log antes de o campo sincronizar (ganharam `Date()` do
    /// pull). Tolerância de 1 s: o JSON perde sub-milissegundos e não queremos
    /// reescrever toda linha a cada launch.
    private func healCreatedAt(_ local: inout Date, remote: Date) {
        if remote < local.addingTimeInterval(-1) { local = remote }
    }

    /// Aplica os campos de um `FuelLogDTO` a um `FuelLog` (novo ou já existente).
    /// Usado no pull tanto para inserir quanto para o last-write-wins (sobrescrita
    /// da linha local quando a remota é mais nova). Não mexe em `id`/`motorcycle`.
    ///
    /// Enums vêm como **chave crua**, nunca via `FuelType(rawValue:) ?? fallback`:
    /// um build novo pode gravar um tipo que este não conhece (ex.: combustível de
    /// outro país), e converter para o fallback aqui faria o push seguinte
    /// sobrescrever o dado certo no Supabase. A tela usa o fallback; o dado fica
    /// intacto. Estático e interno só para os testes (`SyncEnumPassthroughTests`).
    static func applyFuel(_ dto: FuelLogDTO, to log: FuelLog) {
        log.date = dto.date
        log.odometer = dto.odometer
        log.liters = dto.liters
        log.totalCost = dto.total_cost
        log.fuelTypeRaw = dto.fuel_type
        log.isFullTank = dto.is_full_tank
        log.latitude = dto.latitude; log.longitude = dto.longitude
        log.city = dto.city; log.state = dto.state; log.country = dto.country
        log.temperatureC = dto.temperature_c
        log.receiptImageURL = dto.receipt_image_url
        // Nunca sobrescreve uma foto local ainda não enviada (ver PhotoReference.merge).
        log.odometerPhotoURL = PhotoReference.merge(local: log.odometerPhotoURL,
                                                    remote: dto.odometer_photo_url)
        log.ocrProcessed = dto.ocr_processed
        log.ocrConfidence = dto.ocr_confidence
        log.dateWasEdited = dto.date_was_edited
        log.locationWasEdited = dto.location_was_edited
        log.updatedAt = dto.updated_at
        log.revision = dto.revision
        log.deletedAt = dto.deleted_at
    }

    /// Aplica os campos de um `MaintenanceLogDTO` a um `MaintenanceLog`. Enums
    /// como chave crua — mesmo motivo de `applyFuel`.
    static func applyMaint(_ dto: MaintenanceLogDTO, to log: MaintenanceLog) {
        log.date = dto.date
        log.mileage = dto.mileage
        log.cost = dto.cost
        log.notes = dto.notes
        log.typeRaw = dto.type
        log.tirePositionRaw = dto.tire_position
        log.intervalKm = dto.interval_km
        log.intervalMonths = dto.interval_months
        log.partOfMaintenanceID = dto.part_of_maintenance_id
        log.updatedAt = dto.updated_at
        log.revision = dto.revision
        log.deletedAt = dto.deleted_at
    }

    /// Faz push de todas as motos do usuário (e seus filhos) para o Supabase.
    /// Chamada com um push já em voo (ex.: save durante o sync do launch numa
    /// rede lenta) não é descartada: marca `pushPending` e o push em voo roda de
    /// novo ao terminar — o snapshot dele pode ter sido lido antes do save.
    func pushAll(from context: ModelContext) async {
        guard !isSyncing else {
            pushPending = true
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        repeat {
            pushPending = false
            await performPush(from: context)
        } while pushPending
    }

    private func performPush(from context: ModelContext) async {
        guard let uid = await ensureSession() else { return }

        do {
            let motorcycles = try context.fetch(FetchDescriptor<Motorcycle>())

            let motoDTOs = motorcycles.map { m in
                MotorcycleDTO(
                    id: m.id, user_id: uid, make: m.make, model: m.model, year: m.year,
                    country: m.country, current_odometer: m.currentOdometer,
                    odometer_baseline: m.odometerBaseline,
                    category: m.category, displacement_cc: m.displacementCC,
                    manufacturer_consumption: m.manufacturerConsumption,
                    deleted_at: m.deletedAt
                )
            }
            if !motoDTOs.isEmpty {
                try await client.from("motorcycles").upsert(motoDTOs).execute()
            }

            // Push usa os arrays CRUS (`fuelLogs`/`maintenanceLogs`, não os
            // `active*`): linhas soft-deletadas PRECISAM subir para propagar o
            // `deleted_at` aos outros devices.
            let fuelDTOs = motorcycles.flatMap { m in
                m.fuelLogs.map { fuelDTO($0, motorcycleID: m.id, userID: uid) }
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
                        updated_at: mt.updatedAt, revision: mt.revision, deleted_at: mt.deletedAt,
                        created_at: mt.createdAt
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
            if MotorcycleOwnership.backfillActive(
                for: motorcycles.filter { $0.deletedAt == nil }, userID: uid, in: context
            ) {
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

            // Fotos por ÚLTIMO: os dados já subiram, então uma rede lenta (fotos
            // são o payload mais pesado) não segura linhas nem estoura o timeout
            // do launch antes delas. As que subirem agora re-sobem a linha com o
            // path remoto; as que falharem ficam locais e tentam no próximo push.
            let uploaded = await uploadPendingPhotos(motorcycles, userID: uid)
            if !uploaded.isEmpty {
                try context.save()
                let dtos = uploaded.compactMap { f in
                    f.motorcycle.map { fuelDTO(f, motorcycleID: $0.id, userID: uid) }
                }
                try await client.from("fuel_logs").upsert(dtos).execute()
            }

            lastError = nil
        } catch {
            lastError = "Falha ao sincronizar: \(error.localizedDescription)"
            Analytics.syncFailed(stage: "push", errorCode: Self.errorCode(error))
        }
    }

    private func fuelDTO(_ f: FuelLog, motorcycleID: UUID, userID: UUID) -> FuelLogDTO {
        FuelLogDTO(
            id: f.id, motorcycle_id: motorcycleID, user_id: userID, date: f.date,
            odometer: f.odometer, liters: f.liters, total_cost: f.totalCost,
            fuel_type: f.fuelTypeRaw, is_full_tank: f.isFullTank,
            latitude: f.latitude, longitude: f.longitude, city: f.city,
            state: f.state, country: f.country, temperature_c: f.temperatureC,
            receipt_image_url: f.receiptImageURL,
            odometer_photo_url: PhotoReference.pushValue(f.odometerPhotoURL),
            ocr_processed: f.ocrProcessed, ocr_confidence: f.ocrConfidence,
            date_was_edited: f.dateWasEdited, location_was_edited: f.locationWasEdited,
            updated_at: f.updatedAt, revision: f.revision, deleted_at: f.deletedAt,
            created_at: f.createdAt
        )
    }

    // MARK: - Fotos do hodômetro (Storage)

    /// Sobe as fotos com upload pendente (referência local) pro bucket privado e
    /// troca a referência pelo path remoto. Devolve os logs que mudaram. Falha
    /// por foto é engolida (best-effort): a foto segue no disco e tenta de novo
    /// no próximo push — não derruba o sync dos dados.
    private func uploadPendingPhotos(_ motorcycles: [Motorcycle], userID: UUID) async -> [FuelLog] {
        let pending = motorcycles.flatMap(\.fuelLogs).filter {
            $0.deletedAt == nil && PhotoReference.isPendingUpload($0.odometerPhotoURL)
        }
        var uploaded: [FuelLog] = []
        for log in pending {
            guard let data = PhotoStorage.data(for: log.odometerPhotoURL) else { continue }
            let path = PhotoReference.remotePath(userID: userID, logID: log.id)
            do {
                // upsert: uma foto trocada na edição sobrescreve a anterior (mesmo path).
                try await client.storage.from(PhotoReference.bucket).upload(
                    path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true)
                )
                log.odometerPhotoURL = path
                uploaded.append(log)
            } catch {
                Analytics.syncFailed(stage: "photo_upload", errorCode: Self.errorCode(error))
            }
        }
        return uploaded
    }

    /// Foto do hodômetro para exibir: disco deste device primeiro (offline);
    /// senão baixa do bucket privado com a sessão (RLS: só a própria pasta).
    func odometerPhoto(for ref: String?) async -> UIImage? {
        if let local = PhotoStorage.localImage(for: ref) { return local }
        guard PhotoReference.isRemote(ref), let ref, await ensureSession() != nil else { return nil }
        do {
            let data = try await client.storage.from(PhotoReference.bucket).download(path: ref)
            return UIImage(data: data)
        } catch {
            Analytics.syncFailed(stage: "photo_download", errorCode: Self.errorCode(error))
            return nil
        }
    }

    /// Apaga TODAS as fotos do usuário no bucket (exclusão de conta). Precisa
    /// rodar ANTES de apagar o usuário: o cascade do Postgres não alcança o
    /// Storage, e sem o usuário as policies não deixam mais ninguém apagar.
    private func deleteRemotePhotos(userID: UUID) async throws {
        let bucket = client.storage.from(PhotoReference.bucket)
        let folder = userID.uuidString
        while true {
            let files = try await bucket.list(path: folder, options: SearchOptions(limit: 100))
            guard !files.isEmpty else { return }
            let removed = try await bucket.remove(paths: files.map { "\(folder)/\($0.name)" })
            // RLS negando o delete devolve lista vazia sem erro — sem esta guarda
            // o loop listaria os mesmos arquivos para sempre.
            guard !removed.isEmpty else {
                throw URLError(.noPermissionsToReadFile)
            }
        }
    }
}
