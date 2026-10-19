//
//  ChallengeTests.swift
//  CarburanteTests
//
//  Regras puras dos Desafios (`Challenge`): prazo, textos do card do Resumo,
//  monograma e o período em `AppFormat.dayRange`.
//

import XCTest
@testable import Carburante

final class ChallengeTests: XCTestCase {
    private let calendar = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func standing(_ rank: Int, _ name: String, km: Double, fuelUps: Int = 3, me: Bool = false) -> ChallengeStanding {
        ChallengeStanding(id: UUID(), rank: rank, name: name,
                          bikes: [ChallengeBike(make: "Honda", model: "CB 500X")],
                          fuelUps: fuelUps, km: km, isMe: me)
    }

    private func challenge(_ standings: [ChallengeStanding] = []) -> Challenge {
        Challenge(id: UUID(), name: "Turma da serra", startDate: date(2026, 10, 1), endDate: date(2026, 10, 31),
                  createdByName: "Wagner", code: "K7QM4XPR", coverRef: nil, standings: standings, entries: [])
    }

    // MARK: Prazo

    func testPhase_runningCountsDaysToTheLastDay() {
        let c = challenge()
        XCTAssertEqual(c.phase(now: date(2026, 10, 19)), .running(daysLeft: 12))
        XCTAssertEqual(c.phaseText(now: date(2026, 10, 19)), "faltam 12 dias")
        XCTAssertEqual(c.phaseText(now: date(2026, 10, 30)), "falta 1 dia")
        XCTAssertEqual(c.phaseText(now: date(2026, 10, 31)), "último dia")
    }

    func testPhase_closesThreeDaysAfterTheEnd() {
        let c = challenge()
        XCTAssertEqual(c.phase(now: date(2026, 11, 1)), .closing(daysToClose: 2))
        XCTAssertEqual(c.phase(now: date(2026, 11, 3)), .closing(daysToClose: 0))
        XCTAssertFalse(c.isFinished(now: date(2026, 11, 3)))
        XCTAssertTrue(c.isFinished(now: date(2026, 11, 4)))
    }

    func testPhase_upcoming() {
        XCTAssertEqual(challenge().phaseText(now: date(2026, 9, 30)), "começa amanhã")
        XCTAssertEqual(challenge().phaseText(now: date(2026, 9, 28)), "começa em 3 dias")
    }

    // MARK: Card do Resumo

    func testGap_namesWhoIsRightAhead() {
        let c = challenge([standing(1, "Ana Paula", km: 1420), standing(2, "Wagner Rosa", km: 1240, me: true),
                           standing(3, "Bruno", km: 980)])
        XCTAssertEqual(c.gapSentence, "Ana está 180 km à frente.")
    }

    func testGap_leaderSeesTheLead() {
        let c = challenge([standing(1, "Wagner Rosa", km: 1420, me: true), standing(2, "Ana Paula", km: 1240)])
        XCTAssertEqual(c.gapSentence, "Você lidera por 180 km.")
    }

    func testGap_tieAndNoFuelUps() {
        let tie = challenge([standing(1, "Ana Paula", km: 500), standing(2, "Wagner Rosa", km: 500, me: true)])
        XCTAssertEqual(tie.gapSentence, "Empatado com Ana.")
        let fresh = challenge([standing(1, "Ana Paula", km: 500), standing(2, "Wagner Rosa", km: 0, fuelUps: 0, me: true)])
        XCTAssertEqual(fresh.gapSentence, "Seus km começam a contar no próximo abastecimento com foto.")
        XCTAssertNil(challenge([standing(1, "Ana Paula", km: 500)]).gapSentence)
    }

    // MARK: Piloto

    func testInitials_firstAndLastName() {
        XCTAssertEqual(standing(1, "Ana Paula", km: 0).initials, "AP")
        XCTAssertEqual(standing(1, "Maria da Silva", km: 0).initials, "MS")
        XCTAssertEqual(standing(1, "diego", km: 0).initials, "D")
    }

