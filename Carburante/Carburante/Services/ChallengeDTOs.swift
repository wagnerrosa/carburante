//
//  ChallengeDTOs.swift
//  Carburante
//
//  Respostas das funções dos desafios (`supabase/challenges.sql`), em
//  snake_case como o servidor manda, e a conversão para os tipos de tela
//  (`Challenge`, `ChallengeStanding`, `ChallengeEntry`, `ChallengeInvite`).
//  Os testes decodificam JSON capturado do servidor de verdade. As respostas
//  da lista também vão para o disco como vieram (`ChallengeSnapshot`).
//

import Foundation

/// Uma linha de `my_challenges()`.
struct ChallengeRowDTO: Codable {
    let id: UUID
    let name: String
    let starts_at: Date
    let ends_at: Date
    let time_zone: String
    let cover_path: String?
    let invite_code: String
    let created_by_me: Bool
    let member_count: Int
    let finalized_at: Date?

    var period: ChallengePeriod {
        ChallengePeriod(startsAt: starts_at, endsAt: ends_at,
                        timeZone: ChallengeDTO.timeZone(time_zone))
    }

    func challenge(standings: [ChallengeStanding], entries: [ChallengeEntry]) -> Challenge {
        let period = period
        // Quem criou e está no desafio: o nome dele vem da classificação.
        let createdByName = created_by_me ? standings.first(where: \.isMe)?.name : nil
        return Challenge(id: id, name: name, startDate: period.firstDay, endDate: period.lastDay,
                         createdByName: createdByName, code: invite_code, coverRef: cover_path,
                         standings: standings, entries: entries, createdByMe: created_by_me,
                         timeZone: period.timeZone)
    }
}

/// Uma linha de `challenge_leaderboard(challenge)`.
struct ChallengeStandingDTO: Codable {
    let member_id: UUID
    let rank: Int
    let display_name: String
    let is_me: Bool
    let km: Double
    let fuel_ups: Int
    let bikes: [Bike]
    let last_entry_at: Date?

    struct Bike: Codable {
        let make: String
        let model: String
    }

    var standing: ChallengeStanding {
        ChallengeStanding(id: member_id, rank: rank, name: display_name,
                          bikes: bikes.map { ChallengeBike(make: $0.make, model: $0.model) },
                          fuelUps: fuel_ups, km: km, isMe: is_me, lastEntryAt: last_entry_at)
    }
}

/// Uma linha de `challenge_entries(challenge, member?)`.
struct ChallengeEntryDTO: Codable {
    let fuel_log_id: UUID
    let member_id: UUID
    let date: Date
    let make: String
    let model: String
    let odometer: Double
    /// Chave congelada: start, counted, no_photo, historical, gap, impossible.
    let status: String
    let km: Double
    let odometer_photo_path: String?
    /// Chave congelada: camera, gallery (nil = registro de antes da D5).
    let odometer_photo_source: String?
    let challenge_photo_path: String?

    var entry: ChallengeEntry {
        ChallengeEntry(id: fuel_log_id, memberID: member_id, date: date,
                       bike: ChallengeBike(make: make, model: model), odometer: odometer,
                       status: Self.status(status, km: km),
                       odometerPhotoRef: odometer_photo_path,
                       odometerFromGallery: odometer_photo_source == "gallery",
                       challengePhotoRef: challenge_photo_path)
    }

    static func status(_ key: String, km: Double) -> ChallengeEntry.Status {
        switch key {
        case "counted": .counted(km: km)
        case "start": .start
        case "no_photo": .noPhoto
        case "historical": .notCounted(.historical)
        case "gap": .notCounted(.gap)
        case "impossible": .notCounted(.impossible)
        // Servidor mais novo: se somou km, conta; senão, "não contou".
        default: km > 0 ? .counted(km: km) : .notCounted(.unknown)
        }
    }
}

/// Resposta de `challenge_preview(code)` (null = código não existe).
struct ChallengeInviteDTO: Decodable {
    let id: UUID
    let name: String
    let starts_at: Date
    let ends_at: Date
    let time_zone: String
    let cover_path: String?
    let created_by_name: String?
    let member_count: Int
    let member_names: [String]
    let max_members: Int
    let is_member: Bool
    let is_removed: Bool
    let has_ended: Bool

    func invite(code: String) -> ChallengeInvite {
        ChallengeInvite(id: id, code: code, name: name,
                        period: ChallengePeriod(startsAt: starts_at, endsAt: ends_at,
                                                timeZone: ChallengeDTO.timeZone(time_zone)),
                        coverRef: cover_path, createdByName: created_by_name,
                        memberCount: member_count, memberNames: member_names,
                        maxMembers: max_members, isMember: is_member,
                        isRemoved: is_removed, hasEnded: has_ended)
    }
}

/// `create_challenge` → `{id, invite_code}`; `join_challenge` → `{id}`.
struct ChallengeCreatedDTO: Decodable {
    let id: UUID
    let invite_code: String
}

struct ChallengeJoinedDTO: Decodable {
    let id: UUID
}

enum ChallengeDTO {
    /// O servidor só aceita fusos do `pg_timezone_names` (IANA, os mesmos do
    /// iOS); um nome desconhecido aqui cai no fuso do aparelho.
    static func timeZone(_ identifier: String) -> TimeZone {
        TimeZone(identifier: identifier) ?? .current
    }
}

/// Último placar carregado, guardado como o servidor mandou: abre a aba e o
/// card do Resumo na hora e sem rede ("atualizado há 2 horas"). Cache — o
/// sistema pode apagar; some ao sair da conta.
struct ChallengeSnapshot: Codable {
    struct Item: Codable {
        let row: ChallengeRowDTO
        let standings: [ChallengeStandingDTO]
        let entries: [ChallengeEntryDTO]

        var challenge: Challenge {
            row.challenge(standings: standings.map(\.standing), entries: entries.map(\.entry))
        }
    }

    /// De quem é: outra conta no aparelho não vê.
    let userID: UUID
    let savedAt: Date
    let items: [Item]

    /// Mais recente primeiro: é o que a pílula mostra de cara.
    var challenges: [Challenge] {
        items.map(\.challenge).sorted { $0.startDate > $1.startDate }
    }

    func item(_ challengeID: UUID) -> Item? {
        items.first { $0.row.id == challengeID }
    }

    /// O mesmo placar com o mural de um desafio trocado (encerrado aberto
    /// depois). Mantém a hora: a classificação continua sendo a daquela carga.
    func replacingEntries(_ entries: [ChallengeEntryDTO], of challengeID: UUID) -> ChallengeSnapshot {
        ChallengeSnapshot(userID: userID, savedAt: savedAt, items: items.map { item in
            item.row.id == challengeID
                ? Item(row: item.row, standings: item.standings, entries: entries)
                : item
        })
    }

    private static let fileURL: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("ChallengeSnapshot.json")
    }()

    static func load(from url: URL = fileURL) -> ChallengeSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ChallengeSnapshot.self, from: data)
    }

    func save(to url: URL = Self.fileURL) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func remove(at url: URL = fileURL) {
        try? FileManager.default.removeItem(at: url)
    }
}
