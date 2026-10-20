//
//  Challenge.swift
//  Carburante
//
//  Desafios em grupo (PLAN/desafios.md). Tipos de LEITURA: o servidor calcula
//  a classificação (`challenge_leaderboard`) e o app só exibe. Valores puros,
//  sem SwiftData — nada disso é fonte de verdade no aparelho. Quem fala com o
//  servidor é o `ChallengeService`.
//

import Foundation

struct Challenge: Identifiable, Hashable {
    let id: UUID
    var name: String
    /// Primeiro e último dia do período (o último conta inteiro), no fuso
    /// `timeZone`.
    var startDate: Date
    var endDate: Date
    /// Nome de quem criou, como a turma vê. nil = não veio do servidor.
    var createdByName: String?
    /// Código do convite, normalizado (`InviteCode`). Vai no link
    /// `carburante.motorcycles/d/?c=<código>`.
    var code: String
    /// Referência da capa no Storage. nil = capa padrão do app.
    var coverRef: String?
    var standings: [ChallengeStanding]
    /// Abastecimentos dos participantes dentro do período (mais novo primeiro).
    var entries: [ChallengeEntry]
    /// Comentários nos abastecimentos do mural.
    var comments: [ChallengeComment] = []
    /// Reações (emoji livre) nos abastecimentos do mural — 1 por pessoa por abastecimento.
    var reactions: [ChallengeReactionMark] = []
    /// Votos na foto do hodômetro (confere × suspeito) — 1 por pessoa por abastecimento.
    var photoVotes: [ChallengePhotoVoteMark] = []
    /// Quem criou modera: troca o código, apaga comentário de qualquer um e
    /// esconde foto do mural.
    var createdByMe = false
    /// Abastecimentos com a foto do desafio escondida por quem criou (D8).
    var hiddenPhotoEntryIDs: Set<UUID> = []
    /// Pilotos que você bloqueou (D8): sem fotos nem conversa deles.
    var blockedMemberIDs: Set<UUID> = []
    /// Fuso do desafio: decide onde começa e termina cada dia do período.
    var timeZone: TimeZone = .current

    var period: ChallengePeriod {
        ChallengePeriod(firstDay: startDate, lastDay: endDate, timeZone: timeZone)
    }

    /// Dias depois do fim para registrar o abastecimento que cobre os últimos
    /// dias. A classificação só fecha depois deles.
    static let closingGraceDays = 3

    var memberCount: Int { standings.count }
    var me: ChallengeStanding? { standings.first(where: \.isMe) }
    var winner: ChallengeStanding? { standings.first { $0.rank == 1 } }

    var inviteURL: URL { InviteCode.link(for: code) }

    /// Texto pronto do "Convidar" (o link vai junto). O código vai escrito
    /// para quem abrir a mensagem fora do iPhone ou com o link quebrado.
    func inviteMessage(now: Date = Date()) -> String {
        "Bora pro desafio “\(name)” no Carburante? Ganha quem rodar mais km até "
            + "\(AppFormat.dayMonth(endDate, now: now)). Código: \(InviteCode.formatted(code))"
    }

    func standing(for memberID: UUID) -> ChallengeStanding? {
        standings.first { $0.id == memberID }
    }

    func entries(of memberID: UUID) -> [ChallengeEntry] {
        entries.filter { $0.memberID == memberID }
    }

    /// Conversa de um abastecimento, mais antigo primeiro (como no Mensagens).
    func comments(on entryID: UUID) -> [ChallengeComment] {
        comments.filter { $0.entryID == entryID }.sorted { $0.date < $1.date }
    }

    func commentCount(on entryID: UUID) -> Int {
        comments.count(where: { $0.entryID == entryID })
    }

    /// Quem escreveu apaga o seu; quem criou o desafio apaga qualquer um.
    func canDelete(_ comment: ChallengeComment) -> Bool {
        createdByMe || comment.memberID == me?.id
    }

    // MARK: Reações

    /// Ninguém reage ao próprio abastecimento.
    func canReact(to entry: ChallengeEntry) -> Bool {
        guard let me else { return false }
        return entry.memberID != me.id
    }

    func myReaction(on entryID: UUID) -> String? {
        guard let me else { return nil }
        return reactions.first { $0.entryID == entryID && $0.memberID == me.id }?.emoji
    }