    func testBikeLabel_modelOrCount() {
        var s = standing(1, "Bruno", km: 0)
        XCTAssertEqual(s.bikeLabel, "CB 500X")
        s.bikes.append(ChallengeBike(make: "Yamaha", model: "MT-07"))
        XCTAssertEqual(s.bikeLabel, "2 motos")
    }

    // MARK: Código do convite

    func testInviteCode_acceptsWhatPeopleTypeOrPaste() {
        XCTAssertEqual(InviteCode.normalized("K7QM4XPR"), "K7QM4XPR")
        XCTAssertEqual(InviteCode.normalized(" k7qm-4xpr "), "K7QM4XPR")
        XCTAssertEqual(InviteCode.normalized("K7QM 4XPR"), "K7QM4XPR")
        XCTAssertEqual(InviteCode.normalized("https://carburante.motorcycles/d/?c=K7QM4XPR"), "K7QM4XPR")
    }

    func testInviteCode_rejectsWhatCannotBeACode() {
        XCTAssertNil(InviteCode.normalized(""))
        XCTAssertNil(InviteCode.normalized("SERRA7"), "curto e com vogal")
        XCTAssertNil(InviteCode.normalized("K7QM4XP0"), "0 se confunde com O")
        XCTAssertNil(InviteCode.normalized("K7QM4XP1"), "1 se confunde com I/L")
        XCTAssertNil(InviteCode.normalized("K7QM4XPRB"), "longo demais")
    }

    func testInviteCode_formattedInTwoBlocks() {
        XCTAssertEqual(InviteCode.formatted("K7QM4XPR"), "K7QM-4XPR")
        XCTAssertEqual(InviteCode.formatted("ABC"), "ABC")
    }

    func testInviteCode_randomIsAlwaysValid() {
        for _ in 0..<200 {
            let code = InviteCode.random()
            XCTAssertEqual(InviteCode.normalized(code), code)
        }
    }

    // MARK: Comentários

    func testComment_cleanedTrimsAndLimits() {
        XCTAssertEqual(ChallengeComment.cleaned("  Que vista!\n"), "Que vista!")
        XCTAssertNil(ChallengeComment.cleaned("   \n "))
        XCTAssertNotNil(ChallengeComment.cleaned(String(repeating: "a", count: 200)))
        XCTAssertNil(ChallengeComment.cleaned(String(repeating: "a", count: 201)))
        // Emoji conta 1, como a pessoa vê (o servidor mede em code points: folga lá).
        XCTAssertNotNil(ChallengeComment.cleaned(String(repeating: "👨‍👩‍👧", count: 200)))
    }

    func testComment_counterOnlyNearTheLimit() {
        XCTAssertNil(ChallengeComment.remaining(String(repeating: "a", count: 179)))
        XCTAssertEqual(ChallengeComment.remaining(String(repeating: "a", count: 180)), 20)
        XCTAssertEqual(ChallengeComment.remaining(String(repeating: "a", count: 200)), 0)
    }

    func testComment_whoCanDelete() {
        let me = standing(2, "Wagner Rosa", km: 0, me: true)
        let ana = standing(1, "Ana Paula", km: 0)
        var c = challenge([ana, me])
        let entry = UUID()
        let mine = ChallengeComment(id: UUID(), entryID: entry, memberID: me.id, text: "Bora", date: date(2026, 10, 2))
        let hers = ChallengeComment(id: UUID(), entryID: entry, memberID: ana.id, text: "Vamos", date: date(2026, 10, 1))
        c.comments = [mine, hers]
        XCTAssertTrue(c.canDelete(mine))
        XCTAssertFalse(c.canDelete(hers))
        c.createdByMe = true
        XCTAssertTrue(c.canDelete(hers), "quem criou modera")
        XCTAssertEqual(c.comments(on: entry).map(\.text), ["Vamos", "Bora"], "mais antigo primeiro")
        XCTAssertEqual(c.commentCount(on: entry), 2)
        XCTAssertEqual(c.commentCount(on: UUID()), 0)
    }

    // MARK: Reações

