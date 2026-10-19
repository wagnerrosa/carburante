//
//  ChallengePreview.swift
//  Carburante
//
//  D0 do PLAN/desafios.md: dados fictícios para aprovar as telas antes do
//  servidor. Só DEBUG, só em memória — não toca SwiftData nem Supabase.
//
//  Launch arg `-challengesPreview <tela>` liga a aba e abre a tela:
//  board | activity | participant | entry | details | empty | invite | inviteAnon | form | resumo.
//  Fotos: Documents/ChallengePreview/<ref>.jpg no simulador (sem elas, a
//  capa padrão / um quadro cinza).
//

#if DEBUG
import Foundation

enum ChallengePreview {
    enum Screen: String {
        case board, activity, participant, entry, details, empty, invite, inviteAnon, form, resumo
    }

    static var screen: Screen? {
        UserDefaults.standard.string(forKey: "challengesPreview").flatMap(Screen.init)
    }

    static var isEnabled: Bool { screen != nil }

    static var startScreen: ChallengesView.StartScreen {
        switch screen {
        case .activity: .activity
        case .participant: .participant(participantID)
        case .entry: .entry(entryID)
        case .details: .details
        case .invite: .invite(anonymous: false)
        case .inviteAnon: .invite(anonymous: true)
        case .form: .form
        default: .board
        }
    }

    /// Card do Resumo: o primeiro desafio ativo.
    static var summaryChallenge: Challenge? {
        challenges.first { !$0.isFinished() }
    }

    static let challenges: [Challenge] = {
        let all = [serra, domingo, setembro]
        return screen == .empty ? [setembro] : all
    }()

    private static let cal = Calendar.current
    private static let today = cal.startOfDay(for: Date())