    /// Tocar num emoji: põe; outro emoji troca; o mesmo de novo tira
    /// (Tapback do Mensagens). Só aceita um emoji de verdade.
    mutating func react(_ emoji: String, on entry: ChallengeEntry) {
        guard let me, canReact(to: entry), ChallengeReaction.isSingleEmoji(emoji) else { return }
        let previous = myReaction(on: entry.id)
        reactions.removeAll { $0.entryID == entry.id && $0.memberID == me.id }
        if previous != emoji {
            reactions.append(ChallengeReactionMark(entryID: entry.id, memberID: me.id, emoji: emoji))
        }
    }

    /// Emojis de um abastecimento, o mais usado primeiro; empate = quem
    /// chegou antes (ordem das marcas, que o servidor manda por data).
    func reactionTallies(on entryID: UUID) -> [ReactionTally] {
        let marks = reactions.filter { $0.entryID == entryID }
        var order: [String] = []
        for mark in marks where !order.contains(mark.emoji) { order.append(mark.emoji) }
        let tallies: [ReactionTally] = order.map { emoji in
            let people = marks.filter { $0.emoji == emoji }.compactMap { standing(for: $0.memberID) }
            return ReactionTally(emoji: emoji, count: people.count,
                                 includesMe: people.contains(where: \.isMe),
                                 names: people.sorted { $0.isMe && !$1.isMe }.map { $0.isMe ? "Você" : $0.firstName })
        }
        // `sorted` não é estável: desempata pela ordem de chegada.
        return tallies.sorted {
            $0.count != $1.count ? $0.count > $1.count
                : order.firstIndex(of: $0.emoji)! < order.firstIndex(of: $1.emoji)!
        }
    }

    // MARK: Foto suspeita

    func isBlocked(_ memberID: UUID) -> Bool { blockedMemberIDs.contains(memberID) }

    func isPhotoHidden(_ entryID: UUID) -> Bool { hiddenPhotoEntryIDs.contains(entryID) }

    /// Quem criou esconde (ou mostra de novo) a foto do desafio de outro
    /// piloto. A dele mesmo ele troca no registro.
    func canHidePhoto(of entry: ChallengeEntry) -> Bool {
        guard createdByMe, let me, entry.memberID != me.id else { return false }
        return entry.challengePhotoRef != nil || isPhotoHidden(entry.id)
    }

    /// Foto do desafio depois de salvar: só no seu abastecimento e enquanto o
    /// desafio não encerrou (na reta de fechamento ainda dá).
    func canChangeChallengePhoto(of entry: ChallengeEntry, now: Date = Date()) -> Bool {
        guard let me else { return false }
        return entry.memberID == me.id && !isFinished(now: now)
    }

    /// Vota quem está no desafio, na foto dos outros. Sem foto, nada a conferir.
    func canVote(on entry: ChallengeEntry) -> Bool {
        canReact(to: entry) && entry.odometerPhotoRef != nil
    }

    func myVote(on entryID: UUID) -> PhotoVote? {
        guard let me else { return nil }
        return photoVotes.first { $0.entryID == entryID && $0.memberID == me.id }?.vote
    }

    /// Mesmo jeito da reação: outro voto troca, o mesmo de novo tira.
    mutating func vote(_ vote: PhotoVote, on entry: ChallengeEntry) {
        guard let me, canVote(on: entry) else { return }
        let previous = myVote(on: entry.id)
        photoVotes.removeAll { $0.entryID == entry.id && $0.memberID == me.id }
        if previous != vote {
            photoVotes.append(ChallengePhotoVoteMark(entryID: entry.id, memberID: me.id, key: vote.rawValue))
        }
    }

    func photoVerdict(on entryID: UUID) -> PhotoVerdict {
        let marks = photoVotes.filter { $0.entryID == entryID }
        func names(_ vote: PhotoVote) -> [String] {
            marks.filter { $0.vote == vote }
                .compactMap { standing(for: $0.memberID) }
                .sorted { $0.isMe && !$1.isMe }
                .map { $0.isMe ? "Você" : $0.firstName }
        }
        return PhotoVerdict(suspect: names(.suspect), ok: names(.ok))
    }

    /// Quantos registros do piloto estão marcados como suspeitos.
    func suspectCount(of memberID: UUID) -> Int {
        entries(of: memberID).count(where: { photoVerdict(on: $0.id).isSuspect })
    }

    typealias Phase = ChallengePeriod.Phase

    func phase(now: Date = Date()) -> Phase { period.phase(now: now) }

    func isFinished(now: Date = Date()) -> Bool { phase(now: now) == .finished }

    /// "faltam 12 dias", "último dia", "classificação fecha em 2 dias"…
    func phaseText(now: Date = Date()) -> String { period.phaseText(now: now) }

