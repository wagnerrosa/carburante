//
//  PhotoReferenceTests.swift
//  CarburanteTests
//
//  Regras puras da referência da foto do hodômetro (`PhotoReference`): local
//  (upload pendente) vs remota, o que sobe no push e o merge do pull.
//

import XCTest
@testable import Carburante

final class PhotoReferenceTests: XCTestCase {
    private let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let logID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    private var local: String { PhotoReference.fileName(logID: logID) }
    private var remote: String { PhotoReference.remotePath(userID: userID, logID: logID) }

    func testRemotePathStartsWithUserFolder() {
        // A 1ª pasta é o que a policy de RLS do Storage compara com auth.uid().
        XCTAssertEqual(remote, "\(userID.uuidString)/\(logID.uuidString).jpg")
    }

    func testUserFolderIsLowercase() {
        // auth.uid()::text é minúsculo; pasta maiúscula = policy nega = upload 400.
        let id = UUID(uuidString: "04F021F1-7B92-423C-AD72-D762A90A3B14")!
        XCTAssertEqual(PhotoReference.folder(userID: id), "04f021f1-7b92-423c-ad72-d762a90a3b14")
        XCTAssertTrue(PhotoReference.remotePath(userID: id, logID: logID)
            .hasPrefix("04f021f1-7b92-423c-ad72-d762a90a3b14/"))
    }

    func testLocalAndRemoteShareFileName() {
        // O device que tirou a foto segue lendo do disco depois do upload.
        XCTAssertEqual((remote as NSString).lastPathComponent, local)
    }

    func testClassification() {
        XCTAssertTrue(PhotoReference.isPendingUpload(local))
        XCTAssertFalse(PhotoReference.isRemote(local))
        XCTAssertTrue(PhotoReference.isRemote(remote))
        XCTAssertFalse(PhotoReference.isPendingUpload(remote))
        XCTAssertFalse(PhotoReference.isPendingUpload(nil))
        XCTAssertFalse(PhotoReference.isPendingUpload(""))
        XCTAssertFalse(PhotoReference.isRemote(nil))
    }

    func testPushSendsOnlyRemote() {
        // Nome de arquivo local não significa nada em outro device.
        XCTAssertNil(PhotoReference.pushValue(local))
        XCTAssertNil(PhotoReference.pushValue(nil))
        XCTAssertEqual(PhotoReference.pushValue(remote), remote)
    }

    func testMergeKeepsPendingLocalOverRemote() {
        // Foto trocada aqui e ainda não enviada vence o path antigo do servidor.
        XCTAssertEqual(PhotoReference.merge(local: local, remote: remote), local)
        XCTAssertEqual(PhotoReference.merge(local: local, remote: nil), local)
    }

    func testMergeAdoptsRemoteWhenNothingPending() {
        // Caso do outro device: linha já existia sem foto; o upload não mexe em
        // updated_at, então só o merge entrega o path.
        XCTAssertEqual(PhotoReference.merge(local: nil, remote: remote), remote)
    }

    func testMergeRemoteNilNeverErasesUploadedPath() {
        // nil no servidor = "ainda não subiu" (ex.: foto trocada em outro device),
        // não "foto removida".
        XCTAssertEqual(PhotoReference.merge(local: remote, remote: nil), remote)
        XCTAssertNil(PhotoReference.merge(local: nil, remote: nil))
    }
}
