//
//  ChallengeServiceTests.swift
//  CarburanteTests
//
//  Respostas das funções dos desafios → tipos de tela. O JSON abaixo foi
//  capturado do Supabase de verdade (fixtures de supabase/tests, transação
//  com ROLLBACK), decodificado com o mesmo decodificador do SDK.
//

import XCTest
@testable import Carburante

@MainActor
final class ChallengeServiceTests: XCTestCase {
    private let brt = TimeZone(identifier: "America/Sao_Paulo")!

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try ChallengeService.decode(type, from: Data(json.utf8))
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = brt
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: my_challenges

    private let myChallengesJSON = """
    [{"id": "11111111-1111-4111-8111-111111111111", "name": "Turma da serra",
      "starts_at": "2026-10-05T03:00:00+00:00", "ends_at": "2026-10-12T03:00:00+00:00",
      "time_zone": "America/Sao_Paulo", "cover_path": null, "invite_code": "K7QM4XPR",
      "created_by_me": true, "member_count": 3, "finalized_at": null}]
    """

    func testMyChallenges_periodComesBackAsWholeDaysInTheChallengeTimeZone() throws {
        let row = try XCTUnwrap(decode([ChallengeRowDTO].self, myChallengesJSON).first)
        // [05/10 00:00, 12/10 00:00) em Brasília = de 5 a 11 de outubro.
        XCTAssertEqual(row.period.firstDay, day(2026, 10, 5))
        XCTAssertEqual(row.period.lastDay, day(2026, 10, 11))
        XCTAssertEqual(row.period.dayCount, 7)
        XCTAssertEqual(row.period.timeZone, brt)
        XCTAssertNil(row.finalized_at)
    }

    func testMyChallenges_creatorNameComesFromMyStanding() throws {
        let row = try XCTUnwrap(decode([ChallengeRowDTO].self, myChallengesJSON).first)
        let me = ChallengeStanding(id: UUID(), rank: 1, name: "Ana Souza", bikes: [], fuelUps: 0, km: 0, isMe: true)
        let challenge = row.challenge(standings: [me], entries: [])
        XCTAssertEqual(challenge.createdByName, "Ana Souza")
        XCTAssertTrue(challenge.createdByMe)
        XCTAssertEqual(challenge.code, "K7QM4XPR")
        XCTAssertEqual(challenge.timeZone, brt)
        XCTAssertEqual(challenge.startDate, day(2026, 10, 5))
        XCTAssertEqual(challenge.endDate, day(2026, 10, 11))
    }

    // MARK: challenge_leaderboard

    func testLeaderboard_decodesBikesAndLastEntry() throws {
        let json = """
        [{"member_id": "022f02e9-1f8f-4757-8661-9c1a2303fac9", "rank": 1, "display_name": "Ana Souza",
          "is_me": true, "km": 876.3, "fuel_ups": 2, "bikes": [{"make": "Yamaha", "model": "MT-07"}],
          "last_entry_at": "2026-10-10T12:00:00+00:00"},
         {"member_id": "6f470d53-020d-4030-9943-a4224730b981", "rank": 2, "display_name": "Bruno",
          "is_me": false, "km": 450, "fuel_ups": 7,
          "bikes": [{"make": "Honda", "model": "CB 500X"}, {"make": "BMW", "model": "G 310 GS"}],
          "last_entry_at": "2026-10-10T06:00:00+00:00"},
         {"member_id": "61acedad-f781-407c-9f0b-063d6277322e", "rank": 3, "display_name": "Diego",
          "is_me": false, "km": 0, "fuel_ups": 0, "bikes": [{"make": "Triumph", "model": "Tiger 900"}],
          "last_entry_at": null}]
        """
        let standings = try decode([ChallengeStandingDTO].self, json).map(\.standing)
        XCTAssertEqual(standings.map(\.km), [876.3, 450, 0])
        XCTAssertEqual(standings[0].isMe, true)
        XCTAssertEqual(standings[1].bikeLabel, "2 motos")
        XCTAssertEqual(standings[1].badgeMake, "Honda")
        XCTAssertEqual(standings[2].bikeLabel, "Tiger 900")
        XCTAssertNil(standings[2].lastEntryAt)
        XCTAssertEqual(standings[0].lastEntryAt, ISO8601DateFormatter().date(from: "2026-10-10T12:00:00Z"))
    }

    // MARK: challenge_entries