    var pilotsText: String { memberCount == 1 ? "1 piloto" : "\(memberCount) pilotos" }

    /// A "pressão boa" do card do Resumo: quem está logo à frente e por
    /// quanto. nil quando você não está no desafio.
    var gapSentence: String? {
        guard let me else { return nil }
        if me.fuelUps == 0 {
            return "Seus km começam a contar no próximo abastecimento com foto."
        }
        let others = standings.filter { !$0.isMe }
        // Empate: o servidor (`rank()`) dá a mesma posição a quem tem os
        // mesmos km — e pula a seguinte (1, 1, 3).
        if let tied = others.first(where: { $0.rank == me.rank }) {
            return "Empatado com \(tied.firstName)."
        }
        if me.rank == 1 {
            guard let next = others.min(by: { $0.rank < $1.rank }) else { return "Você lidera." }
            let lead = me.km - next.km
            return lead > 0 ? "Você lidera por \(AppFormat.km(lead))." : "Empatado com \(next.firstName)."
        }
        guard let ahead = others.filter({ $0.rank < me.rank }).max(by: { $0.rank < $1.rank }) else { return nil }
        let gap = ahead.km - me.km
        return gap > 0 ? "\(ahead.firstName) está \(AppFormat.km(gap)) à frente." : "Empatado com \(ahead.firstName)."
    }
}

extension Challenge {
    /// O desafio do card do Resumo (PLAN/desafios.md §Card no Resumo): um em
    /// que você está e que ainda vale abastecer — rolando ou na reta de
    /// fechamento —, o que fecha primeiro. Antes de começar e encerrado não
    /// têm card.
    static func forSummary(_ challenges: [Challenge], now: Date = Date()) -> Challenge? {
        challenges
            .filter { challenge in
                guard challenge.me != nil else { return false }
                switch challenge.phase(now: now) {
                case .running, .closing: return true
                case .upcoming, .finished: return false
                }
            }
            .min { ($0.period.endsAt, $0.name) < ($1.period.endsAt, $1.name) }
    }

    /// Quem venceu (empate = mais de um). Vazio se ninguém somou km.
    var winners: [ChallengeStanding] {
        standings.filter { $0.rank == 1 && $0.km > 0 }
    }
}

/// O que o último abastecimento fez no placar — o retorno ao registrar
/// ("+230 km no desafio · você está em 2º", PLAN/desafios.md §v1). O app
/// compara a sua linha antes e depois do recálculo no servidor.
struct ChallengeGain: Equatable {
    let km: Double
    let rank: Int
    let previousRank: Int?
    let date: Date

    /// Some do card depois disso (o placar segue mostrando a posição).
    static let shownFor: TimeInterval = 12 * 60 * 60

    /// nil = o abastecimento não mexeu nos seus km (sem foto, âncora, ainda
    /// subindo a foto) — menos de 1 km também não vale festa.
    init?(before: ChallengeStanding?, after: ChallengeStanding?, date: Date = Date()) {
        guard let after else { return nil }
        let km = after.km - (before?.km ?? 0)
        guard km >= 1 else { return nil }
        self.km = km
        self.rank = after.rank
        self.previousRank = before?.rank
        self.date = date
    }

    func isFresh(now: Date = Date()) -> Bool {
        now.timeIntervalSince(date) < Self.shownFor
    }

    /// "+230 km no último abastecimento · subiu para 2º"
    var text: String {
        "+\(AppFormat.km(km)) no último abastecimento · \(rankText)"
    }

    private var rankText: String {
        guard let previousRank, previousRank != rank else {
            return rank == 1 ? "segue na liderança" : "segue em \(rank)º"
        }
        if rank == 1 { return "assumiu a liderança" }
        return rank < previousRank ? "subiu para \(rank)º" : "agora em \(rank)º"
    }
}

/// Período do desafio em dias inteiros, no fuso do desafio. O servidor guarda
/// `[starts_at, ends_at)`: o início do 1º dia e o início do dia seguinte ao
/// último — o último dia conta inteiro.
struct ChallengePeriod: Hashable {
    /// Início do 1º e do último dia.
    let firstDay: Date
    let lastDay: Date
    let timeZone: TimeZone

    /// O servidor aceita até 366 dias de `starts_at` a `ends_at`; 365 deixa
    /// folga para a mudança de horário de outros fusos.
    static let maxDays = 365

    init(firstDay: Date, lastDay: Date, timeZone: TimeZone = .current) {
        let calendar = Self.calendar(timeZone)
        self.firstDay = calendar.startOfDay(for: firstDay)
        self.lastDay = max(self.firstDay, calendar.startOfDay(for: lastDay))
        self.timeZone = timeZone
    }

