//
//  CloudBackupStepTests.swift
//  CarburanteTests
//
//  Passo "Guarde seu histórico" do checklist (`CloudBackupStep`).
//

import XCTest
@testable import Carburante

final class CloudBackupStepTests: XCTestCase {

    private let bikeCreated = Date(timeIntervalSince1970: 1_000)

    func testAnonymousIsPending() {
        XCTAssertEqual(CloudBackupStep.state(isAnonymous: true, appleLinkedAt: nil,
                                             bikeCreatedAt: bikeCreated), .pending)
    }

    /// Entrou pelo guia desta moto → ✓ como retorno.
    func testLinkedAfterBikeIsDone() {
        XCTAssertEqual(CloudBackupStep.state(isAnonymous: false,
                                             appleLinkedAt: bikeCreated.addingTimeInterval(60),
                                             bikeCreatedAt: bikeCreated), .done)
    }

    /// Moto nova de quem já tinha conta → o passo não aparece.
    func testLinkedBeforeBikeIsHidden() {
        XCTAssertNil(CloudBackupStep.state(isAnonymous: false,
                                           appleLinkedAt: bikeCreated.addingTimeInterval(-60),
                                           bikeCreatedAt: bikeCreated))
    }

    func testLinkedWithUnknownDateIsHidden() {
        XCTAssertNil(CloudBackupStep.state(isAnonymous: false, appleLinkedAt: nil,
                                           bikeCreatedAt: bikeCreated))
    }
}
