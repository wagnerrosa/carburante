//
//  AppleSignInNonceTests.swift
//  CarburanteTests
//
//  Testa o gerador de nonce do Sign in with Apple (puro, sem rede).
//

import XCTest
@testable import Carburante

final class AppleSignInNonceTests: XCTestCase {
    func testRandomHasRequestedLength() {
        XCTAssertEqual(AppleSignInNonce.random(length: 32).count, 32)
        XCTAssertEqual(AppleSignInNonce.random(length: 8).count, 8)
    }

    func testRandomIsUnique() {
        let a = AppleSignInNonce.random()
        let b = AppleSignInNonce.random()
        XCTAssertNotEqual(a, b, "Dois nonces seguidos não podem colidir")
    }

    func testRandomUsesURLSafeCharset() {
        let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = AppleSignInNonce.random(length: 256)
        XCTAssertTrue(nonce.allSatisfy { allowed.contains($0) })
    }

    func testSHA256IsDeterministicAndHex() {
        // SHA256("abc") conhecido — prova hash correto e encoding hex minúsculo.
        let expected = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        XCTAssertEqual(AppleSignInNonce.sha256("abc"), expected)
    }

    func testSHA256DiffersForDifferentInput() {
        XCTAssertNotEqual(AppleSignInNonce.sha256("a"), AppleSignInNonce.sha256("b"))
    }
}