    func testEntries_mapStatusPhotoAndSource() throws {
        let json = """
        [{"fuel_log_id": "a3000000-0000-4000-8000-000000000007", "member_id": "022f02e9-1f8f-4757-8661-9c1a2303fac9",
          "date": "2026-10-13T12:00:00+00:00", "make": "Yamaha", "model": "MT-07", "odometer": 11300,
          "status": "counted", "km": 393.8,
          "odometer_photo_path": "a1000000-0000-4000-8000-000000000001/A3000000-0000-4000-8000-000000000007.jpg",
          "odometer_photo_source": "gallery", "challenge_photo_path": null},
         {"fuel_log_id": "a3000000-0000-4000-8000-000000000006", "member_id": "022f02e9-1f8f-4757-8661-9c1a2303fac9",
          "date": "2026-10-10T12:00:00.123456+00:00", "make": "Yamaha", "model": "MT-07", "odometer": 10900,
          "status": "no_photo", "km": 0, "odometer_photo_path": null, "odometer_photo_source": null,
          "challenge_photo_path": null}]
        """
        let entries = try decode([ChallengeEntryDTO].self, json).map(\.entry)
        XCTAssertEqual(entries[0].status, .counted(km: 393.8))
        XCTAssertEqual(entries[0].km, 393.8)
        XCTAssertTrue(entries[0].odometerFromGallery)
        XCTAssertEqual(entries[0].odometerPhotoRef,
                       "a1000000-0000-4000-8000-000000000001/A3000000-0000-4000-8000-000000000007.jpg")
        XCTAssertEqual(entries[0].bike.label, "Yamaha MT-07")
        // Data com microssegundos (como o Postgres manda created_at/date).
        XCTAssertEqual(entries[1].status, .noPhoto)
        XCTAssertEqual(entries[1].statusTitle, "Sem foto")
        XCTAssertFalse(entries[1].odometerFromGallery)
    }

    func testEntryStatus_everyFrozenKeyAndUnknown() {
        XCTAssertEqual(ChallengeEntryDTO.status("start", km: 0), .start)
        XCTAssertEqual(ChallengeEntryDTO.status("counted", km: 12), .counted(km: 12))
        XCTAssertEqual(ChallengeEntryDTO.status("no_photo", km: 0), .noPhoto)
        XCTAssertEqual(ChallengeEntryDTO.status("historical", km: 0), .notCounted(.historical))
        XCTAssertEqual(ChallengeEntryDTO.status("gap", km: 0), .notCounted(.gap))
        XCTAssertEqual(ChallengeEntryDTO.status("impossible", km: 0), .notCounted(.impossible))
        // Servidor mais novo: somou km conta, senão "não contou".
        XCTAssertEqual(ChallengeEntryDTO.status("bonus", km: 50), .counted(km: 50))
        XCTAssertEqual(ChallengeEntryDTO.status("disputed", km: 0), .notCounted(.unknown))
    }

    // MARK: Placar guardado (D5b)

    func testSnapshot_roundTripsWhatTheServerSent() throws {
        let rows = try decode([ChallengeRowDTO].self, myChallengesJSON)
        let standings = try decode([ChallengeStandingDTO].self, """
        [{"member_id": "022f02e9-1f8f-4757-8661-9c1a2303fac9", "rank": 1, "display_name": "Ana Souza",
          "is_me": true, "km": 876.3, "fuel_ups": 2, "bikes": [{"make": "Yamaha", "model": "MT-07"}],
          "last_entry_at": "2026-10-10T12:00:00.123456+00:00"}]
        """)
        let entries = try decode([ChallengeEntryDTO].self, """
        [{"fuel_log_id": "a3000000-0000-4000-8000-000000000007", "member_id": "022f02e9-1f8f-4757-8661-9c1a2303fac9",
          "date": "2026-10-13T12:00:00+00:00", "make": "Yamaha", "model": "MT-07", "odometer": 11300,
          "status": "counted", "km": 393.8, "odometer_photo_path": null,
          "odometer_photo_source": "camera", "challenge_photo_path": null}]
        """)
        let userID = UUID()
        let snapshot = ChallengeSnapshot(userID: userID, savedAt: Date(),
                                         items: [.init(row: rows[0], standings: standings, entries: entries)])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("snapshot-\(UUID()).json")
        defer { ChallengeSnapshot.remove(at: url) }
        snapshot.save(to: url)

        let restored = try XCTUnwrap(ChallengeSnapshot.load(from: url))
        XCTAssertEqual(restored.userID, userID)
        XCTAssertEqual(restored.challenges, snapshot.challenges)
        XCTAssertEqual(restored.challenges.first?.me?.km, 876.3)
        XCTAssertEqual(restored.challenges.first?.timeZone, brt)
    }