    /// O que o servidor devolve → dias.
    init(startsAt: Date, endsAt: Date, timeZone: TimeZone) {
        let last = Self.calendar(timeZone).date(byAdding: .day, value: -1, to: endsAt) ?? endsAt
        self.init(firstDay: startsAt, lastDay: last, timeZone: timeZone)
    }

    var startsAt: Date { firstDay }
    var endsAt: Date { calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay }
    var dayCount: Int { days(firstDay, lastDay) + 1 }

    var calendar: Calendar { Self.calendar(timeZone) }

    static func calendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func days(_ from: Date, _ to: Date) -> Int {
        calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    enum Phase: Equatable {
        case upcoming(daysToStart: Int)
        case running(daysLeft: Int)
        /// Período acabou; a classificação ainda aceita o último abastecimento.
        case closing(daysToClose: Int)
        case finished
    }

    func phase(now: Date = Date()) -> Phase {
        let today = calendar.startOfDay(for: now)
        if today < firstDay { return .upcoming(daysToStart: days(today, firstDay)) }
        if today <= lastDay { return .running(daysLeft: days(today, lastDay)) }
        let daysAfterEnd = days(lastDay, today)
        if daysAfterEnd <= Challenge.closingGraceDays {
            return .closing(daysToClose: Challenge.closingGraceDays - daysAfterEnd)
        }
        return .finished
    }

    /// "faltam 12 dias", "último dia", "classificação fecha em 2 dias"…
    func phaseText(now: Date = Date()) -> String {
        switch phase(now: now) {
        case .upcoming(let d): return d == 1 ? "começa amanhã" : "começa em \(d) dias"
        case .running(0): return "último dia"
        case .running(1): return "falta 1 dia"
        case .running(let d): return "faltam \(d) dias"
        case .closing(0): return "classificação fecha hoje"
        case .closing(1): return "classificação fecha amanhã"
        case .closing(let d): return "classificação fecha em \(d) dias"
        case .finished: return "encerrado"
        }
    }
}

/// Prazo em 1 toque no form: 1 semana, 1 mês ou até uma data escolhida.
enum ChallengeDuration: Hashable, CaseIterable, Identifiable {
    case week, month, until

    var id: Self { self }

    var label: String {
        switch self {
        case .week: "1 semana"
        case .month: "1 mês"
        case .until: "Até…"
        }
    }

    /// Período começando no dia de `start`. `until` (o último dia) só vale
    /// para `.until`; fica entre o 1º dia e o máximo do servidor.
    func period(from start: Date, until: Date, timeZone: TimeZone = .current) -> ChallengePeriod {
        let calendar = ChallengePeriod.calendar(timeZone)
        let first = calendar.startOfDay(for: start)
        let last: Date
        switch self {
        case .week:
            last = calendar.date(byAdding: .day, value: 6, to: first)!
        case .month:
            let next = calendar.date(byAdding: .month, value: 1, to: first)!
            last = calendar.date(byAdding: .day, value: -1, to: next)!
        case .until:
            let longest = calendar.date(byAdding: .day, value: ChallengePeriod.maxDays - 1, to: first)!
            last = min(max(until, first), longest)
        }
        return ChallengePeriod(firstDay: first, lastDay: last, timeZone: timeZone)
    }
}

/// Limite de criação do plano grátis (decisão 3 do PLAN/desafios.md): um
/// desafio criado por vez — acabou o período, cria outro. Premium cria vários
/// ao mesmo tempo. Entrar é sempre grátis e sem limite. Checado só no app
/// (o Premium ainda não existe no servidor).
enum ChallengeCreationLimit {
    static let freeAtATime = 1

    /// Desafios meus que ainda não acabaram (vão começar ou estão rolando).
    /// Na reta de fechamento o período já acabou: não prende o próximo.
    static func openCreated(_ challenges: [Challenge], now: Date = Date()) -> Int {
        challenges.count { challenge in
            guard challenge.createdByMe else { return false }
            switch challenge.phase(now: now) {
            case .upcoming, .running: return true
            case .closing, .finished: return false
            }
        }
    }

    static func canCreate(_ challenges: [Challenge], isPremium: Bool, now: Date = Date()) -> Bool {
        isPremium || openCreated(challenges, now: now) < freeAtATime
    }
}

/// Nome do desafio e do piloto, com a mesma limpeza do servidor
/// (`challenge_clean_name`): espaços repetidos viram um, pontas cortadas.
enum ChallengeName {
    static let challengeMaxLength = 40
    static let pilotMaxLength = 30

