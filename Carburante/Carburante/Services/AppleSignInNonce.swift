//
//  AppleSignInNonce.swift
//  Carburante
//
//  Geração de nonce para Sign in with Apple. O fluxo OIDC exige um nonce: o app
//  gera um valor aleatório, manda o SHA256 dele para a Apple (`request.nonce`) e
//  guarda o valor CRU para enviar ao Supabase junto do `idToken`. O Supabase
//  recalcula o hash e compara com a claim `nonce` do token — prova que o token
//  foi emitido para esta requisição (anti-replay).
//
//  Puro (sem UI, sem rede) → testável. Ver `AppleSignInNonceTests`.
//

import Foundation
import CryptoKit

enum AppleSignInNonce {
    /// Nonce aleatório (valor cru). Mandado ao Supabase. Comprimento >= 32 por
    /// recomendação da Apple. Charset URL-safe (sem padding/escapes).
    static func random(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else { continue }
            // Rejeição uniforme: só aceita bytes que mapeiam sem viés ao charset.
            if random < UInt8(charset.count) {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    /// SHA256 hex do nonce cru. Vai em `request.nonce` (o que a Apple assina).
    static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
