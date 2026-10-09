//
//  SyncCreatedAtTests.swift
//  CarburanteTests
//
//  `createdAt` é fato imutável: no pull vale o MENOR entre local e remoto
//  (`SyncService.healedCreatedAt`). Base da regra "histórico vs na hora" dos
//  logs e da regra do Premium "moto cadastrada antes do lançamento não conta
//  para o limite".
//

import XCTest
@testable import Carburante

@MainActor
final class SyncCreatedAtTests: XCTestCase {

    private let local = Date(timeIntervalSince1970: 1_800_000_000)

    func testEarlierRemoteWins() {
        // Device puxou a moto antes do campo sincronizar: local = hora do pull.
        let remote = local.addingTimeInterval(-86_400 * 90)
        XCTAssertEqual(SyncService.healedCreatedAt(local: local, remote: remote), remote)
    }

    func testLaterRemoteNeverOverwrites() {
        // Servidor com a hora do 1º push (depois do cadastro no device).
        let remote = local.addingTimeInterval(3_600)
        XCTAssertEqual(SyncService.healedCreatedAt(local: local, remote: remote), local)
    }

    func testSubSecondDifferenceKeepsLocal() {
        // O JSON perde sub-milissegundos — não reescreve a cada launch.
        let remote = local.addingTimeInterval(-0.4)
        XCTAssertEqual(SyncService.healedCreatedAt(local: local, remote: remote), local)
    }
}
