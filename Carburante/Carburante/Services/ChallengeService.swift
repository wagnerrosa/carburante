//
//  ChallengeService.swift
//  Carburante
//
//  Desafios em grupo (PLAN/desafios.md): o app só fala com o servidor pelas
//  funções de `supabase/challenges.sql` — as tabelas são fechadas, e a
//  classificação é calculada lá. Desafio é ONLINE (sem SwiftData): esta classe
//  guarda em memória o que a aba mostra e recarrega no launch, ao abrir/puxar,
//  ao voltar ao app e depois de cada abastecimento. O último placar fica no
//  disco (`ChallengeSnapshot`) para abrir na hora e sem rede.
//
//  Tudo exige conta Apple (o servidor recusa sessão anônima), menos a prévia
//  do convite. Erros chegam como chaves congeladas → `ChallengeError`.
//

import Foundation
import SwiftData
import Supabase
import UIKit

@MainActor
@Observable
final class ChallengeService {
    static let shared = ChallengeService()

    /// Meus desafios (ativos e encerrados), já com classificação e mural.
    private(set) var challenges: [Challenge] = []
    /// Quanto o último abastecimento mexeu em cada placar (só na memória).
    private(set) var gains: [UUID: ChallengeGain] = [:]
    private(set) var state: LoadState = .idle
    /// Última vez que a lista veio do servidor.
    private(set) var updatedAt: Date?

    enum LoadState: Equatable {
        case idle, loading, loaded
        case failed(ChallengeError)
    }

    private var sync: SyncService { .shared }
    private var client: SupabaseClient { sync.client }
    /// De quem é a lista em memória: trocou de conta, ela some.
    @ObservationIgnored private var loadedUserID: UUID?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    /// As respostas do servidor por trás de `challenges` (e do arquivo).
    @ObservationIgnored private var snapshot: ChallengeSnapshot?
    /// Encerrados com o mural já carregado nesta abertura do app.
    @ObservationIgnored private var finishedEntriesLoaded: Set<UUID> = []

    /// O último placar guardado abre a aba e o card do Resumo antes da rede.
    private init() {
        if let snapshot = ChallengeSnapshot.load() {
            self.snapshot = snapshot
            challenges = snapshot.challenges
            updatedAt = snapshot.savedAt
            loadedUserID = snapshot.userID
        }
    }

    // MARK: Leitura

