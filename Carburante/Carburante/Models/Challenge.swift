//
//  Challenge.swift
//  Carburante
//
//  Desafios em grupo (PLAN/desafios.md). Tipos de LEITURA: o servidor calcula
//  a classificação (`challenge_leaderboard`) e o app só exibe. Valores puros,
//  sem SwiftData — nada disso é fonte de verdade no aparelho.
//

import Foundation

struct Challenge: Identifiable, Hashable {
    let id: UUID
    var name: String
    /// Primeiro e último dia do período (o último conta inteiro).
    var startDate: Date
    var endDate: Date
    var createdByName: String
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
    /// Quem criou modera: troca o código e apaga comentário de qualquer um.
    var createdByMe = false

    /// Dias depois do fim para registrar o abastecimento que cobre os últimos
    /// dias. A classificação só fecha depois deles.
    static let closingGraceDays = 3

    var memberCount: Int { standings.count }
    var me: ChallengeStanding? { standings.first(where: \.isMe) }
    var winner: ChallengeStanding? { standings.first { $0.rank == 1 } }

    var inviteURL: URL {
        URL(string: "https://carburante.motorcycles/d/?c=\(code)")!
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

    enum Phase: Equatable {
        case upcoming(daysToStart: Int)
        case running(daysLeft: Int)
        /// Período acabou; a classificação ainda aceita o último abastecimento.
        case closing(daysToClose: Int)
        case finished
    }

    func phase(now: Date = Date(), calendar: Calendar = .current) -> Phase {
        let today = calendar.startOfDay(for: now)
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        func days(_ from: Date, _ to: Date) -> Int {
            calendar.dateComponents([.day], from: from, to: to).day ?? 0
        }
        if today < start { return .upcoming(daysToStart: days(today, start)) }
        if today <= end { return .running(daysLeft: days(today, end)) }
        let daysAfterEnd = days(end, today)
        if daysAfterEnd <= Self.closingGraceDays {
            return .closing(daysToClose: Self.closingGraceDays - daysAfterEnd)
        }
        return .finished
    }

    func isFinished(now: Date = Date()) -> Bool { phase(now: now) == .finished }

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

    var pilotsText: String { memberCount == 1 ? "1 piloto" : "\(memberCount) pilotos" }

    /// A "pressão boa" do card do Resumo: quem está logo à frente e por
    /// quanto. nil quando você não está no desafio.
    var gapSentence: String? {
        guard let me else { return nil }
        if me.fuelUps == 0 {
            return "Seus km começam a contar no próximo abastecimento com foto."
        }
        if me.rank == 1 {
            guard let second = standings.first(where: { $0.rank == 2 }) else { return "Você lidera." }
            let lead = me.km - second.km
            return lead > 0 ? "Você lidera por \(AppFormat.km(lead))." : "Empatado com \(second.firstName)."
        }
        guard let ahead = standings.first(where: { $0.rank == me.rank - 1 }) else { return nil }
        let gap = ahead.km - me.km
        return gap > 0 ? "\(ahead.firstName) está \(AppFormat.km(gap)) à frente." : "Empatado com \(ahead.firstName)."
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

    var displayName: String { isMe ? "Você" : name }
    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }

    /// Monograma (padrão Contatos): 1ª letra do primeiro e do último nome.
    var initials: String {
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

        var text: String {
            switch self {
            case .historical: "Registrado dias depois: registro antigo não conta."
            case .impossible: "Mais de 80 km por litro: trecho impossível."
            case .gap: "Teve um abastecimento pulado antes deste."
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
