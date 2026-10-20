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

    // MARK: Card do Resumo + retorno ao registrar (D5b)

    private func challenge(_ name: String, from start: Date, to end: Date, mine: Bool = true) -> Challenge {
        Challenge(id: UUID(), name: name, startDate: start, endDate: end, createdByName: nil, code: "K7QM4XPR",
                  coverRef: nil, standings: [standing(1, "Ana", km: 100, me: mine)], entries: [])
    }

    func testSummary_picksTheChallengeThatClosesFirst() {
        let now = date(2026, 10, 20)
        let month = challenge("Mês", from: date(2026, 10, 1), to: date(2026, 10, 31))
        let week = challenge("Semana", from: date(2026, 10, 18), to: date(2026, 10, 24))
        // Acabou dia 18: na reta de fechamento, último abastecimento ainda conta.
        let closing = challenge("Fechando", from: date(2026, 10, 10), to: date(2026, 10, 18))
        XCTAssertEqual(Challenge.forSummary([month, week, closing], now: now)?.name, "Fechando")
        XCTAssertEqual(Challenge.forSummary([month, week], now: now)?.name, "Semana")
    }

    func testSummary_noCardBeforeStartAfterCloseOrOutside() {
        let now = date(2026, 10, 20)
        let upcoming = challenge("Depois", from: date(2026, 10, 25), to: date(2026, 10, 31))
        let finished = challenge("Setembro", from: date(2026, 9, 1), to: date(2026, 9, 30))
        let notIn = challenge("Removido", from: date(2026, 10, 1), to: date(2026, 10, 31), mine: false)
        XCTAssertNil(Challenge.forSummary([upcoming, finished, notIn], now: now))
    }

    func testWinners_tieAndNobody() {
        let tie = challenge([standing(1, "Ana", km: 500), standing(1, "Bruno", km: 500), standing(3, "Carla", km: 10)])
        XCTAssertEqual(tie.winners.map(\.name), ["Ana", "Bruno"])
        let nobody = challenge([standing(1, "Ana", km: 0), standing(1, "Bruno", km: 0)])
        XCTAssertTrue(nobody.winners.isEmpty)
    }

    func testGain_textFollowsThePosition() {
        let before = standing(3, "Wagner", km: 1_010, me: true)
        var after = before
        after.km = 1_240
        after.rank = 2
        XCTAssertEqual(ChallengeGain(before: before, after: after)?.text,
                       "+230 km no último abastecimento · subiu para 2º")
        after.rank = 3
        XCTAssertEqual(ChallengeGain(before: before, after: after)?.text,
                       "+230 km no último abastecimento · segue em 3º")
        after.rank = 1
        XCTAssertEqual(ChallengeGain(before: before, after: after)?.text,
                       "+230 km no último abastecimento · assumiu a liderança")
        // Alguém somou mais no mesmo intervalo.
        after.rank = 4
        XCTAssertEqual(ChallengeGain(before: before, after: after)?.text,
                       "+230 km no último abastecimento · agora em 4º")
        var leader = before
        leader.rank = 1
        after.rank = 1
        XCTAssertEqual(ChallengeGain(before: leader, after: after)?.text,
                       "+230 km no último abastecimento · segue na liderança")
    }

    func testGain_onlyWhenTheKmMoved() {
        let before = standing(2, "Wagner", km: 100, me: true)
        var after = before
        after.km = 100.4
        XCTAssertNil(ChallengeGain(before: before, after: after), "âncora, sem foto ou foto ainda subindo")
        XCTAssertNil(ChallengeGain(before: before, after: nil), "saiu do desafio")
        after.km = 50
        XCTAssertEqual(ChallengeGain(before: nil, after: after)?.km, 50, "entrou no meio do caminho")
    }

    func testGain_fadesAfterTwelveHours() {
        let now = Date()
        var after = standing(1, "Wagner", km: 300, me: true)
        after.rank = 1
        let gain = ChallengeGain(before: standing(1, "Wagner", km: 100, me: true), after: after, date: now)
        XCTAssertEqual(gain?.isFresh(now: now.addingTimeInterval(11 * 3600)), true)
        XCTAssertEqual(gain?.isFresh(now: now.addingTimeInterval(13 * 3600)), false)
    }

    func testTimeAgo_forTheSavedStandings() {
        let now = Date()
        XCTAssertEqual(AppFormat.timeAgo(now.addingTimeInterval(-20), now: now), "agora")
        XCTAssertEqual(AppFormat.timeAgo(now.addingTimeInterval(-2 * 3600), now: now), "há 2 horas")
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

    // MARK: Link do convite

    func testInviteLink_roundTrip() {
        let link = InviteCode.link(for: "K7QM4XPR")
        XCTAssertEqual(link.absoluteString, "https://carburante.motorcycles/d/?c=K7QM4XPR")
        XCTAssertEqual(InviteCode.code(fromLink: link), "K7QM4XPR")
        XCTAssertEqual(challenge().inviteURL, link)
    }

    func testInviteLink_acceptsWhatTheShareSheetAndBrowsersProduce() {
        let links = [
            "https://www.carburante.motorcycles/d/?c=K7QM4XPR",
            "https://carburante.motorcycles/d?c=K7QM4XPR",
            "https://carburante.motorcycles/d/index.html?c=K7QM4XPR",
            "https://CARBURANTE.motorcycles/d/?c=k7qm-4xpr",
            "https://carburante.motorcycles/d/?utm_source=whatsapp&c=K7QM4XPR",
        ]
        for link in links {
            XCTAssertEqual(InviteCode.code(fromLink: URL(string: link)!), "K7QM4XPR", link)
        }
    }

    func testInviteLink_ignoresTheRestOfTheSite() {
        let links = [
            "https://carburante.motorcycles/",
            "https://carburante.motorcycles/ajuda/?c=K7QM4XPR",
            "https://carburante.motorcycles/d/",
            "https://carburante.motorcycles/d/?c=SERRA7",
            "https://carburante.motorcycles/d/K7QM4XPR",
            "http://carburante.motorcycles/d/?c=K7QM4XPR",
            "https://carburante.motorcycles.evil.com/d/?c=K7QM4XPR",
        ]
        for link in links {
            XCTAssertNil(InviteCode.code(fromLink: URL(string: link)!), link)
        }
    }

    func testInviteMessage_carriesNameDeadlineAndCode() {
        let message = challenge().inviteMessage(now: date(2026, 10, 19))
        XCTAssertTrue(message.contains("“Turma da serra”"), message)
        XCTAssertTrue(message.contains("até 31 de out."), message)
        XCTAssertTrue(message.hasSuffix("Código: K7QM-4XPR"), message)
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

    // MARK: Foto suspeita

    func testVerdict_twoAndMajorityMarksSuspect() {
        func verdict(_ suspect: Int, _ ok: Int) -> PhotoVerdict {
            PhotoVerdict(suspect: Array(repeating: "A", count: suspect), ok: Array(repeating: "B", count: ok))
        }
        XCTAssertTrue(verdict(2, 1).isSuspect, "2 × 1: suspeito")
        XCTAssertTrue(verdict(3, 1).isSuspect)
        XCTAssertFalse(verdict(1, 0).isSuspect, "uma pessoa sozinha não marca")
        XCTAssertFalse(verdict(2, 2).isSuspect, "empate não marca")
        XCTAssertFalse(verdict(0, 3).isSuspect)
    }

    func testVote_swapRemoveAndWhoCanVote() {
        let me = standing(2, "Wagner Rosa", km: 0, me: true)
        let ana = standing(1, "Ana Paula", km: 0)
        var c = challenge([ana, me])
        var hers = entry(of: ana)
        XCTAssertFalse(c.canVote(on: hers), "sem foto do hodômetro, nada a conferir")
        hers.odometerPhotoRef = "odometer"
        c.vote(.suspect, on: hers)
        XCTAssertEqual(c.myVote(on: hers.id), .suspect)
        c.vote(.ok, on: hers)
        XCTAssertEqual(c.myVote(on: hers.id), .ok, "outro voto troca")
        XCTAssertEqual(c.photoVotes.count, 1)
        c.vote(.ok, on: hers)
        XCTAssertNil(c.myVote(on: hers.id), "o mesmo de novo tira")
        var mine = entry(of: me)
        mine.odometerPhotoRef = "odometer"
        c.vote(.ok, on: mine)
        XCTAssertTrue(c.photoVotes.isEmpty, "ninguém vota na própria foto")
    }

    func testSuspectCount_perPilot() {
        let me = standing(2, "Wagner Rosa", km: 0, me: true)
        let ana = standing(1, "Ana Paula", km: 0)
        let bruno = standing(3, "Bruno Lima", km: 0)
        var c = challenge([ana, me, bruno])
        let hers = entry(of: ana)
        c.entries = [hers]
        c.photoVotes = [
            ChallengePhotoVoteMark(entryID: hers.id, memberID: me.id, key: "suspect"),
            ChallengePhotoVoteMark(entryID: hers.id, memberID: bruno.id, key: "suspect"),
        ]
        XCTAssertEqual(c.suspectCount(of: ana.id), 1)
        XCTAssertEqual(c.photoVerdict(on: hers.id).suspect, ["Você", "Bruno"])
        XCTAssertEqual(PhotoVote.allCases.map(\.rawValue), ["ok", "suspect"], "chaves congeladas")
    }

    // MARK: Período

    func testDayRange() {
        let now = date(2026, 10, 19)
        XCTAssertEqual(AppFormat.dayRange(date(2026, 10, 1), date(2026, 10, 31), now: now), "1–31 de out.")
        XCTAssertEqual(AppFormat.dayRange(date(2026, 10, 20), date(2026, 11, 19), now: now), "20 de out. – 19 de nov.")
        XCTAssertEqual(AppFormat.dayRange(date(2026, 12, 20), date(2027, 1, 19), now: now),
                       "20 de dez. de 2026 – 19 de jan. de 2027")
    }

    // MARK: Período e prazo (D2)

    private let brt = TimeZone(identifier: "America/Sao_Paulo")!

    private func brtDay(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        ChallengePeriod.calendar(brt).date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testPeriod_serverBoundsAreStartOfFirstDayAndStartOfDayAfterLast() {
        let period = ChallengePeriod(firstDay: brtDay(2026, 10, 5, hour: 15), lastDay: brtDay(2026, 10, 11, hour: 9),
                                     timeZone: brt)
        XCTAssertEqual(period.startsAt, ISO8601DateFormatter().date(from: "2026-10-05T03:00:00Z"))
        XCTAssertEqual(period.endsAt, ISO8601DateFormatter().date(from: "2026-10-12T03:00:00Z"))
        XCTAssertEqual(period.dayCount, 7)
        // Ida e volta pelo formato do servidor.
        let back = ChallengePeriod(startsAt: period.startsAt, endsAt: period.endsAt, timeZone: brt)
        XCTAssertEqual(back, period)
    }

    func testPeriod_lastDayNeverBeforeFirst() {
        let period = ChallengePeriod(firstDay: brtDay(2026, 10, 5), lastDay: brtDay(2026, 10, 1), timeZone: brt)
        XCTAssertEqual(period.lastDay, period.firstDay)
        XCTAssertEqual(period.dayCount, 1)
    }

    func testDuration_weekMonthAndUntil() {
        let start = brtDay(2026, 10, 19, hour: 14)
        let week = ChallengeDuration.week.period(from: start, until: start, timeZone: brt)
        XCTAssertEqual(week.firstDay, brtDay(2026, 10, 19))
        XCTAssertEqual(week.lastDay, brtDay(2026, 10, 25))
        XCTAssertEqual(week.dayCount, 7)

        let month = ChallengeDuration.month.period(from: start, until: start, timeZone: brt)
        XCTAssertEqual(month.lastDay, brtDay(2026, 11, 18))

        // 31 de janeiro + 1 mês = 28 de fevereiro → último dia 27.
        let january = ChallengeDuration.month.period(from: brtDay(2027, 1, 31), until: start, timeZone: brt)
        XCTAssertEqual(january.lastDay, brtDay(2027, 2, 27))

        let until = ChallengeDuration.until.period(from: start, until: brtDay(2026, 12, 24, hour: 20), timeZone: brt)
        XCTAssertEqual(until.lastDay, brtDay(2026, 12, 24))
    }

    func testDuration_untilIsCappedToWhatTheServerAccepts() {
        let start = brtDay(2026, 10, 19)
        let tooLong = ChallengeDuration.until.period(from: start, until: brtDay(2028, 1, 1), timeZone: brt)
        XCTAssertEqual(tooLong.dayCount, ChallengePeriod.maxDays)
        // Servidor: ends_at - starts_at <= 366 dias.
        XCTAssertLessThanOrEqual(tooLong.endsAt.timeIntervalSince(tooLong.startsAt), 366 * 86_400)
    }

    func testPhase_usesTheChallengeTimeZone() {
        // Último dia 11/10 em Brasília. 12/10 01:00 em Brasília = 04:00 UTC:
        // já fechando, mesmo que o aparelho esteja em outro fuso.
        let period = ChallengePeriod(firstDay: brtDay(2026, 10, 5), lastDay: brtDay(2026, 10, 11), timeZone: brt)
        XCTAssertEqual(period.phase(now: brtDay(2026, 10, 11, hour: 23)), .running(daysLeft: 0))
        XCTAssertEqual(period.phase(now: brtDay(2026, 10, 12, hour: 1)), .closing(daysToClose: 2))
        XCTAssertEqual(period.phase(now: brtDay(2026, 10, 14, hour: 23)), .closing(daysToClose: 0))
        XCTAssertEqual(period.phase(now: brtDay(2026, 10, 15, hour: 0)), .finished)
    }

    // MARK: Nomes (mesma limpeza do servidor)

    func testName_collapsesSpacesAndTrims() {
        XCTAssertEqual(ChallengeName.cleaned("  Turma   da\nserra ", maxLength: 40), "Turma da serra")
        XCTAssertNil(ChallengeName.cleaned("   ", maxLength: 40))
        XCTAssertNil(ChallengeName.cleaned("", maxLength: 30))
    }

    func testName_countsLikePostgres() {
        // char_length conta code points: a família tem 5.
        let family = "👨‍👩‍👧"
        XCTAssertEqual(family.unicodeScalars.count, 5)
        XCTAssertNotNil(ChallengeName.cleaned(String(repeating: "a", count: 25) + family, maxLength: 30))
        XCTAssertNil(ChallengeName.cleaned(String(repeating: "a", count: 26) + family, maxLength: 30))
        // Cortar não parte o emoji no meio.
        XCTAssertEqual(ChallengeName.truncated(String(repeating: "a", count: 26) + family, maxLength: 30),
                       String(repeating: "a", count: 26))
        XCTAssertEqual(ChallengeName.truncated("Turma", maxLength: 40), "Turma")
    }

    func testSuggestedPilotName_lastUsedThenAppleThenEmpty() {
        let defaults = UserDefaults(suiteName: "ChallengeTests.\(UUID())")!
        XCTAssertEqual(ChallengeName.suggestedPilotName(defaults), "")
        defaults.set("Wagner", forKey: ChallengeName.appleGivenNameKey)
        XCTAssertEqual(ChallengeName.suggestedPilotName(defaults), "Wagner")
        defaults.set("Wagner R.", forKey: ChallengeName.pilotNameKey)
        XCTAssertEqual(ChallengeName.suggestedPilotName(defaults), "Wagner R.")
    }

    // MARK: Prévia do convite

    private func invite(count: Int, names: [String], member: Bool = false, removed: Bool = false,
                        ended: Bool = false) -> ChallengeInvite {
        ChallengeInvite(id: UUID(), code: "K7QM4XPR", name: "Turma da serra",
                        period: ChallengePeriod(firstDay: brtDay(2026, 10, 5), lastDay: brtDay(2026, 10, 11),
                                                timeZone: brt),
                        coverRef: nil, createdByName: "Ana", memberCount: count, memberNames: names,
                        maxMembers: 50, isMember: member, isRemoved: removed, hasEnded: ended)
    }

    func testInvite_membersTextLeavesTheCreatorOut() {
        XCTAssertEqual(invite(count: 1, names: []).membersText, "Ninguém entrou ainda")
        XCTAssertEqual(invite(count: 2, names: ["Bruno Lima"]).membersText, "Bruno já está")
        XCTAssertEqual(invite(count: 3, names: ["Bruno", "Diego"]).membersText, "Bruno e Diego já estão")
        XCTAssertEqual(invite(count: 6, names: ["Bruno", "Diego", "Carla"]).membersText,
                       "Bruno, Diego e mais 3 já estão")
    }

    func testInvite_blocker() {
        XCTAssertNil(invite(count: 3, names: []).blocker)
        XCTAssertEqual(invite(count: 3, names: [], removed: true).blocker, ChallengeError.removed.message)
        XCTAssertEqual(invite(count: 3, names: [], ended: true).blocker, ChallengeError.ended.message)
        XCTAssertEqual(invite(count: 50, names: []).blocker, ChallengeError.full.message)
        // Já está dentro: cheio não impede abrir.
        XCTAssertNil(invite(count: 50, names: [], member: true).blocker)
    }

    // MARK: Limite do grátis

    private func created(_ start: Date, _ end: Date, mine: Bool = true) -> Challenge {
        var c = Challenge(id: UUID(), name: "Turma", startDate: start, endDate: end, createdByName: nil,
                          code: "K7QM4XPR", coverRef: nil, standings: [], entries: [])
        c.createdByMe = mine
        return c
    }

    func testCreationLimit_freeCreatesOneAtATime() {
        let now = date(2026, 10, 19)
        let running = created(date(2026, 10, 1), date(2026, 10, 31))
        XCTAssertTrue(ChallengeCreationLimit.canCreate([], isPremium: false, now: now))
        XCTAssertFalse(ChallengeCreationLimit.canCreate([running], isPremium: false, now: now))
        XCTAssertTrue(ChallengeCreationLimit.canCreate([running], isPremium: true, now: now))
        // Marcado para começar depois também ocupa a vaga.
        let upcoming = created(date(2026, 11, 1), date(2026, 11, 7))
        XCTAssertFalse(ChallengeCreationLimit.canCreate([upcoming], isPremium: false, now: now))
    }

    func testCreationLimit_endedOrJoinedDoNotCount() {
        let now = date(2026, 10, 19)
        // Período acabou ontem: classificação fechando, mas já pode criar outro.
        let closing = created(date(2026, 10, 12), date(2026, 10, 18))
        let finished = created(date(2026, 9, 1), date(2026, 9, 30))
        // Entrar é sempre grátis: desafio dos outros não conta.
        let joined = created(date(2026, 10, 1), date(2026, 10, 31), mine: false)
        XCTAssertEqual(ChallengeCreationLimit.openCreated([closing, finished, joined], now: now), 0)
        XCTAssertTrue(ChallengeCreationLimit.canCreate([closing, finished, joined], isPremium: false, now: now))
    }
}