    /// Recarrega meus desafios. Chamadas seguidas esperam a que está em voo.
    func refresh() async {
        if let refreshTask { return await refreshTask.value }
        let task = Task { await load() }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    /// Volta ao app: recarrega se o placar tem mais de `maxAge` segundos.
    func refreshIfStale(maxAge: TimeInterval = 5 * 60) async {
        guard let updatedAt, Date().timeIntervalSince(updatedAt) < maxAge else {
            return await refresh()
        }
    }

    /// Depois de salvar um abastecimento (e de o push subir linha e foto):
    /// recarrega e guarda quanto cada placar mexeu — o "+230 km" do card.
    func refreshAfterFuelUp() async {
        // Uma carga em voo pode ter saído antes do push: espera e carrega de novo.
        if let refreshTask { await refreshTask.value }
        let before = Dictionary(uniqueKeysWithValues: challenges.map { ($0.id, $0.me) })
        await refresh()
        guard state == .loaded else { return }
        for challenge in challenges {
            if let gain = ChallengeGain(before: before[challenge.id] ?? nil, after: challenge.me) {
                gains[challenge.id] = gain
            }
        }
    }

    /// O desafio do card do Resumo (`Challenge.forSummary`).
    var summaryChallenge: Challenge? { Challenge.forSummary(challenges) }

    /// "+230 km no último abastecimento", enquanto for recente.
    func gain(for challengeID: UUID) -> ChallengeGain? {
        gains[challengeID].flatMap { $0.isFresh() ? $0 : nil }
    }

    /// Sem conexão e mostrando o último placar guardado.
    var isShowingSavedCopy: Bool {
        if case .failed = state { return updatedAt != nil && !challenges.isEmpty }
        return false
    }

    /// Sair da conta / apagar dados: nada dos desafios fica no aparelho.
    func clearLocal() {
        challenges = []
        gains = [:]
        updatedAt = nil
        loadedUserID = nil
        snapshot = nil
        finishedEntriesLoaded = []
        state = .idle
        ChallengeSnapshot.remove()
    }

    private func load() async {
        // Sessão anônima não tem desafio (o servidor recusaria).
        guard let userID = await sync.ensureSession(), !sync.isAnonymous else {
            clearLocal()
            loadedUserID = sync.userID
            updatedAt = Date()
            state = .loaded
            return
        }
        // Outra conta: a lista (e o guardado) era de quem saiu.
        if userID != loadedUserID {
            clearLocal()
        }
        state = .loading
        let previous = snapshot
        do {
            let rows: [ChallengeRowDTO] = try await client.rpc("my_challenges").execute().value
            var items: [ChallengeSnapshot.Item] = []
            try await withThrowingTaskGroup(of: ChallengeSnapshot.Item.self) { group in
                for row in rows {
                    let earlier = previous?.item(row.id)
                    group.addTask { try await self.snapshotItem(row, previous: earlier) }
                }
                for try await item in group { items.append(item) }
            }
            let snapshot = ChallengeSnapshot(userID: userID, savedAt: Date(), items: items)
            loadedUserID = userID
            updatedAt = snapshot.savedAt
            state = .loaded
            apply(snapshot)
        } catch {
            state = .failed(Self.challengeError(error))
        }
    }

    /// Classificação + mural + conversa de um desafio, como o servidor mandou.
    /// Encerrado só traz a classificação (a lista mostra os 3 primeiros); o
    /// mural e a conversa dele carregam ao abrir (`loadEntriesIfNeeded`) e o
    /// que já veio fica.
    private func snapshotItem(_ row: ChallengeRowDTO,
                              previous: ChallengeSnapshot.Item?) async throws -> ChallengeSnapshot.Item {
        async let standings = leaderboard(row.id)
        guard row.period.phase() != .finished else {
            return ChallengeSnapshot.Item(row: row, standings: try await standings,
                                          entries: previous?.entries ?? [], social: previous?.social)
        }
        async let entries = self.entries(row.id)
        async let social = self.social(row.id)
        return ChallengeSnapshot.Item(row: row, standings: try await standings,
                                      entries: try await entries, social: try await social)
    }

    /// Encerrado aberto na aba: mural e registros dos pilotos, 1 vez por
    /// abertura do app (a classificação já congelou; as fotos seguem visíveis
    /// para a turma).
    func loadEntriesIfNeeded(for challengeID: UUID) async {
        guard !finishedEntriesLoaded.contains(challengeID),
              let row = snapshot?.item(challengeID)?.row,
              row.period.phase() == .finished else { return }
        finishedEntriesLoaded.insert(challengeID)
        async let entries = try? self.entries(challengeID)
        async let social = try? self.social(challengeID)
        guard let entries = await entries else {
            finishedEntriesLoaded.remove(challengeID)
            return
        }
        let loadedSocial = await social
        // A lista pode ter recarregado enquanto isso: aplica na mais nova.
        if var current = snapshot {
            current = current.replacingEntries(entries, of: challengeID)
            if let loadedSocial { current = current.replacingSocial(loadedSocial, of: challengeID) }
            apply(current)
        }
    }

    /// Conversa de um desafio de novo (abriu um abastecimento, comentou,
    /// reagiu, votou). Sem rede, fica a que está na tela.
    func refreshSocial(for challengeID: UUID) async {
        guard let social = try? await social(challengeID), let current = snapshot,
              current.item(challengeID) != nil else { return }
        apply(current.replacingSocial(social, of: challengeID))
    }

    private func apply(_ snapshot: ChallengeSnapshot) {
        self.snapshot = snapshot
        challenges = snapshot.challenges
        snapshot.save()
    }

    private func leaderboard(_ challengeID: UUID) async throws -> [ChallengeStandingDTO] {
        try await client
            .rpc("challenge_leaderboard", params: ["p_challenge_id": challengeID])
            .execute().value
    }

    private func social(_ challengeID: UUID) async throws -> ChallengeSocialDTO {
        try await client
            .rpc("challenge_social", params: ["p_challenge_id": challengeID])
            .execute().value
    }

    /// Mural (sem `memberID`) ou os registros de um participante.
    private func entries(_ challengeID: UUID, memberID: UUID? = nil) async throws -> [ChallengeEntryDTO] {
        try await client
            .rpc("challenge_entries", params: EntriesParams(p_challenge_id: challengeID,
                                                            p_member_id: memberID))
            .execute().value
    }

    // MARK: Comentários, reações, votos (D7)

    /// Comenta num abastecimento do mural. Depois, a conversa vem do servidor
    /// (com o id e a hora de lá).
    func postComment(_ text: String, on entryID: UUID, in challengeID: UUID) async throws(ChallengeError) {
        let _: ChallengeCommentPostedDTO = try await call { [client] in
            try await client.rpc("post_challenge_comment",
                                 params: CommentParams(p_challenge_id: challengeID, p_fuel_log_id: entryID,
                                                       p_body: text))
                .execute().value
        }
        await refreshSocial(for: challengeID)
    }

    /// Apaga o comentário (quem escreveu ou quem criou o desafio).
    func deleteComment(_ commentID: UUID, in challengeID: UUID) async throws(ChallengeError) {
        try await call { [client] in
            try await client.rpc("delete_challenge_comment", params: ["p_comment_id": commentID]).execute()
        }
        await refreshSocial(for: challengeID)
    }

    /// Põe, troca (`emoji`) ou tira (nil) a sua reação.
    func setReaction(_ emoji: String?, on entryID: UUID, in challengeID: UUID) async throws(ChallengeError) {
        try await call { [client] in
            try await client.rpc("set_challenge_reaction",
                                 params: MarkParams(p_challenge_id: challengeID, p_fuel_log_id: entryID,
                                                    key: "p_emoji", value: emoji))
                .execute()
        }
        await refreshSocial(for: challengeID)
    }

    /// Vota (`ok`/`suspect`) ou tira o voto (nil) na foto do hodômetro.
    func setVote(_ vote: PhotoVote?, on entryID: UUID, in challengeID: UUID) async throws(ChallengeError) {
        try await call { [client] in
            try await client.rpc("set_challenge_photo_vote",
                                 params: MarkParams(p_challenge_id: challengeID, p_fuel_log_id: entryID,
                                                    key: "p_vote", value: vote?.rawValue))
                .execute()
        }
        await refreshSocial(for: challengeID)
    }

    // MARK: Foto do desafio

    /// Foto do desafio posta ou trocada depois de salvar o abastecimento (D6).
    /// Grava no disco como o fluxo do abastecimento (sem metadados), sobe pelo
    /// sync de sempre e recarrega o mural. Trocar não muda o caminho no bucket
    /// (a policy da turma exige `<log>-challenge.jpg`): os outros iPhones
    /// percebem pela data do arquivo (`ChallengeImageStore`).
    func setChallengePhoto(_ image: UIImage, logID: UUID, context: ModelContext) async -> ChallengePhotoSaveResult {
        let descriptor = FetchDescriptor<FuelLog>(predicate: #Predicate { $0.id == logID })
        guard let log = try? context.fetch(descriptor).first, log.deletedAt == nil,
              let motorcycle = log.motorcycle,
              let ref = PhotoStorage.saveChallengePhoto(image, for: log.id),
              let data = PhotoStorage.data(for: ref) else {
            return .unavailable
        }
        let path = PhotoReference.challengeRemotePath(motorcycleID: motorcycle.id, logID: log.id)
        log.challengePhotoURL = ref
        try? context.save()
        // Aparece já neste iPhone, antes do upload.
        ChallengeImageStore.shared.store(data, for: path, bucket: PhotoReference.bucket)
        await sync.pushAll(from: context)
        // Um sync em andamento só marca outra rodada: espera ela terminar (até 15 s).
        var waits = 0
        while sync.isSyncing, waits < 60 {
            try? await Task.sleep(for: .milliseconds(250))
            waits += 1
        }
        guard PhotoReference.isRemote(log.challengePhotoURL) else { return .pending(path: path) }
        await refresh()
        return .sent(path: path)
    }

    // MARK: Criar, entrar, sair

    /// Cria o desafio; quem cria entra com `displayName`. Com `cover` (JPEG
    /// pronto, `ChallengeCover.jpeg`), sobe a capa logo depois. A capa que não
    /// subiu não desfaz o desafio: `coverSaved` false e quem criou tenta de
    /// novo nos detalhes.
    @discardableResult
    func create(name: String, period: ChallengePeriod, displayName: String,
                cover: Data? = nil) async throws(ChallengeError) -> (id: UUID, coverSaved: Bool) {
        let params = CreateParams(p_name: name, p_starts_at: period.startsAt, p_ends_at: period.endsAt,
                                  p_display_name: displayName, p_time_zone: period.timeZone.identifier)
        let created: ChallengeCreatedDTO = try await call { [client] in
            try await client.rpc("create_challenge", params: params).execute().value
        }
        var coverSaved = true
        if let cover {
            do {
                try await uploadCover(cover, for: created.id, replacing: nil)
            } catch {
                coverSaved = false
            }
        }
        await refresh()
        return (created.id, coverSaved)
    }

    /// Quem criou põe, troca (`jpeg`) ou tira (nil) a capa. O arquivo sobe
    /// antes com nome novo; depois do `set_challenge_cover`, o anterior sai do
    /// bucket.
    func setCover(_ jpeg: Data?, for challengeID: UUID) async throws(ChallengeError) {
        let current = challenges.first { $0.id == challengeID }?.coverRef
        if let jpeg {
            try await uploadCover(jpeg, for: challengeID, replacing: current)
        } else {
            try await call { [client] in
                try await client.rpc("set_challenge_cover", params: CoverParams(p_challenge_id: challengeID,
                                                                                 p_cover_path: nil))
                    .execute()
            }
            await removeCoverFile(current)
        }
        await refresh()
    }

    private func uploadCover(_ jpeg: Data, for challengeID: UUID,
                             replacing old: String?) async throws(ChallengeError) {
        let path = ChallengeCover.path(challengeID: challengeID)
        try await call { [client] in
            try await client.storage.from(ChallengeCover.bucket).upload(
                path, data: jpeg, options: FileOptions(contentType: "image/jpeg")
            )
        }
        ChallengeImageStore.shared.store(jpeg, for: path)
        do {
            try await call { [client] in
                try await client.rpc("set_challenge_cover", params: CoverParams(p_challenge_id: challengeID,
                                                                                 p_cover_path: path))
                    .execute()
            }
        } catch {
            // A capa nova não entrou: o arquivo não serve para nada.
            await removeCoverFile(path)
            throw Self.challengeError(error)
        }
        await removeCoverFile(old)
    }

    /// Melhor esforço: arquivo que sobra no bucket só ocupa espaço.
    private func removeCoverFile(_ path: String?) async {
        guard let path, ChallengeCover.isRemote(path) else { return }
        _ = try? await client.storage.from(ChallengeCover.bucket).remove(paths: [path])
    }

    /// Prévia do convite pelo código digitado/colado/do link. nil = o código
    /// não existe (o servidor conta como tentativa errada).
    func preview(code: String) async throws(ChallengeError) -> ChallengeInvite? {
        guard let normalized = InviteCode.normalized(code) else { return nil }
        guard await sync.ensureSession() != nil else { throw .noSession }
        let dto: ChallengeInviteDTO? = try await call { [client] in
            try await client.rpc("challenge_preview", params: ["p_code": normalized]).execute().value
        }
        return dto?.invite(code: normalized)
    }

    /// Entra pelo código (já estava dentro = mesmo resultado). nil = o código
    /// não vale mais (trocado entre a prévia e o "Entrar").
    @discardableResult
    func join(code: String, displayName: String) async throws(ChallengeError) -> UUID? {
        let joined: ChallengeJoinedDTO? = try await call { [client] in
            try await client.rpc("join_challenge",
                                 params: ["p_code": code, "p_display_name": displayName])
                .execute().value
        }
        if joined != nil { await refresh() }
        return joined?.id
    }

    func leave(_ challengeID: UUID) async throws(ChallengeError) {
        try await call { [client] in
            try await client.rpc("leave_challenge", params: ["p_challenge_id": challengeID]).execute()
        }
        challenges.removeAll { $0.id == challengeID }
        await refresh()
    }

    /// Quem criou tira um participante (ele não volta pelo código).
    func removeMember(_ memberID: UUID, from challengeID: UUID) async throws(ChallengeError) {
        try await call { [client] in
            try await client.rpc("remove_member",
                                 params: ["p_challenge_id": challengeID, "p_member_id": memberID])
                .execute()
        }
        await refresh()
    }

    // MARK: Erros

    /// Roda uma chamada e traduz o erro para `ChallengeError`.
    @discardableResult
    private func call<T>(_ operation: () async throws -> T) async throws(ChallengeError) -> T {
        do {
            return try await operation()
        } catch {
            throw Self.challengeError(error)
        }
    }

    static func challengeError(_ error: Error) -> ChallengeError {
        switch error {
        case let error as ChallengeError: error
        // `raise exception '<chave>'` chega como a mensagem do erro.
        case let error as PostgrestError: ChallengeError(serverKey: error.message)
        case is URLError: .offline
        default: .unknown(String(describing: error))
        }
    }

    /// Mesmo decodificador do SDK (datas do Postgres com e sem fração) —
    /// os testes decodificam as respostas capturadas do servidor com ele.
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try PostgrestClient.Configuration.jsonDecoder.decode(type, from: data)
    }
}

/// Resultado de pôr/trocar a foto do desafio num abastecimento salvo.
enum ChallengePhotoSaveResult: Equatable {
    /// Subiu: a turma já vê.
    case sent(path: String)
    /// Ficou no iPhone (sem rede); sobe no próximo sync.
    case pending(path: String)
    /// O registro não está neste iPhone, ou a foto não gravou.
    case unavailable