    /// 1º nome que a Apple mandou no login (só vem na 1ª vez).
    static let appleGivenNameKey = "appleGivenName"
    /// Último nome de piloto usado num desafio.
    static let pilotNameKey = "challengePilotName"

    /// Nome do piloto que vem preenchido: o último usado, senão o 1º nome da
    /// Apple, senão vazio (a pessoa digita).
    static func suggestedPilotName(_ defaults: UserDefaults = .standard) -> String {
        for key in [pilotNameKey, appleGivenNameKey] {
            if let name = defaults.string(forKey: key).flatMap({ cleaned($0, maxLength: pilotMaxLength) }) {
                return name
            }
        }
        return ""
    }

    /// Pronto para enviar, ou nil (vazio ou longo demais). Conta como o
    /// Postgres (`char_length` = code points: 👨‍👩‍👧 vale 5), senão o servidor
    /// recusaria o que o app aceitou.
    static func cleaned(_ text: String, maxLength: Int) -> String? {
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !collapsed.isEmpty, collapsed.unicodeScalars.count <= maxLength else { return nil }
        return collapsed
    }

    /// Corta o que passou do limite enquanto a pessoa digita, sem partir um
    /// emoji no meio.
    static func truncated(_ text: String, maxLength: Int) -> String {
        var result = ""
        var scalars = 0
        for character in text {
            scalars += character.unicodeScalars.count
            if scalars > maxLength { break }
            result.append(character)
        }
        return result
    }
}

/// Erro dos desafios. As chaves vêm do servidor (`raise exception` em
/// `supabase/challenges.sql`), ASCII congeladas — o app só traduz. Chave que
/// este app não conhece (servidor mais novo) cai na mensagem genérica.
enum ChallengeError: Error, Hashable {
    case noSession, appleAccountRequired, invalidName, invalidPeriod, notFound
    case notAMember, notTheCreator, full, ended, removed, cannotRemoveSelf
    case tooManyAttempts, invalidCoverPath
    // D7: comentários, reações, votos.
    case entryNotFound, invalidComment, tooManyComments, commentNotFound, cannotDeleteComment
    case cannotReactOwn, invalidReaction, cannotVoteOwn, noPhotoToCheck, invalidVote
    // D8: moderação.
    case inappropriateText, memberNotFound, cannotBlockSelf, invalidReport, tooManyReports
    /// Sem internet ou servidor fora do ar.
    case offline
    /// Chave ou erro desconhecido (o texto cru vai só para o log).
    case unknown(String)

    init(serverKey: String) {
        switch serverKey {
        case "no_session": self = .noSession
        case "apple_account_required": self = .appleAccountRequired
        case "invalid_name": self = .invalidName
        case "invalid_period": self = .invalidPeriod
        case "challenge_not_found": self = .notFound
        case "not_a_member": self = .notAMember
        case "not_the_creator": self = .notTheCreator
        case "challenge_full": self = .full
        case "challenge_ended": self = .ended
        case "removed_from_challenge": self = .removed
        case "cannot_remove_self": self = .cannotRemoveSelf
        case "too_many_attempts": self = .tooManyAttempts
        case "invalid_cover_path": self = .invalidCoverPath
        case "entry_not_found": self = .entryNotFound
        case "invalid_comment": self = .invalidComment
        case "too_many_comments": self = .tooManyComments
        case "comment_not_found": self = .commentNotFound
        case "cannot_delete_comment": self = .cannotDeleteComment
        case "cannot_react_own": self = .cannotReactOwn
        case "invalid_reaction": self = .invalidReaction
        case "cannot_vote_own": self = .cannotVoteOwn
        case "no_photo_to_check": self = .noPhotoToCheck
        case "invalid_vote": self = .invalidVote
        case "inappropriate_text": self = .inappropriateText
        case "member_not_found": self = .memberNotFound
        case "cannot_block_self": self = .cannotBlockSelf
        case "invalid_report": self = .invalidReport
        case "too_many_reports": self = .tooManyReports
        default: self = .unknown(serverKey)
        }
    }

