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
    /// Código do convite (link `carburante.motorcycles/d/?c=<código>`).
    var code: String
    /// Referência da capa no Storage. nil = capa padrão do app.
    var coverRef: String?
    var standings: [ChallengeStanding]
    /// Abastecimentos dos participantes dentro do período (mais novo primeiro).
    var entries: [ChallengeEntry]

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
