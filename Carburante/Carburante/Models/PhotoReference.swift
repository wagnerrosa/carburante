//
//  PhotoReference.swift
//  Carburante
//
//  Regras puras do valor guardado em `FuelLog.odometerPhotoURL` (coluna
//  `odometer_photo_url`). Apesar do nome legado, NÃO é uma URL — o bucket é
//  privado e a imagem é baixada autenticada (RLS) na hora de ver. Dois estados:
//
//  - **local** (upload pendente): só o nome do arquivo, `<fuel_log_id>.jpg`,
//    em Documents/FuelPhotos. Existe só neste device; nunca vai pro servidor.
//  - **remoto**: o path no bucket, `<user_id>/<fuel_log_id>.jpg`. Válido em
//    qualquer device do usuário.
//
//  Os dois terminam no mesmo `<fuel_log_id>.jpg` — o device que tirou a foto
//  continua lendo do disco mesmo depois do upload (funciona offline).
//

import Foundation

enum PhotoReference {
    static let bucket = "fuel-log-photos"

    /// Path no bucket. A 1ª pasta é o `user_id` — é o que as policies de RLS
    /// do Storage checam (`storage.foldername(name)[1] = auth.uid()`).
    static func remotePath(userID: UUID, logID: UUID) -> String {
        "\(folder(userID: userID))/\(fileName(logID: logID))"
    }

    /// Pasta do usuário no bucket. **Minúsculas:** `auth.uid()::text` do Postgres
    /// sai em minúsculas e `UUID.uuidString` do Swift em maiúsculas — com a
    /// pasta em maiúsculas a policy nunca bate e todo upload volta 400.
    static func folder(userID: UUID) -> String {
        userID.uuidString.lowercased()
    }

    static func fileName(logID: UUID) -> String {
        "\(logID.uuidString).jpg"
    }

    /// Referência já está no bucket (tem a pasta do usuário).
    static func isRemote(_ ref: String?) -> Bool {
        guard let ref, !ref.isEmpty else { return false }
        return ref.contains("/")
    }

    /// Foto só no disco deste device, ainda não enviada.
    static func isPendingUpload(_ ref: String?) -> Bool {
        guard let ref, !ref.isEmpty else { return false }
        return !isRemote(ref)
    }

    /// O que sobe na coluna: só referência remota. Um nome de arquivo local não
    /// significa nada em outro device — enquanto o upload não acontece, vai nil.
    static func pushValue(_ ref: String?) -> String? {
        isRemote(ref) ? ref : nil
    }

    /// Reconcilia a referência no pull, FORA do last-write-wins da linha: a
    /// foto tem ciclo próprio (o upload troca a referência sem mexer em
    /// `updatedAt`, então o LWW sozinho nunca entregaria o path a outro device).
    /// - Foto local pendente sempre vence (é dado do usuário ainda não enviado).
    /// - Senão, o remoto vence se existir; remoto nil nunca apaga a local
    ///   (nil no servidor = "ainda não subiu", não "foto removida").
    static func merge(local: String?, remote: String?) -> String? {
        if isPendingUpload(local) { return local }
        if let remote, !remote.isEmpty { return remote }
        return local
    }
}
