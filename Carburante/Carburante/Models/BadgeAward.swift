//
//  BadgeAward.swift
//  Carburante
//
//  Registro de QUANDO uma medalha foi conquistada (estilo Garmin: "Você ganhou
//  esta medalha em 8 de novembro de 2025"). O estado locked/unlocked continua
//  DERIVADO da frota via `BadgeEvaluator` (motor puro). Este @Model só carimba a
//  data da PRIMEIRA vez que o id apareceu desbloqueado — é aditivo ao motor, não
//  o substitui.
//
//  Reconciliação: `BadgeAward.reconcile(unlockedIDs:now:in:)` cria um award para
//  cada id desbloqueado que ainda não tem um. Idempotente — rodar de novo é no-op.
//  Backfill: na 1ª execução após o release, badges já conquistadas ganham a data
//  de hoje (não sabíamos antes — honesto, como toda feature que estreia).
//
//  Espelha a tabela `badge_awards` do Supabase. `badgeID` é a PK lógica por
//  usuário; no SwiftData local não há user (sessão única), então é único global.
//

import Foundation
import SwiftData

@Model
final class BadgeAward {
    /// Id do badge no catálogo (`Badge.id`). Único por usuário.
    @Attribute(.unique) var badgeID: String
    /// Quando a medalha foi conquistada (1ª vez vista desbloqueada).
    var earnedAt: Date
    /// UUID estável p/ PK do Supabase (badge_awards.id).
    var id: UUID

    init(badgeID: String, earnedAt: Date, id: UUID = UUID()) {
        self.badgeID = badgeID
        self.earnedAt = earnedAt
        self.id = id
    }
}

extension BadgeAward {
    /// Carimba a data dos badges recém-desbloqueados. Para cada id em
    /// `unlockedIDs` sem award, cria um com `now`. Idempotente.
    /// Retorna true se gravou algo (caller decide sincronizar).
    @discardableResult
    @MainActor
    static func reconcile(unlockedIDs: Set<String>, now: Date, in context: ModelContext) -> Bool {
        guard !unlockedIDs.isEmpty else { return false }
        let existing = (try? context.fetch(FetchDescriptor<BadgeAward>())) ?? []
        let known = Set(existing.map(\.badgeID))
        let fresh = unlockedIDs.subtracting(known)
        guard !fresh.isEmpty else { return false }
        for badgeID in fresh {
            context.insert(BadgeAward(badgeID: badgeID, earnedAt: now))
        }
        try? context.save()
        return true
    }

    /// Mapa id→data para a UI consultar sem refazer o fetch por badge.
    @MainActor
    static func earnedDates(in context: ModelContext) -> [String: Date] {
        let awards = (try? context.fetch(FetchDescriptor<BadgeAward>())) ?? []
        return Dictionary(awards.map { ($0.badgeID, $0.earnedAt) }, uniquingKeysWith: min)
    }
}