    /// Encerrado aberto depois (D6): o mural dele entra no placar guardado sem
    /// mexer nos outros desafios nem na hora da classificação.
    func testSnapshot_replacingEntriesTouchesOnlyThatChallenge() throws {
        let row = try decode([ChallengeRowDTO].self, myChallengesJSON)[0]
        let other = try decode([ChallengeRowDTO].self, myChallengesJSON.replacingOccurrences(
            of: "11111111-1111-4111-8111-111111111111", with: "22222222-2222-4222-8222-222222222222"))[0]
        let entries = try decode([ChallengeEntryDTO].self, """
        [{"fuel_log_id": "a3000000-0000-4000-8000-000000000007", "member_id": "022f02e9-1f8f-4757-8661-9c1a2303fac9",
          "date": "2026-10-13T12:00:00+00:00", "make": "Yamaha", "model": "MT-07", "odometer": 11300,
          "status": "counted", "km": 393.8, "odometer_photo_path": "54fe483d-0000-4000-8000-000000000001/A3000000-0000-4000-8000-000000000007.jpg",
          "odometer_photo_source": "gallery", "challenge_photo_path": null}]
        """)
        let savedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = ChallengeSnapshot(userID: UUID(), savedAt: savedAt, items: [
            .init(row: row, standings: [], entries: []),
            .init(row: other, standings: [], entries: entries),
        ])

        let updated = snapshot.replacingEntries(entries, of: row.id)
        XCTAssertEqual(updated.savedAt, savedAt, "a classificação continua sendo a daquela carga")
        XCTAssertEqual(updated.item(row.id)?.entries.count, 1)
        XCTAssertEqual(updated.item(other.id)?.entries.count, 1)
        XCTAssertEqual(updated.item(row.id)?.challenge.entries.first?.odometerFromGallery, true)
        XCTAssertNil(snapshot.item(UUID()))
    }

    // MARK: Conversa (D7)

    /// Formato do `jsonb_build_object` do `challenge_social` (data com fração).
    private let socialJSON = """
    {"votes": [{"vote": "suspect", "member_id": "022f02e9-1f8f-4757-8661-9c1a2303fac9", "fuel_log_id": "a3000000-0000-4000-8000-000000000007"},
               {"vote": "maybe_later", "member_id": "b0000000-0000-4000-8000-000000000001", "fuel_log_id": "a3000000-0000-4000-8000-000000000007"}],
     "comments": [{"id": "c0000000-0000-4000-8000-0000000000c1", "body": "Que vista! 😍", "member_id": "022f02e9-1f8f-4757-8661-9c1a2303fac9",
                   "created_at": "2026-10-20T12:34:56.789012+00:00", "fuel_log_id": "a3000000-0000-4000-8000-000000000007"}],
     "reactions": [{"emoji": "🏍️", "member_id": "022f02e9-1f8f-4757-8661-9c1a2303fac9", "fuel_log_id": "a3000000-0000-4000-8000-000000000007"}]}
    """

    func testSocial_becomesCommentsReactionsAndVotes() throws {
        let social = try decode(ChallengeSocialDTO.self, socialJSON)
        let row = try decode([ChallengeRowDTO].self, myChallengesJSON)[0]
        let item = ChallengeSnapshot.Item(row: row, standings: [], entries: [], social: social)
        let challenge = item.challenge
        let entry = UUID(uuidString: "a3000000-0000-4000-8000-000000000007")!
        XCTAssertEqual(challenge.comments(on: entry).map(\.text), ["Que vista! 😍"])
        XCTAssertEqual(challenge.comments.first?.id, UUID(uuidString: "c0000000-0000-4000-8000-0000000000c1"))
        XCTAssertEqual(challenge.reactions.map(\.emoji), ["🏍️"])
        XCTAssertEqual(challenge.photoVotes.count, 2)
        // Chave de voto de um app mais novo fica guardada mas não conta.
        XCTAssertNil(challenge.photoVotes.last?.vote)
    }

    /// Placar guardado antes da D7 (sem `social` nem `created_by_name`) abre igual.
    func testSnapshot_fromBeforeD7StillOpens() throws {
        let json = """
        {"userID": "022f02e9-1f8f-4757-8661-9c1a2303fac9", "savedAt": 800000000,
         "items": [{"row": {"id": "11111111-1111-4111-8111-111111111111", "name": "Turma da serra",
                            "starts_at": 781412400, "ends_at": 782017200, "time_zone": "America/Sao_Paulo",
                            "cover_path": null, "invite_code": "K7QM4XPR", "created_by_me": false,
                            "member_count": 3, "finalized_at": null},
                    "standings": [], "entries": []}]}
        """
        let snapshot = try JSONDecoder().decode(ChallengeSnapshot.self, from: Data(json.utf8))
        XCTAssertNil(snapshot.items.first?.social)
        XCTAssertNil(snapshot.challenges.first?.createdByName)
        XCTAssertTrue(snapshot.challenges.first?.comments.isEmpty == true)
    }