    private func entry(of member: ChallengeStanding) -> ChallengeEntry {
        ChallengeEntry(id: UUID(), memberID: member.id, date: date(2026, 10, 5),
                       bike: ChallengeBike(make: "Honda", model: "CB 500X"), odometer: 1000, status: .start)
    }

    func testReact_putSwapAndRemove() {
        let me = standing(2, "Wagner Rosa", km: 0, me: true)
        let ana = standing(1, "Ana Paula", km: 0)
        var c = challenge([ana, me])
        let hers = entry(of: ana)
        c.react("🏍️", on: hers)
        XCTAssertEqual(c.myReaction(on: hers.id), "🏍️")
        c.react("🤘", on: hers)
        XCTAssertEqual(c.myReaction(on: hers.id), "🤘", "outro emoji troca: 1 por pessoa")
        XCTAssertEqual(c.reactions.count, 1)
        c.react("🤘", on: hers)
        XCTAssertNil(c.myReaction(on: hers.id), "o mesmo de novo tira")
        XCTAssertTrue(c.reactions.isEmpty)
    }

    func testReact_notOnYourOwnFuelUpNorWithText() {
        let me = standing(1, "Wagner Rosa", km: 0, me: true)
        let ana = standing(2, "Ana Paula", km: 0)
        var c = challenge([me, ana])
        c.react("🔥", on: entry(of: me))
        XCTAssertTrue(c.reactions.isEmpty, "ninguém reage ao próprio")
        c.react("a", on: entry(of: ana))
        c.react("🔥🔥", on: entry(of: ana))
        XCTAssertTrue(c.reactions.isEmpty, "só um emoji")
    }

    func testIsSingleEmoji() {
        for emoji in ["🏍️", "🤘", "👍🏽", "🇧🇷", "👨‍👩‍👧", "❤️", "1️⃣"] {
            XCTAssertTrue(ChallengeReaction.isSingleEmoji(emoji), emoji)
        }
        for text in ["", "a", "1", "#", "©", "🔥🔥", "ok"] {
            XCTAssertFalse(ChallengeReaction.isSingleEmoji(text), text)
        }
        XCTAssertTrue(ChallengeReaction.quick.allSatisfy(ChallengeReaction.isSingleEmoji))
    }

    func testReactionTallies_mostUsedFirstThenFirstToArrive() {
        let me = standing(2, "Wagner Rosa", km: 0, me: true)
        let ana = standing(1, "Ana Paula", km: 0)
        let bruno = standing(3, "Bruno Lima", km: 0)
        let carla = standing(4, "Carla Souza", km: 0)
        var c = challenge([ana, me, bruno, carla])
        let target = entry(of: carla)
        c.reactions = [
            ChallengeReactionMark(entryID: target.id, memberID: ana.id, emoji: "🌧️"),
            ChallengeReactionMark(entryID: target.id, memberID: bruno.id, emoji: "🏍️"),
            ChallengeReactionMark(entryID: target.id, memberID: me.id, emoji: "🏍️"),
            ChallengeReactionMark(entryID: target.id, memberID: carla.id, emoji: "🤘"),
        ]
        let tallies = c.reactionTallies(on: target.id)
        XCTAssertEqual(tallies.map(\.emoji), ["🏍️", "🌧️", "🤘"], "empate: quem chegou antes")
        XCTAssertEqual(tallies[0].count, 2)
        XCTAssertTrue(tallies[0].includesMe)
        XCTAssertEqual(tallies[0].names, ["Você", "Bruno"])
        XCTAssertFalse(tallies[1].includesMe)
    }

    // MARK: Período

    func testDayRange() {
        let now = date(2026, 10, 19)
        XCTAssertEqual(AppFormat.dayRange(date(2026, 10, 1), date(2026, 10, 31), now: now), "1–31 de out.")
        XCTAssertEqual(AppFormat.dayRange(date(2026, 10, 20), date(2026, 11, 19), now: now), "20 de out. – 19 de nov.")
        XCTAssertEqual(AppFormat.dayRange(date(2026, 12, 20), date(2027, 1, 19), now: now),
                       "20 de dez. de 2026 – 19 de jan. de 2027")
    }
}