    private static func day(_ daysAgo: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        let d = cal.date(byAdding: .day, value: -daysAgo, to: today)!
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: d)!
    }

    /// Comentários de hoje relativos a agora ("há 12 min"), não a uma hora fixa.
    private static func ago(minutes: Int) -> Date {
        Date().addingTimeInterval(-Double(minutes) * 60)
    }

    // MARK: Pilotos

    private static let ids = (0..<6).map { _ in UUID() }
    private static let cb500 = ChallengeBike(make: "Honda", model: "CB 500X")
    private static let iron = ChallengeBike(make: "Harley-Davidson", model: "Iron 883")
    private static let mt07 = ChallengeBike(make: "Yamaha", model: "MT-07")
    private static let biz = ChallengeBike(make: "Honda", model: "Biz 125")
    private static let gs = ChallengeBike(make: "BMW", model: "G 310 GS")
    private static let himalayan = ChallengeBike(make: "Royal Enfield", model: "Himalayan")
    private static let twin = ChallengeBike(make: "Triumph", model: "Street Twin")

    static var participantID: UUID { ids[2] }
    /// Abastecimento da Ana na serra (foto do desafio + conversa).
    static let entryID = UUID()
    private static let noPhotoEntryID = UUID()
    private static let myEntryID = UUID()
    private static let diegoEntryID = UUID()

    // MARK: Turma da serra (mês corrente, ativo)

    private static let serra: Challenge = {
        let start = cal.dateInterval(of: .month, for: today)!.start
        let end = cal.date(byAdding: .day, value: -1, to: cal.dateInterval(of: .month, for: today)!.end)!
        let standings = [
            ChallengeStanding(id: ids[0], rank: 1, name: "Ana Paula", bikes: [cb500], fuelUps: 5, km: 1420, isMe: false),
            ChallengeStanding(id: ids[1], rank: 2, name: "Wagner Rosa", bikes: [iron], fuelUps: 4, km: 1240, isMe: true),
            ChallengeStanding(id: ids[2], rank: 3, name: "Bruno Lima", bikes: [mt07, biz], fuelUps: 4, km: 980, isMe: false),
            ChallengeStanding(id: ids[3], rank: 4, name: "Carla Souza", bikes: [gs], fuelUps: 3, km: 760, isMe: false),
            ChallengeStanding(id: ids[4], rank: 5, name: "Diego", bikes: [himalayan], fuelUps: 2, km: 410, isMe: false),
            ChallengeStanding(id: ids[5], rank: 6, name: "Fernanda Alves", bikes: [twin], fuelUps: 1, km: 0, isMe: false),
        ]
        func e(_ who: Int, _ bike: ChallengeBike, _ date: Date, _ odo: Double, _ status: ChallengeEntry.Status,
               photo: Bool = true, gallery: Bool = false, extra: String? = nil, id: UUID = UUID()) -> ChallengeEntry {
            ChallengeEntry(id: id, memberID: ids[who], date: date, bike: bike, odometer: odo, status: status,
                           odometerPhotoRef: photo ? "odometer" : nil, odometerFromGallery: gallery,
                           challengePhotoRef: extra)
        }
        let entries = [
            e(0, cb500, day(0, 14, 32), 18_930, .counted(km: 230), extra: "IMG_0003", id: entryID),
            e(2, biz, day(0, 9, 10), 41_205, .noPhoto, photo: false, id: noPhotoEntryID),
            e(1, iron, day(1, 18, 45), 22_035, .counted(km: 310), extra: "IMG_0001", id: myEntryID),
            e(3, gs, day(2, 11, 20), 9_870, .counted(km: 190), gallery: true),
            e(4, himalayan, day(3, 16, 5), 31_400, .counted(km: 205), extra: "IMG_0004", id: diegoEntryID),
            e(0, cb500, day(4, 8, 40), 18_700, .counted(km: 310)),
            e(2, mt07, day(4, 19, 15), 15_330, .counted(km: 520), gallery: true),
            e(5, twin, day(5, 10, 0), 6_120, .start),
            e(1, iron, day(6, 17, 30), 21_725, .counted(km: 340)),
            e(3, gs, day(8, 9, 0), 9_680, .counted(km: 330), extra: "IMG_0005"),
            e(0, cb500, day(9, 13, 10), 18_390, .counted(km: 290)),
            e(2, mt07, day(10, 7, 50), 14_810, .counted(km: 460)),
            e(1, iron, day(11, 18, 0), 21_385, .counted(km: 290)),
            e(4, himalayan, day(12, 12, 30), 31_195, .counted(km: 205)),
            e(0, cb500, day(13, 18, 20), 18_100, .counted(km: 330)),
            e(2, biz, day(14, 12, 0), 40_990, .notCounted(.gap)),
            e(3, gs, day(15, 15, 45), 9_350, .counted(km: 240)),
            e(1, iron, day(16, 8, 15), 21_095, .counted(km: 300)),
            e(0, cb500, day(17, 17, 0), 17_770, .counted(km: 260)),
        ]
        func c(_ entry: UUID, _ who: Int, _ date: Date, _ text: String) -> ChallengeComment {
            ChallengeComment(id: UUID(), entryID: entry, memberID: ids[who], text: text, date: date)
        }
        let comments = [
            c(entryID, 2, ago(minutes: 85), "Que vista! Onde é isso?"),
            c(entryID, 0, ago(minutes: 70), "Serra do Rio do Rastro. Lá em cima tava 6 °C 🥶"),
            c(entryID, 1, ago(minutes: 12), "Semana que vem eu vou também. Me espera lá em cima 😂"),
            c(noPhotoEntryID, 3, ago(minutes: 200), "Cadê a foto do hodômetro, Bruno? 👀"),
            c(noPhotoEntryID, 2, ago(minutes: 185), "Esqueci! Os km vão no próximo, juro 😅"),
            c(myEntryID, 4, day(1, 19, 10), "Essa Iron tá rodando mais que a minha Himalayan"),
        ]
        func r(_ entry: UUID, _ who: Int, _ reaction: ChallengeReaction) -> ChallengeReactionMark {
            ChallengeReactionMark(entryID: entry, memberID: ids[who], key: reaction.rawValue)
        }
        let reactions = [
            r(entryID, 2, .wow), r(entryID, 3, .wow), r(entryID, 1, .fire), r(entryID, 4, .moto),
            r(noPhotoEntryID, 3, .laugh), r(noPhotoEntryID, 0, .laugh),
            r(myEntryID, 0, .moto), r(myEntryID, 4, .moto), r(myEntryID, 3, .fire),
            r(diegoEntryID, 0, .rain), r(diegoEntryID, 5, .clap), r(diegoEntryID, 2, .rain),
        ]
        return Challenge(id: UUID(), name: "Turma da serra", startDate: start, endDate: end,
                         createdByName: "Wagner", code: "K7QM4XPR", coverRef: "IMG_0005",
                         standings: standings, entries: entries, comments: comments,
                         reactions: reactions, createdByMe: true)
    }()

    // MARK: Bate-volta de domingo (1 semana, ativo, sem capa)

    private static let domingo: Challenge = {
        let me = UUID()
        return Challenge(
            id: UUID(), name: "Bate-volta de domingo", startDate: day(2), endDate: day(-4),
            createdByName: "Carla", code: "B9TW2HKN", coverRef: nil,
            standings: [
                ChallengeStanding(id: UUID(), rank: 1, name: "Carla Souza", bikes: [gs], fuelUps: 1, km: 190, isMe: false),
                ChallengeStanding(id: me, rank: 2, name: "Wagner Rosa", bikes: [iron], fuelUps: 1, km: 0, isMe: true),
                ChallengeStanding(id: UUID(), rank: 3, name: "Pedro", bikes: [mt07], fuelUps: 0, km: 0, isMe: false),
            ],
            entries: [])
    }()

    // MARK: Setembro na estrada (encerrado)

    private static let setembro: Challenge = {
        let lastMonth = cal.date(byAdding: .month, value: -1, to: today)!
        let interval = cal.dateInterval(of: .month, for: lastMonth)!
        return Challenge(
            id: UUID(), name: "Setembro na estrada", startDate: interval.start,
            endDate: cal.date(byAdding: .day, value: -1, to: interval.end)!,
            createdByName: "Ana", code: "MZ6RQ3VD", coverRef: "IMG_0003",
            standings: [
                ChallengeStanding(id: UUID(), rank: 1, name: "Ana Paula", bikes: [cb500], fuelUps: 8, km: 2310, isMe: false),
                ChallengeStanding(id: UUID(), rank: 2, name: "Wagner Rosa", bikes: [iron], fuelUps: 7, km: 1980, isMe: true),
                ChallengeStanding(id: UUID(), rank: 3, name: "Bruno Lima", bikes: [mt07, biz], fuelUps: 5, km: 1120, isMe: false),
                ChallengeStanding(id: UUID(), rank: 4, name: "Carla Souza", bikes: [gs], fuelUps: 4, km: 900, isMe: false),
            ],
            entries: [])
    }()
}
#endif