    func testMyChallenges_creatorNameForEveryone() throws {
        let json = myChallengesJSON
            .replacingOccurrences(of: "\"created_by_me\": true", with: "\"created_by_me\": false")
            .replacingOccurrences(of: "\"finalized_at\": null}", with: "\"finalized_at\": null, \"created_by_name\": \"Ana Souza\"}")
        let row = try decode([ChallengeRowDTO].self, json)[0]
        XCTAssertEqual(row.challenge(standings: [], entries: []).createdByName, "Ana Souza")
    }

    func testSnapshot_missingOrBrokenFileIsNoSnapshot() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("snapshot-\(UUID()).json")
        XCTAssertNil(ChallengeSnapshot.load(from: url))
        try Data("{".utf8).write(to: url)
        defer { ChallengeSnapshot.remove(at: url) }
        XCTAssertNil(ChallengeSnapshot.load(from: url))
    }

    // MARK: challenge_preview

    func testPreview_decodesInviteAndWrongCodeIsNil() throws {
        let json = """
        {"id": "11111111-1111-4111-8111-111111111111", "name": "Turma da serra",
         "ends_at": "2026-10-12T03:00:00+00:00", "has_ended": true, "is_member": true,
         "starts_at": "2026-10-05T03:00:00+00:00", "time_zone": "America/Sao_Paulo", "cover_path": null,
         "is_removed": false, "max_members": 50, "member_count": 3, "member_names": ["Bruno", "Diego"],
         "created_by_name": "Ana Souza"}
        """
        let invite = try XCTUnwrap(decode(ChallengeInviteDTO?.self, json)).invite(code: "K7QM4XPR")
        XCTAssertEqual(invite.code, "K7QM4XPR")
        XCTAssertEqual(invite.createdByName, "Ana Souza")
        XCTAssertEqual(invite.membersText, "Bruno e Diego já estão")
        XCTAssertEqual(invite.period.lastDay, day(2026, 10, 11))
        XCTAssertTrue(invite.isMember)
        XCTAssertEqual(invite.blocker, ChallengeError.ended.message)
        XCTAssertNil(try decode(ChallengeInviteDTO?.self, "null"))
    }

    func testCreateAndJoinResponses() throws {
        let created = try decode(ChallengeCreatedDTO.self,
                                 #"{"id": "180ad24f-ad5b-48b4-9904-d9ca67ab6ada", "invite_code": "4SM7X4S6"}"#)
        XCTAssertEqual(created.invite_code, "4SM7X4S6")
        XCTAssertNil(try decode(ChallengeJoinedDTO?.self, "null"))
    }

    // MARK: Erros

    func testErrors_serverKeysBecomeMessagesAndUnknownIsGeneric() {
        XCTAssertEqual(ChallengeError(serverKey: "challenge_full"), .full)
        XCTAssertEqual(ChallengeError(serverKey: "removed_from_challenge"), .removed)
        XCTAssertEqual(ChallengeError(serverKey: "too_many_attempts"), .tooManyAttempts)
        XCTAssertEqual(ChallengeError(serverKey: "apple_account_required"), .appleAccountRequired)
        XCTAssertEqual(ChallengeError(serverKey: "nova_chave"), .unknown("nova_chave"))
        XCTAssertEqual(ChallengeError.unknown("x").message, "Algo deu errado. Tente de novo.")
        XCTAssertEqual(ChallengeService.challengeError(URLError(.notConnectedToInternet)), .offline)
        XCTAssertEqual(ChallengeService.challengeError(ChallengeError.ended), .ended)
    }

    /// Toda chave congelada do servidor tem tradução própria (nenhuma cai na
    /// genérica por erro de digitação).
    func testErrors_everyServerKeyIsKnown() {
        let keys = ["no_session", "apple_account_required", "invalid_name", "invalid_period",
                    "challenge_not_found", "not_a_member", "not_the_creator", "challenge_full",
                    "challenge_ended", "removed_from_challenge", "cannot_remove_self",
                    "too_many_attempts", "invalid_cover_path",
                    "entry_not_found", "invalid_comment", "too_many_comments", "comment_not_found",
                    "cannot_delete_comment", "cannot_react_own", "invalid_reaction", "cannot_vote_own",
                    "no_photo_to_check", "invalid_vote"]
        for key in keys {
            if case .unknown = ChallengeError(serverKey: key) { XCTFail("chave sem tradução: \(key)") }
        }
    }
}