    var message: String {
        switch self {
        case .noSession: "Não deu para identificar sua conta. Tente de novo."
        case .appleAccountRequired: "Desafios precisam da conta Apple. Entre com a Apple e tente de novo."
        case .invalidName: "Confira o nome: está vazio ou longo demais."
        case .invalidPeriod: "Confira as datas: o desafio começa a partir de hoje e dura até 1 ano."
        case .notFound: "Este desafio não existe mais."
        case .notAMember: "Você não está mais neste desafio."
        case .notTheCreator: "Só quem criou o desafio pode fazer isso."
        case .full: "Este desafio já está com o máximo de pilotos."
        case .ended: "Este desafio já acabou."
        case .removed: "Você foi removido deste desafio por quem criou."
        case .cannotRemoveSelf: "Para sair, use “Sair do desafio”."
        case .tooManyAttempts: "Muitas tentativas com código errado. Espere um pouco e tente de novo."
        case .invalidCoverPath: "Não deu para salvar a capa. Tente de novo."
        case .entryNotFound: "Este abastecimento não está mais no desafio."
        case .invalidComment: "O comentário está vazio ou longo demais."
        case .tooManyComments: "Muitos comentários seguidos. Espere um pouco e tente de novo."
        case .commentNotFound: "Este comentário já foi apagado."
        case .cannotDeleteComment: "Só quem escreveu ou quem criou o desafio apaga o comentário."
        case .cannotReactOwn: "Não dá para reagir ao próprio abastecimento."
        case .invalidReaction: "Escolha um emoji só."
        case .cannotVoteOwn: "Não dá para conferir a própria foto."
        case .noPhotoToCheck: "Este abastecimento não tem foto do hodômetro para conferir."
        case .invalidVote: "Não deu para registrar o voto. Tente de novo."
        case .inappropriateText: "Esse texto tem palavras que não são aceitas nos desafios."
        case .memberNotFound: "Este piloto não está mais no desafio."
        case .cannotBlockSelf: "Não dá para bloquear você mesmo."
        case .invalidReport: "Não deu para denunciar: o conteúdo já mudou ou foi apagado."
        case .tooManyReports: "Muitas denúncias seguidas. Espere um pouco e tente de novo."
        case .offline: "Sem conexão. Confira a internet e tente de novo."
        case .unknown: "Algo deu errado. Tente de novo."
        }
    }
}

/// O que se denuncia (D8). `rawValue` = chave congelada do servidor
/// (`challenge_reports.kind`).
enum ChallengeReportKind: String, CaseIterable {
    case name, cover, photo, comment

    /// "Denunciar o nome", "Denunciar a capa"…
    var title: String {
        switch self {
        case .name: "Denunciar o nome"
        case .cover: "Denunciar a capa"
        case .photo: "Denunciar a foto"
        case .comment: "Denunciar o comentário"
        }
    }
}

/// Prévia do convite (`challenge_preview`): o que convence a entrar, antes de
/// estar no desafio. Funciona com sessão anônima.
struct ChallengeInvite: Identifiable, Hashable {
    let id: UUID
    /// Código normalizado que abriu a prévia (é ele que entra).
    var code: String
    var name: String
    var period: ChallengePeriod
    var coverRef: String?
    var createdByName: String?
    /// Quem está no desafio, contando quem criou.
    var memberCount: Int
    /// Até 3 nomes de quem já entrou (sem quem criou), por ordem de chegada.
    var memberNames: [String]
    var maxMembers: Int
    var isMember = false
    var isRemoved = false
    var hasEnded = false

    var isFull: Bool { memberCount >= maxMembers }

    /// "Bruno e Diego já estão", "Bruno, Diego e mais 3 já estão".
    var membersText: String {
        let names = memberNames.prefix(2).map { ChallengeStanding.firstName(of: $0) }
        // Quem criou já aparece na capa; aqui só quem entrou depois.
        let rest = max(0, memberCount - 1 - names.count)
        switch (names.count, rest) {
        case (0, _): return "Ninguém entrou ainda"
        case (1, 0): return "\(names[0]) já está"
        case (2, 0): return "\(names[0]) e \(names[1]) já estão"
        default: return "\(names.joined(separator: ", ")) e mais \(rest) já estão"
        }
    }

    /// Por que não dá para entrar (nil = dá).
    var blocker: String? {
        if isRemoved { return ChallengeError.removed.message }
        if hasEnded { return ChallengeError.ended.message }
        if isFull && !isMember { return ChallengeError.full.message }
        return nil
    }
}

/// Código do convite: 8 caracteres sorteados pelo servidor, sem vogais (não
/// forma palavra) nem os que se confundem (0/O, 1/I/L). Na tela vai em dois
/// blocos, "K7QM-4XPR", para ditar e digitar. O link é o caminho principal;
/// digitar é o plano B.
enum InviteCode {
    static let length = 8
    static let alphabet = Array("BCDFGHJKMNPQRSTVWXYZ23456789")

