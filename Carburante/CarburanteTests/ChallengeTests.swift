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
                  createdByName: "Wagner", code: "SERRA7", coverRef: nil, standings: standings, entries: [])
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

    // MARK: Período

    func testDayRange() {
        let now = date(2026, 10, 19)
        XCTAssertEqual(AppFormat.dayRange(date(2026, 10, 1), date(2026, 10, 31), now: now), "1–31 de out.")
        XCTAssertEqual(AppFormat.dayRange(date(2026, 10, 20), date(2026, 11, 19), now: now), "20 de out. – 19 de nov.")
        XCTAssertEqual(AppFormat.dayRange(date(2026, 12, 20), date(2027, 1, 19), now: now),
                       "20 de dez. de 2026 – 19 de jan. de 2027")
    }
}
