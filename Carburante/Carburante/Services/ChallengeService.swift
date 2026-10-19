//
//  ChallengeService.swift
//  Carburante
//
//  Desafios em grupo (PLAN/desafios.md): o app só fala com o servidor pelas
//  funções de `supabase/challenges.sql` — as tabelas são fechadas, e a
//  classificação é calculada lá. Desafio é ONLINE (sem SwiftData): esta classe
//  guarda em memória o que a aba mostra e recarrega ao abrir/puxar.
//
//  Tudo exige conta Apple (o servidor recusa sessão anônima), menos a prévia
//  do convite. Erros chegam como chaves congeladas → `ChallengeError`.
//

import Foundation
import Supabase

@MainActor
@Observable
final class ChallengeService {
    static let shared = ChallengeService()

    /// Meus desafios (ativos e encerrados), já com classificação e mural.
    private(set) var challenges: [Challenge] = []
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

    private init() {}

    // MARK: Leitura

    /// Recarrega meus desafios. Chamadas seguidas esperam a que está em voo.
    func refresh() async {
        if let refreshTask { return await refreshTask.value }
        let task = Task { await load() }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func load() async {
        if sync.userID != loadedUserID {
            challenges = []
            updatedAt = nil
        }
        // Sessão anônima não tem desafio (o servidor recusaria).
        guard let userID = await sync.ensureSession(), !sync.isAnonymous else {
            challenges = []
            loadedUserID = sync.userID
            updatedAt = Date()
            state = .loaded
            return
        }
        state = .loading
        do {
            let rows: [ChallengeRowDTO] = try await client.rpc("my_challenges").execute().value
            var loaded: [Challenge] = []
            try await withThrowingTaskGroup(of: Challenge.self) { group in
                for row in rows {
                    group.addTask { try await self.challenge(from: row) }
                }
                for try await challenge in group { loaded.append(challenge) }
            }
            // Mais recente primeiro: é o que a pílula mostra de cara.
            challenges = loaded.sorted { $0.startDate > $1.startDate }
            loadedUserID = userID
            updatedAt = Date()
            state = .loaded
        } catch {
            state = .failed(Self.challengeError(error))
        }
    }

    /// Classificação + mural de um desafio. Encerrado só precisa da
    /// classificação (o card mostra os 3 primeiros).
    private func challenge(from row: ChallengeRowDTO) async throws -> Challenge {
        async let standings = leaderboard(row.id)
        let finished = row.period.phase() == .finished
        let entries = finished ? [] : try await self.entries(row.id)
        return row.challenge(standings: try await standings, entries: entries)
    }

    func leaderboard(_ challengeID: UUID) async throws -> [ChallengeStanding] {
        let rows: [ChallengeStandingDTO] = try await client
            .rpc("challenge_leaderboard", params: ["p_challenge_id": challengeID])
            .execute().value
        return rows.map(\.standing)
    }

    /// Mural (sem `memberID`) ou os registros de um participante.
    func entries(_ challengeID: UUID, memberID: UUID? = nil) async throws -> [ChallengeEntry] {
        let rows: [ChallengeEntryDTO] = try await client
            .rpc("challenge_entries", params: EntriesParams(p_challenge_id: challengeID,
                                                            p_member_id: memberID))
            .execute().value
        return rows.map(\.entry)
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