    /// O que a pessoa digitou ou colou → código, ou nil se não pode ser um.
    /// Aceita minúsculas, espaço, hífen e o link inteiro do convite.
    static func normalized(_ typed: String) -> String? {
        var text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        if let link = URLComponents(string: text),
           let fromLink = link.queryItems?.first(where: { $0.name == "c" })?.value {
            text = fromLink
        }
        let code = text.uppercased().filter { $0 != " " && $0 != "-" }
        guard code.count == length, code.allSatisfy(alphabet.contains) else { return nil }
        return code
    }

    /// "K7QM4XPR" → "K7QM-4XPR".
    static func formatted(_ code: String) -> String {
        guard code.count == length else { return code }
        let middle = code.index(code.startIndex, offsetBy: length / 2)
        return "\(code[..<middle])-\(code[middle...])"
    }

    /// Sorteio local (protótipo). O de verdade nasce no servidor, que garante
    /// que é único.
    static func random() -> String {
        String((0..<length).map { _ in alphabet.randomElement()! })
    }

    // MARK: Link

    /// Domínio do Universal Link (`docs/.well-known/apple-app-site-association`
    /// + Associated Domains no app). Sem o app, a página `/d/` mostra o código
    /// e manda para a loja.
    static let linkHost = "carburante.motorcycles"

    /// `https://carburante.motorcycles/d/?c=K7QM4XPR`. Código na query, não no
    /// caminho: o GitHub Pages só serve arquivo que existe, então `/d/<código>`
    /// daria 404 para quem não tem o app.
    static func link(for code: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = linkHost
        components.path = "/d/"
        components.queryItems = [URLQueryItem(name: "c", value: code)]
        return components.url!
    }

    /// Código de um link de convite que abriu o app, ou nil se o link não é
    /// um convite (outro caminho do site, outro domínio, código inválido).
    static func code(fromLink url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              host == linkHost || host == "www.\(linkHost)",
              ["/d", "/d/", "/d/index.html"].contains(components.path),
              let value = components.queryItems?.first(where: { $0.name == "c" })?.value else {
            return nil
        }
        return normalized(value)
    }
}

/// Comentário num abastecimento do mural. Só texto, curto, só a turma vê.
struct ChallengeComment: Identifiable, Hashable {
    let id: UUID
    var entryID: UUID
    var memberID: UUID
    var text: String
    var date: Date

    /// Caracteres como a pessoa vê (emoji conta 1).
    static let maxLength = 200
    /// O contador aparece só perto do fim.
    static let counterThreshold = 20

    /// Texto pronto para enviar: sem espaço nas pontas. nil = vazio ou longo demais.
    static func cleaned(_ draft: String) -> String? {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= maxLength else { return nil }
        return text
    }

    /// Quantos caracteres faltam; nil enquanto está longe do limite.
    static func remaining(_ draft: String) -> Int? {
        let left = maxLength - draft.count
        return left <= counterThreshold ? left : nil
    }
}

/// Reações: qualquer emoji (teclado de emoji do iPhone) + 6 atalhos no menu,
/// como o Tapback do Mensagens no iOS 18. O emoji em si vai para o servidor —
/// é padrão Unicode, não precisa de chave própria.
enum ChallengeReaction {
    /// Atalhos do menu: o que a turma mais quer dizer (moto, foto bonita, chuva).
    /// 6 é o que cabe na linha do menu sem rolar.
    static let quick = ["🏍️", "🔥", "👏", "😍", "😂", "🌧️"]

    /// Um emoji só — com tom de pele, bandeira, família, tecla "1️⃣".
    /// Letra, número, "#" e "©" sozinhos são texto, não emoji.
    static func isSingleEmoji(_ text: String) -> Bool {
        guard text.count == 1, let scalars = text.first?.unicodeScalars,
              let first = scalars.first, first.properties.isEmoji else { return false }
        return first.properties.isEmojiPresentation || scalars.count > 1
    }
}

/// Uma reação gravada: quem, em qual abastecimento, qual emoji.
struct ChallengeReactionMark: Hashable {
    var entryID: UUID
    var memberID: UUID
    var emoji: String
}

/// Um emoji com a contagem e quem mandou ("Você" primeiro).
struct ReactionTally: Hashable, Identifiable {
    let emoji: String
    let count: Int
    let includesMe: Bool
    let names: [String]

    var id: String { emoji }
}

/// Voto na foto do hodômetro. Chave ASCII congelada (vai para o servidor).
enum PhotoVote: String, CaseIterable {
    case ok, suspect
}

struct ChallengePhotoVoteMark: Hashable {
    var entryID: UUID
    var memberID: UUID
    /// Chave crua; de versão mais nova do app, não conta.
    var key: String