    /// Onde a foto fica no bucket (a mesma em qualquer iPhone da turma).
    var path: String? {
        switch self {
        case .sent(let path), .pending(let path): path
        case .unavailable: nil
        }
    }
}

private struct CreateParams: Encodable {
    let p_name: String
    let p_starts_at: Date
    let p_ends_at: Date
    let p_display_name: String
    let p_time_zone: String
}

/// `p_cover_path` nil vai como `null` (tirar a capa), não some do corpo.
private struct CoverParams: Encodable {
    let p_challenge_id: UUID
    let p_cover_path: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_challenge_id, forKey: .p_challenge_id)
        try container.encode(p_cover_path, forKey: .p_cover_path)
    }

    private enum CodingKeys: String, CodingKey { case p_challenge_id, p_cover_path }
}

private struct CommentParams: Encodable {
    let p_challenge_id: UUID
    let p_fuel_log_id: UUID
    let p_body: String
}

/// Reação ou voto: nil vai como `null` (tirar), não some do corpo.
private struct MarkParams: Encodable {
    let p_challenge_id: UUID
    let p_fuel_log_id: UUID
    let key: String
    let value: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        try container.encode(p_challenge_id, forKey: DynamicKey("p_challenge_id"))
        try container.encode(p_fuel_log_id, forKey: DynamicKey("p_fuel_log_id"))
        try container.encode(value, forKey: DynamicKey(key))
    }

    private struct DynamicKey: CodingKey {
        let stringValue: String
        init(_ string: String) { stringValue = string }
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }
}

private struct EntriesParams: Encodable {
    let p_challenge_id: UUID
    let p_member_id: UUID?

    // nil não vai no corpo: o servidor usa o padrão (mural inteiro).
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_challenge_id, forKey: .p_challenge_id)
        try container.encodeIfPresent(p_member_id, forKey: .p_member_id)
    }

    private enum CodingKeys: String, CodingKey { case p_challenge_id, p_member_id }
}

/// Liga a aba Desafios. Só no build de desenvolvimento enquanto a v1 não
/// fecha (PLAN/desafios.md D2–D8): a 1.2 e um eventual 1.2.x saem sem ela.
/// O teste com amigos (D6, TestFlight) e a 1.3 ligam de vez.
enum ChallengeFeature {
    static var isEnabled: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}