    var vote: PhotoVote? { PhotoVote(rawValue: key) }
}

/// Resultado da conferência da foto. **Não mexe no km** — é a credibilidade
/// do registro diante da turma; a conversa vai para os comentários.
struct PhotoVerdict: Hashable {
    /// Quem achou suspeito / quem disse que confere ("Você" primeiro).
    let suspect: [String]
    let ok: [String]

    /// Uma pessoa sozinha não marca ninguém.
    static let minimumSuspectVotes = 2

    /// Suspeito: pelo menos 2 acham suspeito e são maioria (2 × 1 marca;
    /// 1 × 0 e 2 × 2 não).
    var isSuspect: Bool {
        suspect.count >= Self.minimumSuspectVotes && suspect.count > ok.count
    }

    var hasVotes: Bool { !suspect.isEmpty || !ok.isEmpty }

    /// "2 suspeito · 1 confere".
    var tally: String {
        "\(suspect.count) suspeito · \(ok.count) confere"
    }
}

struct ChallengeBike: Hashable {
    var make: String
    var model: String
    var label: String { "\(make) \(model)" }
}

/// Uma linha da classificação.
struct ChallengeStanding: Identifiable, Hashable {
    /// Id do participante no desafio (não é o user_id).
    let id: UUID
    var rank: Int
    /// Nome que a turma vê (escolhido ao entrar).
    var name: String
    /// Motos com abastecimento no período — todas somam.
    var bikes: [ChallengeBike]
    var fuelUps: Int
    var km: Double
    var isMe: Bool
    /// Último abastecimento que contou no período ("há 2 dias").
    var lastEntryAt: Date? = nil

    var displayName: String { isMe ? "Você" : name }
    var firstName: String { Self.firstName(of: name) }
    var initials: String { Self.initials(of: name) }

    static func firstName(of name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    /// Monograma (padrão Contatos): 1ª letra do primeiro e do último nome.
    static func initials(of name: String) -> String {
        let words = name.split(separator: " ")
        let letters = [words.first, words.count > 1 ? words.last : nil].compactMap { $0?.first }
        return String(letters).uppercased()
    }

    /// "CB 500X" ou "2 motos". Só o modelo: o selo do monograma já mostra a
    /// marca (como a pílula da moto no Resumo).
    var bikeLabel: String {
        bikes.count == 1 ? bikes[0].model : "\(bikes.count) motos"
    }

    /// Marca do selo no monograma: a primeira moto.
    var badgeMake: String? { bikes.first?.make }
}

/// Um abastecimento dentro do período do desafio.
struct ChallengeEntry: Identifiable, Hashable {
    let id: UUID
    var memberID: UUID
    var date: Date
    var bike: ChallengeBike
    var odometer: Double
    var status: Status
    /// Referência da foto do hodômetro (nil = registrou sem foto).
    var odometerPhotoRef: String?
    var odometerFromGallery = false
    /// Foto extra do abastecimento — a "foto do desafio". Não vale km.
    var challengePhotoRef: String?

    enum Status: Hashable {
        /// Km que o trecho terminado aqui somou ao placar.
        case counted(km: Double)
        /// Primeiro abastecimento do participante: só marca o início.
        case start
        /// Sem foto: os km do trecho passam para o próximo com foto.
        case noPhoto
        case notCounted(Reason)
    }

    enum Reason: Hashable {
        case historical, impossible, gap
        /// Situação que este app não conhece (servidor mais novo).
        case unknown

        var text: String {
            switch self {
            case .historical: "Registrado dias depois: registro antigo não conta."
            case .impossible: "Mais de 80 km por litro: trecho impossível."
            case .gap: "Teve um abastecimento pulado antes deste."
            case .unknown: "Este registro não contou."
            }
        }
    }

    var km: Double? {
        if case .counted(let km) = status { return km }
        return nil
    }

    /// Valor da coluna da direita quando não somou km.
    var statusTitle: String? {
        switch status {
        case .counted: nil
        case .start: "Início"
        case .noPhoto: "Sem foto"
        case .notCounted: "Não contou"
        }
    }

    /// Explicação de uma linha para o que não somou km.
    var statusDetail: String? {
        switch status {
        case .counted: nil
        case .start: "Os km contam a partir daqui."
        case .noPhoto: "Os km entram no próximo abastecimento com foto."
        case .notCounted(let reason): reason.text
        }
    }
}
